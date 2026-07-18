@echo off
echo.
echo [setup] Downloading and installing dependencies...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
if errorlevel 1 (
    echo [FAILED] Setup encountered errors. See above.
) else (
    echo [DONE] All dependencies installed successfully!
    echo Run Æô¶¯.bat to start the environment.
)
echo.
pause
