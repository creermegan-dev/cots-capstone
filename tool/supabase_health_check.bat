@echo off
rem Read-only health check: is the background evidence checker scheduled and running?
cd /d "%~dp0.."
echo Health check > tool\last_supabase.txt
call npx supabase db query --help < nul >> tool\last_supabase.txt 2>&1
echo ---- jobs >> tool\last_supabase.txt
call npx supabase db query --linked "select jobname, schedule, active from cron.job" < nul >> tool\last_supabase.txt 2>&1
echo ---- runs last 24h >> tool\last_supabase.txt
call npx supabase db query --linked "select status, count(*) as runs, max(start_time) as last_run, max(end_time) as last_end from cron.job_run_details where start_time > now() - interval '1 day' group by status" < nul >> tool\last_supabase.txt 2>&1
echo ---- last errors >> tool\last_supabase.txt
call npx supabase db query --linked "select start_time, left(return_message, 300) as message from cron.job_run_details where status <> 'succeeded' order by start_time desc limit 3" < nul >> tool\last_supabase.txt 2>&1
echo ---- records >> tool\last_supabase.txt
call npx supabase db query --linked "select (select count(*) from public.captures) as captures, (select count(*) from public.eliminations) as removals, (select count(*) from cots_private.evidence_verification_jobs) as checker_jobs" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
