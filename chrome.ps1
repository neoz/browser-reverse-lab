# start-chrome-debug.ps1
# Launches Google Chrome with CDP remote debugging enabled for Claude Code / MCP attach.
# Uses a local .\chrome-debug profile folder in the current directory.

$Port        = 9222
$UserDataDir = Join-Path $PSScriptRoot "chrome-debug"
$ChromePaths = @(
    "C:\Program Files\Google\Chrome\Application\chrome.exe",
    "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

# Resolve Chrome executable
$ChromeExe = $ChromePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ChromeExe) {
    Write-Error "chrome.exe not found in the expected locations."
    exit 1
}

# Warn if Chrome is already running (a live instance will ignore the debug port)
if (Get-Process -Name chrome -ErrorAction SilentlyContinue) {
    Write-Warning "Chrome is already running. The debug port may be ignored."
    $ans = Read-Host "Close all Chrome windows now? (y/N)"
    if ($ans -eq 'y') {
        Stop-Process -Name chrome -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
}

# Ensure the debug profile directory exists
if (-not (Test-Path $UserDataDir)) {
    New-Item -ItemType Directory -Path $UserDataDir -Force | Out-Null
}

# Launch Chrome with remote debugging
Write-Host "Launching Chrome with remote debugging on port $Port ..." -ForegroundColor Cyan
Write-Host "Profile dir: $UserDataDir" -ForegroundColor DarkGray
& $ChromeExe "--remote-debugging-port=$Port" "--user-data-dir=$UserDataDir"

# Give it a moment, then verify the CDP endpoint
Start-Sleep -Seconds 3
try {
    $tabs = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json" -TimeoutSec 5
    Write-Host "CDP endpoint is live. Debuggable targets:" -ForegroundColor Green
    $tabs | Where-Object { $_.type -eq 'page' } |
        Select-Object title, url | Format-Table -AutoSize
    Write-Host "`nAttach from Claude Code with: --browserUrl http://127.0.0.1:$Port" -ForegroundColor Yellow
} catch {
    Write-Warning "Could not reach http://127.0.0.1:$Port/json yet. Chrome may still be starting, or the port didn't bind."
}
