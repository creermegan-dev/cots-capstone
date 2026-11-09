@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Read-only: site partner approvals and the latest records of the partner Divers (a single SELECT; changes nothing).
cd /d "%~dp0.." || exit /b 1
echo RUNNING> tool\last_supabase_status.txt
echo Partner check > tool\last_supabase.txt
call npx --yes supabase@3.0.0 db query --remote --yes "select ma.code as site, p.full_name as partner, r.status, to_char(r.decided_at at time zone 'Asia/Manila','Mon DD HH24:MI') as approved_at_ph, (select string_agg(m2.code || ' photo ' || to_char(c.captured_at at time zone 'Asia/Manila','Mon DD HH24:MI') || ' uploaded ' || to_char(c.submitted_at at time zone 'Asia/Manila','Mon DD HH24:MI') || case when cots_private.zone_review_needed(c.id) then ' -> waits for Expert' else ' -> OK' end, '; ' order by c.submitted_at desc) from (select * from public.captures c0 where c0.owner_id = r.candidate_id order by c0.submitted_at desc limit 5) c join public.monitoring_areas m2 on m2.id = c.area_id) as latest_records from public.site_partner_requests r join public.follow_up_assignments a on a.id = r.assignment_id join public.monitoring_areas ma on ma.id = a.area_id join public.profiles p on p.id = r.candidate_id order by r.decided_at desc nulls last limit 5" < nul >> tool\last_supabase.txt 2>&1
if errorlevel 1 goto failed
echo DONE> tool\last_supabase_status.txt
exit /b 0
:failed
echo Check failed. See tool\last_supabase.txt.>> tool\last_supabase.txt
echo FAILED> tool\last_supabase_status.txt
exit /b 1
