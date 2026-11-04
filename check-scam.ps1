# Checks a suspicious message with Scam Investigator, called through Swytchcode.
# Usage: check-scam.ps1 -Message "text to check" [-DryRun]

param(
    [string]$Message,
    [switch]$DryRun
)

[Console]::OutputEncoding = [Text.Encoding]::UTF8

$tool = "scaminvestigator.investigate.create"
$maxLength = 5000   # The API rejects longer messages

# Reads Swytchcode's --raw output. The API streams "data: {...}" lines,
# and --raw returns that whole stream as text in the "body" field.
function Read-Investigation {
    param([string]$Output)

    $response = $Output | ConvertFrom-Json
    $events = @()

    foreach ($line in ($response.body -split "`r?`n")) {
        if ($line.StartsWith("data: ")) {
            $events += ($line.Substring(6) | ConvertFrom-Json)
        }
    }

    return [pscustomobject]@{
        Status   = [int]$response.status_code
        Body     = $response.body
        Findings = @($events | Where-Object { $_.type -eq "finding" } | ForEach-Object { $_.finding })
        Verdict  = ($events | Where-Object { $_.type -eq "verdict" } | Select-Object -Last 1).verdict
        Error    = ($events | Where-Object { $_.type -eq "error" } | Select-Object -Last 1).message
    }
}

function Show-Verdict {
    param($Result)

    $labels = @{
        likely_scam       = @("LIKELY SCAM", "Red")
        likely_legitimate = @("LIKELY LEGITIMATE", "Green")
        cannot_determine  = @("CANNOT DETERMINE", "Yellow")
    }
    $label = $labels[$Result.Verdict.verdict]
    $percent = [math]::Round($Result.Verdict.confidence * 100)

    Write-Host ""
    Write-Host "VERDICT: $($label[0]) ($percent% confidence)" -ForegroundColor $label[1]

    Write-Host ""
    Write-Host "Why:"
    foreach ($reason in $Result.Verdict.reasons) {
        Write-Host "  - $($reason.text) [$($reason.finding_ids -join ', ')]"
    }

    Write-Host ""
    Write-Host "What to do:"
    foreach ($advice in $Result.Verdict.action_guidance) {
        Write-Host "  - $advice"
    }

    Write-Host ""
    Write-Host "Evidence checked:"
    foreach ($finding in $Result.Findings) {
        Write-Host "  $($finding.id) $($finding.source) [$($finding.status), $($finding.signal)]: $($finding.summary)"
    }
}

function Invoke-Check {
    if ([string]::IsNullOrWhiteSpace($Message)) {
        Write-Host 'Usage: check-scam.ps1 -Message "text to check" [-DryRun]'
        return 1
    }
    if ($Message.Length -gt $maxLength) {
        Write-Host "Message is too long: $($Message.Length) characters (limit $maxLength)."
        return 1
    }

    # Use a file because PowerShell 5.1 can strip quotes from inline JSON
    $bodyFile = [IO.Path]::GetTempFileName()
    try {
        [IO.File]::WriteAllText($bodyFile, (@{ message = $Message } | ConvertTo-Json -Compress))
        $swyArgs = @("exec", $tool, "--body", $bodyFile)

        if ($DryRun) {
            swy @swyArgs --dry-run | Out-Host
            return $LASTEXITCODE
        }

        Write-Host "Investigating, this can take a minute..."
        $output = (swy @swyArgs --raw) -join "`n"
        $exitCode = $LASTEXITCODE
    }
    finally {
        Remove-Item $bodyFile -ErrorAction SilentlyContinue
    }

    if ($exitCode -ne 0) {
        Write-Host "Swytchcode could not complete the call (exit code $exitCode)." -ForegroundColor Red
        if ($output) { Write-Host $output }
        return 1
    }

    try {
        $result = Read-Investigation $output
    }
    catch {
        Write-Host "Could not read the response: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $output
        return 1
    }

    if ($result.Status -eq 429) {
        Write-Host "Rate limited by Scam Investigator. Try again in a moment." -ForegroundColor Yellow
        return 1
    }
    if ($result.Status -ne 200) {
        Write-Host "Scam Investigator returned HTTP $($result.Status): $($result.Body)" -ForegroundColor Red
        return 1
    }
    if (-not $result.Verdict) {
        $why = if ($result.Error) { $result.Error } else { "the response had no verdict" }
        Write-Host "No verdict: $why" -ForegroundColor Red
        return 1
    }

    Show-Verdict $result
    return 0
}

exit (Invoke-Check)
