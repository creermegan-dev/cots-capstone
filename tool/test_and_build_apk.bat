@echo off
rem Runs the test suite, then builds the release APK only if all tests pass.
rem Results are written to tool\last_test.txt and tool\last_build.txt.
cd /d "%~dp0.."
echo Running flutter test...
call flutter test > tool\last_test.txt 2>&1
if errorlevel 1 (
  echo TESTS FAILED - APK not built. > tool\last_build.txt
  echo Tests failed. See tool\last_test.txt
  goto done
)
echo Tests passed. Building APK...
call flutter build apk --release --split-per-abi --dart-define=SUPABASE_URL=https://kgfehorbjzhooxnnkfac.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_cnrQpU8FTeBHd_wRwL7EVg_nmphLoN0 > tool\last_build.txt 2>&1
if errorlevel 1 (
  echo Build failed. See tool\last_build.txt
) else (
  echo Build finished.
)
:done
echo DONE> tool\last_run_status.txt
