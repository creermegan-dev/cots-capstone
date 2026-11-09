@echo off
rem Stage 13 + practice sites check (a single SELECT; reads only, changes nothing; --yes only skips the CLI prompt).
cd /d "%~dp0.."
echo Stage 13 check > tool\last_supabase.txt
call npx supabase db query --remote --yes "select (select string_agg(code||'='||name, ', ' order by code) from public.monitoring_areas where active) as active_sites, (select count(*) from cots_private.area_cells) as lookup_runs, (select code from public.monitoring_areas where id=cots_private.area_at(7.311361,125.690736)) as home_spot, (select code from public.monitoring_areas where id=cots_private.area_at(7.313715,125.670413)) as dnsc_spot, cots_private.density_level(15) as d15, cots_private.density_level(16) as d16, cots_private.density_level(101) as d101, has_function_privilege('authenticated','public.site_levels_json()','EXECUTE') as app_can_read_levels, has_function_privilege('anon','public.site_levels_json()','EXECUTE') as anon_can_read_levels" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
