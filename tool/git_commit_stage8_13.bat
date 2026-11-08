@echo off
rem Commits the work since Stage 7 (local only; nothing is pushed). Output in tool\last_git.txt.
cd /d "%~dp0.."
git add lib test supabase assets pubspec.yaml tool zone_maps/samal_sites HANDOFF_FOR_CODEX.md SAMAL_TRIP_PLAN_2026-11-06.md > tool\last_git.txt 2>&1
git commit -F tool\last_commit_message.txt >> tool\last_git.txt 2>&1
echo COMMIT EXIT %errorlevel% >> tool\last_git.txt
git log --oneline -3 >> tool\last_git.txt 2>&1
git status --short >> tool\last_git.txt 2>&1
echo DONE> tool\last_run_status.txt
