@echo off
rem Commits Stage 3 on the supabase-migration branch. Does NOT push.
cd /d "%~dp0.."
echo Git commit Stage 3 > tool\last_git.txt
for /f %%b in ('git branch --show-current') do set BRANCH=%%b
if not "%BRANCH%"=="supabase-migration" (
  echo Not on supabase-migration: %BRANCH% - nothing committed >> tool\last_git.txt
  goto done
)
git add -- lib/features/admin/models/admin_record_table_row.dart lib/features/admin/screens/admin_reports_screen.dart lib/features/admin/screens/admin_zones_screen.dart lib/features/user/dashboard_screen.dart lib/features/user/user_dashboard_analytics.dart lib/models/capture_model.dart lib/models/monitoring_analytics.dart lib/models/scan_record_model.dart lib/services/admin_report_export_service.dart lib/services/scan_record_repository.dart lib/services/supabase_record_service.dart lib/widgets/monitoring_analytics_panel.dart lib/widgets/monitoring_record_map.dart lib/models/cots_tally.dart test/admin_report_export_service_test.dart test/admin_reports_real_records_test.dart test/monitoring_analytics_test.dart test/stage3_honest_reports_test.dart supabase/migrations/20261031000300_honest_reports.sql supabase/tests/database/step14_honest_reports.test.sql tool/supabase_backup.bat tool/supabase_stage3_check.bat tool/git_commit_stage3.bat >> tool\last_git.txt 2>&1
if errorlevel 1 goto done
echo ---- staged >> tool\last_git.txt
git diff --cached --stat=200 >> tool\last_git.txt 2>&1
git commit -q -F tool\last_commit_message.txt >> tool\last_git.txt 2>&1
echo COMMIT EXIT %errorlevel% >> tool\last_git.txt
echo ---- result >> tool\last_git.txt
git log -3 --format="%%h %%an %%ad %%s" >> tool\last_git.txt 2>&1
git branch --show-current >> tool\last_git.txt 2>&1
echo ---- left uncommitted >> tool\last_git.txt
git status --short >> tool\last_git.txt 2>&1
:done
echo DONE> tool\last_git_status.txt
