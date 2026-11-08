@echo off
rem Read-only: counts records per site (a single SELECT; changes nothing; --yes only skips the CLI prompt).
cd /d "%~dp0.."
echo Practice records check > tool\last_supabase.txt
call npx supabase db query --remote --yes "select a.code, a.name, a.active, count(c.id) as records, max(c.captured_at) as latest, (select count(*) from public.follow_up_assignments f where f.area_id=a.id) as follow_up from public.monitoring_areas a left join public.captures c on c.area_id=a.id group by a.id order by a.code" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
