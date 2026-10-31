@echo off
rem Commits the Expert Notifications tab and Stage 5 on the supabase-migration branch. Does NOT push.
cd /d "%~dp0.."
echo Git commit Notifications tab + Stage 5 > tool\last_git.txt
for /f %%b in ('git branch --show-current') do set BRANCH=%%b
if not "%BRANCH%"=="supabase-migration" (
  echo Not on supabase-migration: %BRANCH% - nothing committed >> tool\last_git.txt
  goto done
)
git add -- lib/features/admin/screens/admin_notifications_screen.dart lib/features/expert/screens/expert_reassignments_screen.dart lib/features/expert/screens/expert_shell_screen.dart lib/features/expert/screens/expert_notifications_screen.dart lib/features/expert/models/expert_action_item.dart test/expert_notifications_test.dart lib/features/expert/screens/expert_assessments_screen.dart lib/features/user/user_record_details_page.dart lib/models/activity_type.dart lib/models/follow_up_monitoring_model.dart lib/widgets/early_visit_flag.dart supabase/migrations/20261031000500_injection_rules.sql supabase/tests/database/step16_injection_rules.test.sql test/stage5_injection_rules_test.dart tool/supabase_backup.bat tool/supabase_stage5_check.bat tool/git_commit_stage5.bat >> tool\last_git.txt 2>&1
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
