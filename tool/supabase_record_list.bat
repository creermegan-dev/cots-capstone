@echo off
rem Stage 9: lists the saved records (a single SELECT; reads only, changes nothing; --yes only skips the CLI prompt).
cd /d "%~dp0.."
echo Record list > tool\last_supabase.txt
call npx supabase db query --remote --yes "select c.id, ma.code as area, ma.geography_version as map, c.status, c.captured_at, c.submitted_at, p.full_name as diver, c.latitude is not null as has_gps, (select count(*) from public.eliminations e where e.capture_id=c.id) as removals from public.captures c join public.monitoring_areas ma on ma.id=c.area_id left join public.profiles p on p.id=c.owner_id order by c.submitted_at" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
