param()
$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command supabase -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'Supabase CLI is unavailable. No database tests were executed.'
}
Push-Location $workspace
try {
    # No --linked, URL, reset, push, seed, start or hosted credentials. Requires an
    # already approved local stack with these migrations applied.
    & supabase test db --local
    if ($LASTEXITCODE -ne 0) { throw 'Local database tests failed.' }
} finally { Pop-Location }
