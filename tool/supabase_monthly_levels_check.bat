@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Monthly site levels check (a single SELECT; reads only, changes nothing; --yes only skips the CLI prompt).
cd /d "%~dp0.." || exit /b 1
echo RUNNING> tool\last_supabase_status.txt
echo Monthly levels check > tool\last_supabase.txt
call npx --yes supabase@3.0.0 db query --remote --yes "select (select count(*) from pg_proc where proname in ('monthly_level','site_month_totals','site_month_levels_json','site_month_history_json')) as new_functions, cots_private.monthly_level(15) as l15, cots_private.monthly_level(16) as l16, cots_private.monthly_level(100) as l100, cots_private.monthly_level(101) as l101, has_function_privilege('authenticated','public.site_month_levels_json(date)','EXECUTE') as app_can_read, has_function_privilege('anon','public.site_month_levels_json(date)','EXECUTE') as visitors_can_read, (select string_agg(a.code || ' ' || to_char(t.month,'Mon YYYY') || ': ' || t.confirmed || ' confirmed, ' || t.waiting || ' waiting -> ' || cots_private.monthly_level(t.confirmed), '; ' order by a.code, t.month) from cots_private.site_month_totals() t join public.monitoring_areas a on a.id = t.area_id) as site_months" < nul >> tool\last_supabase.txt 2>&1
if errorlevel 1 goto failed
echo DONE> tool\last_supabase_status.txt
exit /b 0
:failed
echo Check failed. See tool\last_supabase.txt.>> tool\last_supabase.txt
echo FAILED> tool\last_supabase_status.txt
exit /b 1
