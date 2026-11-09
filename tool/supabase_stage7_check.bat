@echo off
rem Read-only Stage 7 check: confirms photos without a location are refused for the new map. Changes nothing.
cd /d "%~dp0.."
echo Stage 7 check > tool\last_supabase.txt
call npx supabase db query --linked "select position('COTS_AREA_NO_LOCATION' in pg_get_functiondef('cots_private.check_capture_area()'::regprocedure))>0 as no_location_rule, (select count(*) from pg_trigger where tgname='check_capture_area' and not tgisinternal) as trigger_on, has_function_privilege('authenticated','cots_private.check_capture_area()','EXECUTE') as app_calls_check, (select count(*) from public.monitoring_areas where geography_version='cots-davao-gulf-v2' and active) as parts_active" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
