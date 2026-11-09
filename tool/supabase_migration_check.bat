@echo off
rem Read-only: lists which database updates are applied on hosted Supabase.
cd /d "%~dp0.."
echo Migration check > tool\last_supabase.txt
call npx supabase migration list --linked < nul >> tool\last_supabase.txt 2>&1
call npx supabase db query --linked "select p.proname, has_function_privilege('authenticated', p.oid, 'execute') as app_can_call, has_function_privilege('anon', p.oid, 'execute') as anon_can_call from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='expert_personnel_directory'" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
