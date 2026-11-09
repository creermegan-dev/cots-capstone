@echo off
rem Site 4 · Balet check (a single SELECT; reads only, changes nothing; --yes only skips the CLI prompt).
cd /d "%~dp0.."
echo Site 4 check > tool\last_supabase.txt
call npx supabase db query --remote --yes "select (select string_agg(code, ',' order by code) from public.monitoring_areas where active) as active_sites, (select count(*) from cots_private.area_cells c join public.monitoring_areas a on a.id=c.area_id where a.code='S4') as s4_runs, (select code from public.monitoring_areas where id=cots_private.area_at(7.175877,125.775144)) as centre, (select code from public.monitoring_areas where id=cots_private.area_at(7.171475,125.744961)) as coast, (select code from public.monitoring_areas where id=cots_private.area_at(7.182,125.755)) as deep_water, (select code from public.monitoring_areas where id=cots_private.area_at(7.0123935,125.7183122)) as site2" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
