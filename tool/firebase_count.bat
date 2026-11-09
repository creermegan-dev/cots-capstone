@echo off
rem READ-ONLY: counts what is stored in Firebase (numbers and dates only).
rem Finds the cots-monitor-firebase-adminsdk-*.json key in your user folder.
cd /d "%~dp0.."
set "KEY="
if exist "backups\cots-monitor-firebase-adminsdk-temp.json" set "KEY=%CD%\backups\cots-monitor-firebase-adminsdk-temp.json"
for /f "delims=" %%F in ('dir /b /s /o-d "%USERPROFILE%\Downloads\cots-monitor-firebase-adminsdk-*.json" "%USERPROFILE%\OneDrive\Downloads\cots-monitor-firebase-adminsdk-*.json" "%USERPROFILE%\Desktop\cots-monitor-firebase-adminsdk-*.json" 2^>nul') do if not defined KEY set "KEY=%%F"
if not defined KEY for /f "delims=" %%F in ('where /r "%USERPROFILE%" cots-monitor-firebase-adminsdk-*.json 2^>nul') do if not defined KEY set "KEY=%%F"
if not defined KEY (
  echo NO KEY FOUND anywhere in your user folder. > tool\last_firebase_count.txt
  goto done
)
echo Key found in: %KEY% > tool\last_firebase_count.txt
set "GOOGLE_APPLICATION_CREDENTIALS=%KEY%"
node tool\firebase_count.cjs >> tool\last_firebase_count.txt 2>&1
:done
echo DONE> tool\last_firebase_status.txt
