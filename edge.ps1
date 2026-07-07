# start-edge-debug.ps1
# Launches Microsoft Edge with CDP remote debugging enabled for Claude Code / MCP attach.
# Uses a local .\edge-debug profile folder in the current directory.

$Port        = 9222
$UserDataDir = Join-Path $PSScriptRoot "edge-debug"
$EdgePaths   = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)

# Resolve Edge executable
$EdgeExe = $EdgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $EdgeExe) {
    Write-Error "msedge.exe not found in the expected locations."
    exit 1
}

# Warn if Edge is already running (a live instance will ignore the debug port)
if (Get-Process -Name msedge -ErrorAction SilentlyContinue) {
    Write-Warning "Edge is already running. The debug port may be ignored."
    $ans = Read-Host "Close all Edge windows now? (y/N)"
    if ($ans -eq 'y') {
        Stop-Process -Name msedge -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
}

# Ensure the debug profile directory exists
if (-not (Test-Path $UserDataDir)) {
    New-Item -ItemType Directory -Path $UserDataDir -Force | Out-Null
}

# Launch Edge with remote debugging
Write-Host "Launching Edge with remote debugging on port $Port ..." -ForegroundColor Cyan
Write-Host "Profile dir: $UserDataDir" -ForegroundColor DarkGray
& $EdgeExe "--remote-debugging-port=$Port" "--user-data-dir=$UserDataDir"

# Give it a moment, then verify the CDP endpoint
Start-Sleep -Seconds 3
try {
    $tabs = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json" -TimeoutSec 5
    Write-Host "CDP endpoint is live. Debuggable targets:" -ForegroundColor Green
    $tabs | Where-Object { $_.type -eq 'page' } |
        Select-Object title, url | Format-Table -AutoSize
    Write-Host "`nAttach from Claude Code with: --browserUrl http://127.0.0.1:$Port" -ForegroundColor Yellow
} catch {
    Write-Warning "Could not reach http://127.0.0.1:$Port/json yet. Edge may still be starting, or the port didn't bind."
}