@echo off
rem Creates the branch supabase-migration and commits the app work. Does NOT push.
cd /d "%~dp0.."
echo Git commit > tool\last_git.txt
git switch -c supabase-migration >> tool\last_git.txt 2>&1
if errorlevel 1 goto done
git add -A -- .gitignore android assets lib test supabase functions scripts docs tool firebase firebase.json pubspec.yaml pubspec.lock linux macos windows >> tool\last_git.txt 2>&1
if errorlevel 1 goto done
echo ---- staged >> tool\last_git.txt
git diff --cached --stat=200 >> tool\last_git.txt 2>&1
git commit -q -F tool\last_commit_message.txt >> tool\last_git.txt 2>&1
echo COMMIT EXIT %errorlevel% >> tool\last_git.txt
echo ---- result >> tool\last_git.txt
git log -1 --format="%%h %%an %%ad %%s" >> tool\last_git.txt 2>&1
git branch --show-current >> tool\last_git.txt 2>&1
echo ---- left uncommitted >> tool\last_git.txt
git status --short >> tool\last_git.txt 2>&1
:done
echo DONE> tool\last_git_status.txt
