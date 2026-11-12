@echo off
rem LOCAL database only: applies pending migrations to the local copy and saves the output.
cd /d "%~dp0.."
call npx supabase migration up > tool\last_db_migrate.txt 2>&1
echo EXIT %errorlevel% >> tool\last_db_migrate.txt
call npx supabase migration list >> tool\last_db_migrate.txt 2>&1
echo DONE> tool\last_run_status.txt
