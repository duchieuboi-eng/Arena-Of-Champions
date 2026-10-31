@echo off
setlocal enabledelayedexpansion
title Arena Of Champions - Rojo ^& Roblox Studio

cd /d "%~dp0"

echo ===================================================
echo     Arena Of Champions - Rojo ^& Roblox Studio
echo ===================================================
echo.

:: 1. Ensure Rojo is installed and plugin is installed
if not exist "%~dp0rojo.exe" (
    echo [INFO] rojo.exe not found. Downloading latest Rojo...
    powershell -NoProfile -Command "Invoke-WebRequest -Uri 'https://github.com/rojo-rbx/rojo/releases/download/v7.7.1/rojo-7.7.1-windows-x86_64.zip' -OutFile '%~dp0rojo.zip'; Expand-Archive -Path '%~dp0rojo.zip' -DestinationPath '%~dp0' -Force; Remove-Item '%~dp0rojo.zip' -Force"
)

if not exist "%LOCALAPPDATA%\Roblox\Plugins\RojoManagedPlugin.rbxm" (
    echo [INFO] Installing Rojo Studio plugin...
    "%~dp0rojo.exe" plugin install
)

:: 2. Locate Roblox Studio
set "STUDIO_PATH="

for /d %%i in ("%LOCALAPPDATA%\Roblox\Versions\*") do (
    if exist "%%i\RobloxStudioBeta.exe" set "STUDIO_PATH=%%i\RobloxStudioBeta.exe"
)

if not defined STUDIO_PATH (
    for /d %%i in ("%ProgramFiles%\Roblox\Versions\*") do (
        if exist "%%i\RobloxStudioBeta.exe" set "STUDIO_PATH=%%i\RobloxStudioBeta.exe"
    )
)

if not defined STUDIO_PATH (
    for /d %%i in ("%ProgramFiles(x86)%\Roblox\Versions\*") do (
        if exist "%%i\RobloxStudioBeta.exe" set "STUDIO_PATH=%%i\RobloxStudioBeta.exe"
    )
)

:: Check if a place file was provided as argument or exists in the directory
set "PLACE_FILE="
if "%~1" neq "" (
    if exist "%~1" set "PLACE_FILE=%~1"
) else (
    for %%F in ("%~dp0*.rbxl" "%~dp0*.rbxlx") do (
        if exist "%%F" if not defined PLACE_FILE set "PLACE_FILE=%%~fF"
    )
)

:: 3. Launch Roblox Studio
if defined STUDIO_PATH (
    if defined PLACE_FILE (
        echo [INFO] Launching Roblox Studio with place: !PLACE_FILE!...
        start "" "!STUDIO_PATH!" "!PLACE_FILE!"
    ) else (
        echo [INFO] Launching Roblox Studio...
        start "" "!STUDIO_PATH!"
    )
) else (
    echo [INFO] Launching Roblox Studio via URL protocol...
    start roblox-studio:
)

:: 4. Start Rojo Server
echo.
echo [INFO] Starting Rojo server (listening for Studio plugin connection)...
echo [TIP]  In Roblox Studio, click the Rojo plugin icon and click "Connect".
echo ===================================================
echo.

"%~dp0rojo.exe" serve "%~dp0default.project.json"

if errorlevel 1 (
    echo.
    echo [ERROR] Rojo server exited unexpectedly.
    pause
)
