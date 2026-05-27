# Runs flutter with build cache under LocalAppData to reduce OneDrive fights over .\build.
# Usage: .\scripts\flutter_run_chrome.ps1   or add arguments: .\scripts\flutter_run_chrome.ps1 -d chrome

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$FlutterArgs = @('run', '-d', 'chrome')
)

$cacheRoot = Join-Path $env:LOCALAPPDATA 'FlutterBuildCache\COTSMonitor'
New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
$env:FLUTTER_BUILD_DIR = $cacheRoot

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $projectRoot

& flutter @FlutterArgs
