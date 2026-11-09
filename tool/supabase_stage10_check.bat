@echo off
rem Stage 10 check (a single SELECT; reads only, changes nothing; --yes only skips the CLI prompt).
cd /d "%~dp0.."
echo Stage 10 check > tool\last_supabase.txt
call npx supabase db query --remote --yes "select to_regclass('public.site_partner_requests') is not null as partner_table, (select count(*) from public.site_partner_requests) as requests, (select count(*) from pg_proc where proname in ('invite_site_partner','respond_site_partner_invite','decide_site_partner','site_teams_json','site_partner_requests_json','site_partner_choices_json')) as app_functions, (select count(*) from pg_trigger where tgname='offer_partner_place') as auto_candidate_trigger, has_table_privilege('authenticated','public.site_partner_requests','SELECT') as app_reads_table_directly, position('partner_at' in pg_get_functiondef('cots_private.zone_review_needed(uuid)'::regprocedure))>0 as partner_rule_on" < nul >> tool\last_supabase.txt 2>&1
echo DONE> tool\last_supabase_status.txt
