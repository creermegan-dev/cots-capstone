# Connect this Flutter app to Firebase (generates lib/firebase_options.dart + native configs).
#
# Usage (from repo root):
#   Interactive (pick project from list — USE THIS if "project not found"):
#     powershell -ExecutionPolicy Bypass -File scripts\connect_firebase.ps1
#
#   With a known Project ID (see Firebase Console → Project settings → Project ID):
#     powershell -ExecutionPolicy Bypass -File scripts\connect_firebase.ps1 -ProjectId YOUR_PROJECT_ID
#
# If the wrong Google account is logged in, run first: firebase login

param(
    # Leave empty for interactive mode (recommended when ID is wrong or unknown).
    [string]$ProjectId = ""
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $root

Write-Host "=== COTS Monitor - Firebase connect ===" -ForegroundColor Cyan
Write-Host "Project folder: $root"
Write-Host ""
Write-Host "Your Firebase Project ID is NOT always the same as the display name." -ForegroundColor Yellow
Write-Host "Find it: Firebase Console → gear (Project settings) → General → Project ID." -ForegroundColor Gray
Write-Host ""

$flutterfire = Join-Path $env:LOCALAPPDATA "Pub\Cache\bin\flutterfire.bat"
if (-not (Test-Path $flutterfire)) {
    Write-Host "Installing FlutterFire CLI..." -ForegroundColor Yellow
    dart pub global activate flutterfire_cli
}

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    Write-Host "Interactive mode: choose the Firebase project when prompted." -ForegroundColor Green
    Write-Host "Use the Google account that OWNS 'COTS Monitor' in the browser if asked." -ForegroundColor Gray
    Write-Host ""
    & $flutterfire configure `
        --platforms=web,android `
        --android-package-name=com.example.cots_monitor `
        --overwrite-firebase-options
} else {
    Write-Host "Using Project ID: $ProjectId" -ForegroundColor Green
    Write-Host ""
    & $flutterfire configure `
        -y `
        --project=$ProjectId `
        --platforms=web,android `
        --android-package-name=com.example.cots_monitor `
        --overwrite-firebase-options
}

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Still failing? Try:" -ForegroundColor Red
    Write-Host "  1. firebase login   (use the same Gmail as the Firebase owner)" -ForegroundColor Gray
    Write-Host "  2. Run this script again with NO -ProjectId to pick from the list" -ForegroundColor Gray
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Done. Open lib\firebase_options.dart and confirm projectId looks correct." -ForegroundColor Green
Write-Host "Then run:" -ForegroundColor Green
Write-Host "  flutter pub get" -ForegroundColor Green
Write-Host "  flutter run -d chrome" -ForegroundColor Green
