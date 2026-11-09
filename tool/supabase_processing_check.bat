@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Read-only: records still "Processing evidence" and their photo-check jobs (a single SELECT; changes nothing).
cd /d "%~dp0.." || exit /b 1
echo RUNNING> tool\last_supabase_status.txt
echo Processing check > tool\last_supabase.txt
call npx --yes supabase@3.0.0 db query --remote --yes "select left(c.id::text,8) as capture, ma.code as site, to_char(c.submitted_at at time zone 'Asia/Manila','Mon DD HH24:MI') as uploaded, c.status as capture_status, v.upload_status as photo_status, j.state as job_state, j.attempts, j.last_error_code as error, to_char(j.next_attempt_at at time zone 'Asia/Manila','Mon DD HH24:MI') as next_try, cots_private.zone_review_needed(c.id) as needs_expert_ok, (select string_agg(d.decision, ',') from public.expert_decisions d where d.capture_id = c.id) as expert_decisions from public.captures c left join public.monitoring_areas ma on ma.id = c.area_id left join public.capture_evidence e on e.capture_id = c.id left join public.media_variants v on v.id = e.variant_id left join cots_private.evidence_verification_jobs j on j.variant_id = e.variant_id where c.status = 'pending' order by c.submitted_at desc limit 20" < nul >> tool\last_supabase.txt 2>&1
if errorlevel 1 goto failed
echo DONE> tool\last_supabase_status.txt
exit /b 0
:failed
echo Check failed. See tool\last_supabase.txt.>> tool\last_supabase.txt
echo FAILED> tool\last_supabase_status.txt
exit /b 1
