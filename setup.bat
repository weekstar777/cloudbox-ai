@echo off
chcp 65001 >nul 2>&1
echo.
echo [setup] Downloading and installing dependencies...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
if errorlevel 1 (
    echo [FAILED] Setup encountered errors. See above.
) else (
    echo [DONE] All dependencies installed successfully!
    echo Run setup.bat again to check for updates.
)
echo.
pause
