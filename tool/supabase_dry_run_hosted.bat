@echo off
rem Read-only: shows which migrations would be applied to the HOSTED Supabase project. Changes nothing.
rem Supabase CLI v3 targets the local stack unless --remote is passed.
cd /d "%~dp0.."
where supabase >nul 2>&1
if errorlevel 1 (set SB=npx supabase) else (set SB=supabase)
echo Using: %SB% > tool\last_supabase.txt
call %SB% --version >> tool\last_supabase.txt 2>&1
call %SB% db push --dry-run --remote < nul >> tool\last_supabase.txt 2>&1
echo EXIT %errorlevel% >> tool\last_supabase.txt
echo DONE> tool\last_supabase_status.txt
