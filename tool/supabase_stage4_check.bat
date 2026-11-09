@echo off
rem Read-only Stage 4 check: confirms the handover tables, rules and functions. Changes nothing.
cd /d "%~dp0.."
echo Stage 4 check > tool\last_supabase.txt
echo ---- tables >> tool\last_supabase.txt
call npx supabase db query --linked "select c.relname as table_name, c.relrowsecurity as rls_on, (select count(*) from pg_policies p where p.tablename=c.relname and p.policyname='trusted_session_required') as trusted_rule from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('area_handovers','handover_offers') order by 1" < nul >> tool\last_supabase.txt 2>&1
echo ---- functions >> tool\last_supabase.txt
call npx supabase db query --linked "select n.nspname as schema, p.proname as fn from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.proname in ('main_diver','missed_months_in_a_row','handover_month_note','request_area_handover','start_area_handover','offer_area_handover','respond_area_handover','cancel_area_handover','area_handovers_json','area_missed_months_json') order by 1,2" < nul >> tool\last_supabase.txt 2>&1
echo ---- current main diver used >> tool\last_supabase.txt
call npx supabase db query --linked "select count(*) as rules_using_main_diver from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','cots_private') and p.prokind = 'f' and position('cots_private.main_diver(' in pg_get_functiondef(p.oid)) > 0 and p.proname <> 'main_diver'" < nul >> tool\last_supabase.txt 2>&1
echo ---- privileges >> tool\last_supabase.txt
call npx supabase db query --linked "select has_function_privilege('anon','public.request_area_handover(text,text,text)','EXECUTE') as visitors_can_hand_over, has_function_privilege('authenticated','cots_private.main_diver(uuid)','EXECUTE') as app_can_call_rule, has_table_privilege('authenticated','public.area_handovers','SELECT') as app_can_read_table" < nul >> tool\last_supabase.txt 2>&1
echo ---- jobs >> tool\last_supabase.txt
call npx supabase db query --linked "select jobname, active from cron.job order by jobname" < nul >> tool\last_supabase.txt 2>&1
echo ---- records >> tool\last_supabase.txt
call npx supabase db query --linked "select (select count(*) from public.follow_up_assignments) as zones, (select count(*) from public.area_handovers) as handovers, (select count(*) from public.captures) as captures" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
