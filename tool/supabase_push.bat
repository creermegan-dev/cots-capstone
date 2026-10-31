@echo off
rem Saves a backup, then applies pending database migrations to the linked hosted Supabase project.
cd /d "%~dp0.."
echo Pushing migrations... > tool\last_supabase.txt
call npx supabase db push --linked --yes < nul >> tool\last_supabase.txt 2>&1
echo PUSH EXIT %errorlevel% >> tool\last_supabase.txt
call npx supabase migration list --linked < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
