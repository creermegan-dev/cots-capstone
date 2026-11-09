@echo off
rem Runs the app tests only (no APK build). Results in tool\last_test.txt.
cd /d "%~dp0.."
echo Running flutter test...
call flutter test test/supabase_config_test.dart > tool\last_test.txt 2>&1
if errorlevel 1 goto done
rem Older repository fixtures explicitly exercise the Firebase rollback backend.
call flutter test --dart-define=USE_FIREBASE=true >> tool\last_test.txt 2>&1
:done
echo EXIT %errorlevel% >> tool\last_test.txt
echo DONE> tool\last_run_status.txt
