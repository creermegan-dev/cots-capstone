@echo off
rem Commits Stage 7 (location required) on the supabase-migration branch. Does NOT push.
rem Leaves other people's uncommitted work (for example admin filter changes) untouched.
cd /d "%~dp0.."
echo Git commit Stage 7 > tool\last_git.txt
for /f %%b in ('git branch --show-current') do set BRANCH=%%b
if not "%BRANCH%"=="supabase-migration" (
  echo Not on supabase-migration: %BRANCH% - nothing committed >> tool\last_git.txt
  goto done
)
git add -- android/app/src/main/kotlin/com/example/cots_monitor/MainActivity.kt lib/features/user/scan_detection_page.dart lib/models/photo_location_rule.dart lib/services/area_messages.dart lib/services/original_photo_picker.dart supabase/migrations/20261101000300_location_required.sql supabase/tests/database/step17_area_parts.test.sql test/stage7_location_rule_test.dart tool/supabase_stage6_check.bat tool/supabase_backup.bat tool/git_commit_stage7.bat >> tool\last_git.txt 2>&1
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
