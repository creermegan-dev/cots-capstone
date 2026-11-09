@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Read-only check for the High notice and the names function (a single SELECT; changes nothing).
cd /d "%~dp0.." || exit /b 1
echo RUNNING> tool\last_supabase_status.txt
echo Batch check > tool\last_supabase.txt
call npx --yes supabase@3.0.0 db query --remote --yes "select (select count(*) from pg_proc where proname in ('send_high_level_alerts','person_names_json')) as new_functions, (select schedule from cron.job where jobname='cots-high-level-alerts') as high_check_runs_at, has_function_privilege('authenticated','public.person_names_json(uuid[])','EXECUTE') as app_can_read_names, has_function_privilege('anon','public.person_names_json(uuid[])','EXECUTE') as visitors_can_read_names, has_function_privilege('authenticated','cots_private.send_high_level_alerts(timestamptz)','EXECUTE') as app_can_send_alerts" < nul >> tool\last_supabase.txt 2>&1
if errorlevel 1 goto failed
echo DONE> tool\last_supabase_status.txt
exit /b 0
:failed
echo Check failed. See tool\last_supabase.txt.>> tool\last_supabase.txt
echo FAILED> tool\last_supabase_status.txt
exit /b 1
