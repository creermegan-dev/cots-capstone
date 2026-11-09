@echo off
rem Commits the Photo Information fix and Stage 6 (new monitoring map) on the supabase-migration branch. Does NOT push.
rem Leaves other people's uncommitted work (for example admin filter changes) untouched.
cd /d "%~dp0.."
echo Git commit Photo info + Stage 6 > tool\last_git.txt
for /f %%b in ('git branch --show-current') do set BRANCH=%%b
if not "%BRANCH%"=="supabase-migration" (
  echo Not on supabase-migration: %BRANCH% - nothing committed >> tool\last_git.txt
  goto done
)
git add -- lib/features/admin/models/admin_record_table_row.dart lib/features/admin/screens/admin_record_details_screen.dart lib/features/expert/models/expert_action_item.dart lib/features/user/cots_map_page.dart lib/features/user/scan_detection_page.dart lib/features/user/user_record_details_page.dart lib/main.dart lib/models/capture_model.dart lib/models/cots_zone.dart lib/models/davao_gulf_geography.dart lib/models/removal_record_model.dart lib/models/scan_record_model.dart lib/models/zone_review.dart lib/models/photo_source.dart lib/services/area_messages.dart lib/services/capture_service.dart lib/services/follow_up_monitoring_repository.dart lib/services/offline_submission_service.dart lib/services/scan_record_service.dart lib/services/supabase_follow_up_service.dart lib/services/supabase_record_service.dart pubspec.yaml assets/map supabase/migrations/20261101000100_area_parts.sql supabase/migrations/20261101000200_area_wording.sql supabase/tests/database/step13_zone_responsibility.test.sql supabase/tests/database/step17_area_parts.test.sql test/area_map_test.dart test/photo_info_test.dart test/support test/expert_notifications_test.dart test/follow_up_monitoring_model_test.dart test/stage2_zone_review_test.dart test/supabase_follow_up_test.dart tool/supabase_backup.bat tool/supabase_record_count.bat tool/git_commit_stage6.bat zone_maps/final/scripts zone_maps/final/spec.json zone_maps/final/areas_final.csv >> tool\last_git.txt 2>&1
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
