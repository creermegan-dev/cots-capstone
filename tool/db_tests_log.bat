@echo off
rem Runs the local database tests and saves everything to tool\last_db_tests.txt (local only, no hosted changes).
cd /d "%~dp0.."
call npx supabase test db > tool\last_db_tests.txt 2>&1
echo EXIT %errorlevel% >> tool\last_db_tests.txt
echo DONE> tool\last_run_status.txt
