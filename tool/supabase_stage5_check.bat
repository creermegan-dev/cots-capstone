@echo off
rem Read-only Stage 5 check: confirms the injection rules. Changes nothing.
cd /d "%~dp0.."
echo Stage 5 check > tool\last_supabase.txt
echo ---- functions >> tool\last_supabase.txt
call npx supabase db query --linked "select n.nspname as schema, p.proname as fn from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.proname in ('is_injection','ph_time_label','zone_injections','early_visit_note','month_excused','injection_wait_line') order by 1,2" < nul >> tool\last_supabase.txt 2>&1
echo ---- rules use them >> tool\last_supabase.txt
call npx supabase db query --linked "select position('cots_private.month_excused(' in pg_get_functiondef('cots_private.missed_months_in_a_row(uuid,date)'::regprocedure)) > 0 as missed_count_uses_excused, position('early_visit_note' in pg_get_functiondef('cots_private.survey_json(uuid)'::regprocedure)) > 0 as visits_carry_flag, position('cots_private.injection_wait_line(' in pg_get_functiondef('public.finalize_capture(uuid)'::regprocedure)) > 0 as notice_has_wait_line" < nul >> tool\last_supabase.txt 2>&1
echo ---- privileges >> tool\last_supabase.txt
call npx supabase db query --linked "select has_function_privilege('authenticated','cots_private.zone_injections(uuid)','EXECUTE') as app_can_call_injections, has_function_privilege('authenticated','cots_private.month_excused(uuid,date)','EXECUTE') as app_can_call_excused, has_function_privilege('anon','cots_private.is_injection(text)','EXECUTE') as visitors_can_call_check" < nul >> tool\last_supabase.txt 2>&1
echo ---- records >> tool\last_supabase.txt
call npx supabase db query --linked "select (select count(*) from public.follow_up_assignments) as zones, (select count(*) from public.eliminations) as removals, (select count(*) from public.captures) as captures" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
