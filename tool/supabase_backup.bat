@echo off
rem Saves a copy of the hosted Supabase database into backups\ (read-only on the database).
cd /d "%~dp0.."
set STAMP=2026-11-01_1150
echo Backup %STAMP% > tool\last_supabase.txt
call npx supabase db dump --linked -f backups\%STAMP%_schema.sql < nul >> tool\last_supabase.txt 2>&1
echo SCHEMA EXIT %errorlevel% >> tool\last_supabase.txt
call npx supabase db dump --linked --data-only -f backups\%STAMP%_data.sql < nul >> tool\last_supabase.txt 2>&1
echo DATA EXIT %errorlevel% >> tool\last_supabase.txt
call npx supabase db dump --linked --role-only -f backups\%STAMP%_roles.sql < nul >> tool\last_supabase.txt 2>&1
echo ROLES EXIT %errorlevel% >> tool\last_supabase.txt
echo DONE> tool\last_supabase_status.txt
