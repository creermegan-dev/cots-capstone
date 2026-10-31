@echo off
rem Commits Stage 2 on the supabase-migration branch. Does NOT push.
cd /d "%~dp0.."
echo Git commit Stage 2 > tool\last_git.txt
for /f %%b in ('git branch --show-current') do set BRANCH=%%b
if not "%BRANCH%"=="supabase-migration" (
  echo Not on supabase-migration: %BRANCH% - nothing committed >> tool\last_git.txt
  goto done
)
git add -- lib/features/admin/models/admin_record_table_row.dart lib/features/admin/screens/admin_notifications_screen.dart lib/features/admin/screens/admin_record_details_screen.dart lib/features/user/notifications_screen.dart lib/features/user/scan_detection_page.dart lib/models/app_notification.dart lib/models/capture_model.dart lib/models/scan_record_model.dart lib/services/supabase_record_service.dart lib/models/zone_review.dart supabase/migrations/20261031000200_zone_responsibility.sql supabase/tests/database/step13_zone_responsibility.test.sql test/stage2_zone_review_test.dart tool/supabase_backup.bat tool/supabase_stage2_check.bat tool/git_commit_stage2.bat >> tool\last_git.txt 2>&1
if errorlevel 1 goto done
echo ---- staged >> tool\last_git.txt
git diff --cached --stat=200 >> tool\last_git.txt 2>&1
git commit -q -F tool\last_commit_message.txt >> tool\last_git.txt 2>&1
echo COMMIT EXIT %errorlevel% >> tool\last_git.txt
echo ---- result >> tool\last_git.txt
git log -2 --format="%%h %%an %%ad %%s" >> tool\last_git.txt 2>&1
git branch --show-current >> tool\last_git.txt 2>&1
echo ---- left uncommitted >> tool\last_git.txt
git status --short >> tool\last_git.txt 2>&1
:done
echo DONE> tool\last_git_status.txt
