@echo off
rem Read-only Stage 1 check: confirms the new table, columns, functions and rules exist. Changes nothing.
cd /d "%~dp0.."
echo Stage 1 check > tool\last_supabase.txt
echo ---- tables >> tool\last_supabase.txt
call npx supabase db query --linked "select c.relname as table_name, c.relrowsecurity as rls_on from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname='encounters'" < nul >> tool\last_supabase.txt 2>&1
echo ---- columns >> tool\last_supabase.txt
call npx supabase db query --linked "select table_name, column_name, is_nullable from information_schema.columns where table_schema='public' and column_name in ('encounter_id','removed_count') order by table_name, column_name" < nul >> tool\last_supabase.txt 2>&1
echo ---- constraints >> tool\last_supabase.txt
call npx supabase db query --linked "select conname from pg_constraint where conname in ('eliminations_encounter_count') or conrelid='public.encounters'::regclass order by conname" < nul >> tool\last_supabase.txt 2>&1
echo ---- functions >> tool\last_supabase.txt
call npx supabase db query --linked "select n.nspname as schema, p.proname as fn from pg_proc p join pg_namespace n on n.oid=p.pronamespace where p.proname in ('encounter_summary','submit_follow_up_survey','capture_confirmed_count','survey_confirmed_count','check_capture_encounter','check_elimination_encounter') order by 1,2" < nul >> tool\last_supabase.txt 2>&1
echo ---- policies >> tool\last_supabase.txt
call npx supabase db query --linked "select tablename, policyname from pg_policies where schemaname='public' and tablename in ('encounters','eliminations') order by 1,2" < nul >> tool\last_supabase.txt 2>&1
echo ---- records >> tool\last_supabase.txt
call npx supabase db query --linked "select (select count(*) from public.captures) as captures, (select count(*) from public.eliminations) as removals, (select count(*) from public.encounters) as encounters" < nul >> tool\last_supabase.txt 2>&1
echo ---- jobs >> tool\last_supabase.txt
call npx supabase db query --linked "select jobname, active from cron.job" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
