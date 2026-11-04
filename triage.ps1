# Interactive bug triage through Swytchcode.
# Lists open issues, then lets you comment on or close one.
# Usage: triage.ps1 [-Owner <owner>] [-Repo <repo>] [-ListOnly]

param(
    [string]$Owner = "Mohit427",
    [string]$Repo = "swytchcode-ppi",
    [switch]$ListOnly
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8

# Runs one Swytchcode operation. With -Preview, it only shows the request.
function Invoke-Swy {
    param(
        [string]$Tool,
        [int]$Issue = 0,
        [hashtable]$Body = $null,
        [switch]$Preview
    )

    $swyArgs = @("exec", $Tool, "--input", "owner=$Owner", "--input", "repo=$Repo")
    if ($Issue -gt 0) { $swyArgs += @("--input", "issue_number=$Issue") }

    $bodyFile = $null
    try {
        if ($Body) {
            # Use a file because PowerShell 5.1 can strip quotes from inline JSON
            $bodyFile = [IO.Path]::GetTempFileName()
            [IO.File]::WriteAllText($bodyFile, ($Body | ConvertTo-Json -Compress))
            $swyArgs += @("--body", $bodyFile)
        }

        if ($Preview) {
            swy @swyArgs --dry-run | Out-Host
            return ($LASTEXITCODE -eq 0)
        }

        $output = (swy @swyArgs --json) -join "`n"
        $exitCode = $LASTEXITCODE
    }
    finally {
        if ($bodyFile) { Remove-Item $bodyFile -ErrorAction SilentlyContinue }
    }

    $parsed = $null
    try { $parsed = $output | ConvertFrom-Json } catch { }

    $status = 0
    if ($parsed -and $parsed.status_code) { $status = [int]$parsed.status_code }

    return [pscustomobject]@{
        Ok     = ($exitCode -eq 0 -and $status -ge 200 -and $status -lt 300)
        Status = $status
        Data   = $(if ($parsed) { $parsed.data } else { $null })
        Raw    = $output
    }
}

function Show-Failure {
    param([string]$Step, $Result)
    Write-Host "$Step failed (HTTP status: $($Result.Status))." -ForegroundColor Red
    if ($Result.Raw) { Write-Host $Result.Raw }
}

function Confirm-Action {
    param([string]$Question)
    return ((Read-Host "$Question (y/N)") -eq "y")
}

function Add-IssueComment {
    param($Issue)

    $text = Read-Host "Comment"
    if ([string]::IsNullOrWhiteSpace($text)) { Write-Host "Empty comment, nothing sent."; return }

    $body = @{ body = $text }
    if (-not (Invoke-Swy -Tool "github.issue.comments.create" -Issue $Issue.number -Body $body -Preview)) {
        Write-Host "Preview failed, nothing sent." -ForegroundColor Red
        return
    }
    if (-not (Confirm-Action "Post this comment on #$($Issue.number)?")) { Write-Host "Cancelled."; return }

    $result = Invoke-Swy -Tool "github.issue.comments.create" -Issue $Issue.number -Body $body
    if ($result.Ok) { Write-Host "Commented: $($result.Data.html_url)" -ForegroundColor Green }
    else { Show-Failure "Comment" $result }
}

function Close-Issue {
    param($Issue)

    $text = Read-Host "Reason for closing"
    if ([string]::IsNullOrWhiteSpace($text)) { Write-Host "A reason is required, nothing sent."; return }

    $reason = "completed"
    if ((Read-Host "[1] Completed  [2] Not planned (default 1)") -eq "2") { $reason = "not_planned" }

    $commentBody = @{ body = $text }
    $closeBody = @{ state = "closed"; state_reason = $reason }

    # Preview both steps before sending either one
    Write-Host "Step 1 of 2: post the reason as a comment"
    if (-not (Invoke-Swy -Tool "github.issue.comments.create" -Issue $Issue.number -Body $commentBody -Preview)) {
        Write-Host "Preview failed, nothing sent." -ForegroundColor Red
        return
    }
    Write-Host "Step 2 of 2: close the issue"
    if (-not (Invoke-Swy -Tool "github.issue.update" -Issue $Issue.number -Body $closeBody -Preview)) {
        Write-Host "Preview failed, nothing sent." -ForegroundColor Red
        return
    }
    if (-not (Confirm-Action "Comment on and close #$($Issue.number)?")) { Write-Host "Cancelled."; return }

    $comment = Invoke-Swy -Tool "github.issue.comments.create" -Issue $Issue.number -Body $commentBody
    if (-not $comment.Ok) {
        Show-Failure "Comment" $comment
        Write-Host "Nothing was closed. Issue #$($Issue.number) is still open." -ForegroundColor Yellow
        return
    }

    $close = Invoke-Swy -Tool "github.issue.update" -Issue $Issue.number -Body $closeBody
    if (-not $close.Ok) {
        Show-Failure "Close" $close
        Write-Host "Partial result: the comment was posted ($($comment.Data.html_url)), but #$($Issue.number) is still open." -ForegroundColor Yellow
        return
    }

    $script:closedThisRun += $Issue.number
    Write-Host "Closed: $($Issue.html_url)" -ForegroundColor Green
}

# A just-closed issue can still appear in the next listing for a moment,
# so remember what this run closed and hide it.
$script:closedThisRun = @()

while ($true) {
    $list = Invoke-Swy -Tool "github.issue.get1"
    if (-not $list.Ok) {
        Show-Failure "Listing issues" $list
        exit 1
    }

    # GitHub's issues endpoint also returns pull requests, so filter them out.
    # It returns the first 30 results by default.
    $issues = @($list.Data | Where-Object {
        $_ -and -not $_.pull_request -and ($script:closedThisRun -notcontains $_.number)
    })

    Write-Host ""
    Write-Host "Open issues in $Owner/$Repo"
    if ($issues.Count -eq 0) {
        Write-Host "No open issues."
        exit 0
    }
    foreach ($item in $issues) {
        Write-Host ("#{0,-4} {1}" -f $item.number, $item.title)
    }
    if ($ListOnly) { exit 0 }

    Write-Host ""
    $choice = Read-Host "Issue number (q to quit)"
    if ($choice -eq "q") { exit 0 }

    $selected = $issues | Where-Object { "$($_.number)" -eq $choice.Trim().TrimStart("#") } | Select-Object -First 1
    if (-not $selected) {
        Write-Host "No open issue with that number."
        continue
    }

    switch ((Read-Host "[c] Comment  [x] Close with a reason  [s] Skip").Trim().ToLower()) {
        "c" { Add-IssueComment $selected }
        "x" { Close-Issue $selected }
        default { Write-Host "Skipped." }
    }
}
