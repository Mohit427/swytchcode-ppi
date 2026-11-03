param([string]$Title, [string]$Description = "")

if ([string]::IsNullOrWhiteSpace($Title)) {
    Write-Host 'Usage: report-bug.ps1 -Title "Short title" -Description "Details"'
    exit 1
}

# Save the issue details as JSON
$file = Join-Path $env:TEMP "swy-issue.json"
$json = @{ title = $Title; body = $Description } | ConvertTo-Json -Compress
[IO.File]::WriteAllText($file, $json)

$swyArgs = @("github.issue.create", "--input", "owner=Mohit427",
             "--input", "repo=swytchcode-ppi", "--body", $file)

# Preview the request without sending it
swy exec @swyArgs --dry-run
if ($LASTEXITCODE -ne 0) { Write-Host "Preview failed."; exit 1 }

if ((Read-Host "Create this issue? (y/N)") -ne "y") { Write-Host "Cancelled."; exit 0 }

# Send it, then print the link
$result = (swy exec @swyArgs --json) -join "`n"
if ($LASTEXITCODE -ne 0) { Write-Host "Failed: $result"; exit 1 }

if ($result -match '"html_url"\s*:\s*"(https://github\.com/[^"]+/issues/\d+)"') {
    Write-Host "Created: $($Matches[1])"
} else {
    Write-Host $result
}
