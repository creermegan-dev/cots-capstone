@echo off
rem Shows which database migrations would be applied to hosted Supabase. Changes nothing.
cd /d "%~dp0.."
where supabase >nul 2>&1
if errorlevel 1 (set SB=npx supabase) else (set SB=supabase)
echo Using: %SB% > tool\last_supabase.txt
call %SB% db push --dry-run < nul >> tool\last_supabase.txt 2>&1
echo EXIT %errorlevel% >> tool\last_supabase.txt
echo DONE> tool\last_supabase_status.txt
