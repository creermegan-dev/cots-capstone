@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Saves a copy of the HOSTED Supabase database into backups\ (read-only on the database). Docker Desktop must be running.
rem Supabase CLI v3 targets the local stack unless --remote is passed.
cd /d "%~dp0.." || exit /b 1
echo RUNNING> tool\last_supabase_status.txt
if not exist backups mkdir backups
if not exist backups goto failed
set "STAMP="
for /f %%I in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd_HHmmss_fff"') do set "STAMP=%%I"
if not defined STAMP goto failed
if exist "backups\%STAMP%_schema.sql" goto failed
if exist "backups\%STAMP%_data.sql" goto failed
if exist "backups\%STAMP%_roles.sql" goto failed
echo Backup %STAMP% > tool\last_supabase.txt
call npx --yes supabase@3.0.0 db dump --remote -f backups\%STAMP%_schema.sql < nul >> tool\last_supabase.txt 2>&1
if errorlevel 1 goto failed
call npx --yes supabase@3.0.0 db dump --remote --data-only -f backups\%STAMP%_data.sql < nul >> tool\last_supabase.txt 2>&1
if errorlevel 1 goto failed
call npx --yes supabase@3.0.0 db dump --remote --role-only -f backups\%STAMP%_roles.sql < nul >> tool\last_supabase.txt 2>&1
if errorlevel 1 goto failed
echo DONE> tool\last_supabase_status.txt
exit /b 0
:failed
echo Backup failed. Any partial files are kept for diagnosis.>> tool\last_supabase.txt
echo FAILED> tool\last_supabase_status.txt
exit /b 1
