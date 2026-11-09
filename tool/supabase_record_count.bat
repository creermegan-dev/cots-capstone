@echo off
rem Read-only: counts the records in the hosted Supabase database. Changes nothing.
cd /d "%~dp0.."
echo Record count > tool\last_supabase_count.txt
call npx supabase db query --linked "select (select count(*) from public.captures) captures, (select count(*) from public.encounters) encounters, (select count(*) from public.detection_items) detections, (select count(*) from public.eliminations) removals, (select count(*) from public.follow_up_assignments) zone_assignments, (select count(*) from public.follow_up_surveys) monthly_visits, (select count(*) from public.media_assets) photos, (select count(*) from public.workflow_events) events, (select count(*) from public.notifications) notices, (select count(*) from public.profiles) accounts, (select count(*) from storage.objects) stored_files" < nul >> tool\last_supabase_count.txt 2>&1
echo DONE> tool\last_supabase_count_status.txt
