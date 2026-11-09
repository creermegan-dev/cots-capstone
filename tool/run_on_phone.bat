@echo off
rem Runs the app on the connected phone (USB debugging on), using hosted Supabase.
rem The publishable key is the public app key (not a secret).
cd /d "%~dp0.."
echo ---- devices > tool\last_run_phone.txt
call flutter devices >> tool\last_run_phone.txt 2>&1
echo ---- run >> tool\last_run_phone.txt
call flutter run --dart-define=SUPABASE_URL=https://kgfehorbjzhooxnnkfac.supabase.co --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_cnrQpU8FTeBHd_wRwL7EVg_nmphLoN0
