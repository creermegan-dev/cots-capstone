# Deep-clean Flutter artifacts when folders are locked (common under OneDrive).
# Usage (from project root): powershell -ExecutionPolicy Bypass -File scripts/windows_deep_clean_flutter.ps1
# Optional: -KillDart  stops dart/flutter_tester first (close analysis servers / test runners first).

param(
    [switch]$KillDart
)

$ErrorActionPreference = 'Continue'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

if ($KillDart) {
    Write-Host 'Stopping Dart-related processes...'
    Get-Process dart*, flutter_tester* -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

$dirs = @(
    (Join-Path $projectRoot 'build'),
    (Join-Path $projectRoot '.dart_tool'),
    (Join-Path $projectRoot 'windows\flutter\ephemeral'),
    (Join-Path $projectRoot 'linux\flutter\ephemeral'),
    (Join-Path $projectRoot 'macos\Flutter\ephemeral'),
    (Join-Path $projectRoot 'ios\Flutter\ephemeral')
)

foreach ($d in $dirs) {
    if (-not (Test-Path -LiteralPath $d)) { continue }
    Write-Host "Removing: $d"
    Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path -LiteralPath $d) {
        cmd /c "rmdir /s /q `"$d`"" | Out-Null
    }
}

Write-Host ''
Write-Host 'Next: flutter pub get'
Write-Host 'Tip: Flutter projects under OneDrive often lock files; copying the repo to e.g. C:\dev\Capstone avoids this.'
