@echo off
rem Commits Stage 4 on the supabase-migration branch. Does NOT push.
cd /d "%~dp0.."
echo Git commit Stage 4 > tool\last_git.txt
for /f %%b in ('git branch --show-current') do set BRANCH=%%b
if not "%BRANCH%"=="supabase-migration" (
  echo Not on supabase-migration: %BRANCH% - nothing committed >> tool\last_git.txt
  goto done
)
git add -- lib/features/admin/screens/admin_notifications_screen.dart lib/features/expert/screens/expert_reassignments_screen.dart lib/features/user/follow_up_page.dart lib/features/user/notifications_screen.dart lib/models/app_notification.dart lib/models/area_handover.dart lib/services/supabase_handover_service.dart lib/widgets/area_handover_controls.dart supabase/migrations/20261031000400_area_handover.sql supabase/tests/database/step15_area_handover.test.sql test/stage4_area_handover_test.dart tool/supabase_backup.bat tool/supabase_stage4_check.bat tool/git_commit_stage4.bat >> tool\last_git.txt 2>&1
if errorlevel 1 goto done
echo ---- staged >> tool\last_git.txt
git diff --cached --stat=200 >> tool\last_git.txt 2>&1
git commit -q -F tool\last_commit_message.txt >> tool\last_git.txt 2>&1
echo COMMIT EXIT %errorlevel% >> tool\last_git.txt
echo ---- result >> tool\last_git.txt
git log -4 --format="%%h %%an %%ad %%s" >> tool\last_git.txt 2>&1
git branch --show-current >> tool\last_git.txt 2>&1
echo ---- left uncommitted >> tool\last_git.txt
git status --short >> tool\last_git.txt 2>&1
:done
echo DONE> tool\last_git_status.txt
