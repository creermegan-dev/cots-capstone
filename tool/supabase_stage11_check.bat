@echo off
rem Stage 11 check (a single SELECT; reads only, changes nothing; --yes only skips the CLI prompt).
cd /d "%~dp0.."
echo Stage 11 check > tool\last_supabase.txt
call npx supabase db query --remote --yes "select (select count(*) from pg_proc where proname in ('month_ok','leave_site','send_visit_reminders','end_partner_after_handover')) as new_functions, (select count(*) from pg_trigger where tgname='end_partner_after_handover') as handover_trigger, (select count(*) from cron.job where jobname='cots-visit-reminders') as reminder_schedule, (select schedule from cron.job where jobname='cots-visit-reminders') as runs_at, position('month_ok' in pg_get_functiondef('public.submit_follow_up_survey(uuid,text,date,integer,integer,text,numeric,uuid[],numeric,numeric,text)'::regprocedure))>0 as shared_visit_rule_on, has_function_privilege('authenticated','public.leave_site(text)','EXECUTE') as app_can_leave" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
