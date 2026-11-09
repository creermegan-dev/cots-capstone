@echo off
rem Applies pending database migrations to the HOSTED Supabase project. Run only after the dry run and the user's OK.
rem Supabase CLI v3 targets the local stack unless --remote is passed.
cd /d "%~dp0.."
echo Pushing migrations... > tool\last_supabase.txt
call npx supabase --version >> tool\last_supabase.txt 2>&1
call npx supabase db push --remote --yes < nul >> tool\last_supabase.txt 2>&1
echo PUSH EXIT %errorlevel% >> tool\last_supabase.txt
call npx supabase migration list --remote < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
