@echo off
rem Read-only Stage 3 check: confirms the honest-count functions exist and are protected. Changes nothing.
cd /d "%~dp0.."
echo Stage 3 check > tool\last_supabase.txt
echo ---- functions >> tool\last_supabase.txt
call npx supabase db query --linked "select p.proname as fn, pg_get_function_identity_arguments(p.oid) as args from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('confirmed_cots','waiting_cots','removal_method_summary') order by 1" < nul >> tool\last_supabase.txt 2>&1
echo ---- app counts >> tool\last_supabase.txt
call npx supabase db query --linked "select count(*) as captures_checked from (select public.confirmed_cots(c), public.waiting_cots(c) from public.captures c) x" < nul >> tool\last_supabase.txt 2>&1
echo ---- privileges >> tool\last_supabase.txt
call npx supabase db query --linked "select has_function_privilege('anon','public.removal_method_summary(date,date,text)','EXECUTE') as visitors_can_read_methods, has_function_privilege('authenticated','public.removal_method_summary(date,date,text)','EXECUTE') as signed_in_can_call, has_function_privilege('anon','public.confirmed_cots(public.captures)','EXECUTE') as visitors_can_read_counts" < nul >> tool\last_supabase.txt 2>&1
echo ---- jobs >> tool\last_supabase.txt
call npx supabase db query --linked "select jobname, active from cron.job order by jobname" < nul >> tool\last_supabase.txt 2>&1
echo ---- records >> tool\last_supabase.txt
call npx supabase db query --linked "select (select count(*) from public.captures) as captures, (select count(*) from public.eliminations) as removals, (select count(*) from public.follow_up_surveys) as visits" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
