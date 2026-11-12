@echo off
rem LOCAL database only (never hosted): rebuilds the local copy from all migrations, then runs every database test.
rem Output: tool\last_db_reset.txt (rebuild) and tool\last_db_tests.txt (tests).
cd /d "%~dp0.."
call npx supabase db reset --local > tool\last_db_reset.txt 2>&1
echo EXIT %errorlevel% >> tool\last_db_reset.txt
call npx supabase test db > tool\last_db_tests.txt 2>&1
echo EXIT %errorlevel% >> tool\last_db_tests.txt
echo DONE> tool\last_run_status.txt
