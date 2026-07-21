@echo off
chcp 65001 >nul 2>&1
echo.
echo [cleanup] Cleaning up environment variables and registry...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0cleanup.ps1"
echo.
if errorlevel 1 (
    echo [FAILED] Cleanup encountered errors. See above.
) else (
    echo [DONE] Cleanup completed successfully.
)
echo.
pause
