@echo off
rem Read-only Stage 2 check: confirms the zone rules, reminder job and app lookup exist. Changes nothing.
cd /d "%~dp0.."
echo Stage 2 check > tool\last_supabase.txt
echo ---- functions >> tool\last_supabase.txt
call npx supabase db query --linked "select n.nspname as schema, p.proname as fn from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.proname in ('zone_review_needed','zone_responsible_name','send_zone_review_reminders','zone_review_assigned_to','require_zone_reject_reason','notify_zone_review') order by 1,2" < nul >> tool\last_supabase.txt 2>&1
echo ---- trigger >> tool\last_supabase.txt
call npx supabase db query --linked "select tgname, tgenabled from pg_trigger where tgname='require_zone_reject_reason'" < nul >> tool\last_supabase.txt 2>&1
echo ---- reminder job >> tool\last_supabase.txt
call npx supabase db query --linked "select jobname, schedule, active from cron.job order by jobname" < nul >> tool\last_supabase.txt 2>&1
echo ---- app lookup >> tool\last_supabase.txt
call npx supabase db query --linked "select count(*) as captures_checked from (select public.zone_review_assigned_to(c) from public.captures c) x" < nul >> tool\last_supabase.txt 2>&1
echo ---- privileges >> tool\last_supabase.txt
call npx supabase db query --linked "select has_function_privilege('authenticated','cots_private.send_zone_review_reminders(timestamptz)','EXECUTE') as divers_can_send_reminders, has_function_privilege('anon','public.zone_review_assigned_to(public.captures)','EXECUTE') as visitors_can_read" < nul >> tool\last_supabase.txt 2>&1
echo ---- records >> tool\last_supabase.txt
call npx supabase db query --linked "select (select count(*) from public.captures) as captures, (select count(*) from public.eliminations) as removals, (select count(*) from public.follow_up_assignments) as zones" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
