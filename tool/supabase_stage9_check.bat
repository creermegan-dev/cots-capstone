@echo off
rem Stage 9 check (a single SELECT; reads only, changes nothing; --yes only skips the CLI prompt): the 3 Samal sites are on the hosted database and the old map is gone. 
cd /d "%~dp0.."
echo Stage 9 check > tool\last_supabase.txt
call npx supabase db query --remote --yes "select (select string_agg(code || ' = ' || name, ', ' order by code) from public.monitoring_areas where geography_version='cots-samal-sites-v1' and active) as sites, (select count(*) from public.monitoring_areas where geography_version in ('cots-davao-gulf-v1','cots-davao-gulf-v2')) as old_map_rows, (select count(*) from cots_private.area_cells) as lookup_rows, (select code from public.monitoring_areas where id = cots_private.area_at(7.0123935, 125.7183122)) as point_in_site2, (select count(*) from public.captures) as records, (select count(*) from public.follow_up_assignments) as assignments" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
