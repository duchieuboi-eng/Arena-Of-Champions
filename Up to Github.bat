@echo off
setlocal enabledelayedexpansion
title Arena Of Champions - Push to GitHub
color 0B

cd /d "%~dp0"

echo ===================================================
echo     Arena Of Champions - Up to GitHub Territory
echo ===================================================
echo.

:: 1. Check if git is installed
where git >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Git is not installed or not in PATH!
    echo Please install Git from https://git-scm.com/
    pause
    exit /b 1
)

:: 2. Ensure git repo and remote are configured
if not exist ".git" (
    echo [INFO] Initializing new Git repository...
    git init -b main
)

git remote get-url origin >nul 2>&1
if errorlevel 1 (
    echo [INFO] Setting remote origin to GitHub territory...
    git remote add origin https://github.com/duchieuboi-eng/Arena-Of-Champions.git
)

:: 3. Show current status
echo [STATUS] Checking workspace changes...
git status --short
echo.

:: 4. Get commit message
set "COMMIT_MSG="
if "%~1" neq "" (
    set "COMMIT_MSG=%~1"
) else (
    echo Enter a commit message, or press [ENTER] to use default timestamp:
    set /p "COMMIT_MSG=> "
)

if "!COMMIT_MSG!"=="" (
    for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value 2^>nul') do set "dt=%%I"
    if defined dt (
        set "TIMESTAMP=!dt:~0,4!-!dt:~4,2!-!dt:~6,2! !dt:~8,2!:!dt:~10,2!"
        set "COMMIT_MSG=Update code - !TIMESTAMP!"
    ) else (
        set "COMMIT_MSG=Update code - %date% %time%"
    )
)

:: 5. Stage all changes
echo.
echo [INFO] Staging all files...
git add -A

:: 6. Commit changes if any exist
git diff --cached --quiet
if errorlevel 1 (
    echo [INFO] Committing changes with message: "!COMMIT_MSG!"
    git commit -m "!COMMIT_MSG!"
) else (
    echo [INFO] No local changes detected to commit.
)

:: 7. Push to GitHub
echo.
echo [INFO] Pushing code to GitHub territory (origin/main)...
echo.
git push -u origin main

if errorlevel 1 (
    echo.
    echo ===================================================
    echo  [ERROR] Push failed!
    echo  Checking if remote has newer commits...
    echo ===================================================
    set /p "TRY_PULL=Attempt to pull and retry push? (Y/N, default Y): "
    if /i "!TRY_PULL!" neq "N" (
        echo [INFO] Pulling remote changes...
        git pull --rebase origin main
        echo [INFO] Retrying push...
        git push -u origin main
    )
)

if not errorlevel 1 (
    echo.
    echo ===================================================
    echo  SUCCESS! All code is up in GitHub territory!
    echo  Repository: https://github.com/duchieuboi-eng/Arena-Of-Champions
    echo ===================================================
)

echo.
pause
