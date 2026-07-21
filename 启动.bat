@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"

rem Pre-flight check: verify tools are installed
if not exist "%ROOT%\tools\node-v22.14.0-win-x64\node.exe" (
    echo.
    echo [ERROR] Tools not installed. Please run setup.bat first.
    echo.
    pause
    exit /b 1
)

echo.
echo ========================================
echo   cloudbox-ai Portable Environment
echo ========================================
echo.

set "PATH=%ROOT%\tools\node-v22.14.0-win-x64;%ROOT%\tools\python-full;%ROOT%\tools\python-full\Scripts;%ROOT%\tools\git-full\cmd;%ROOT%\tools\ccswitch;%PATH%"

rem Config dirs (other tools' config dirs are managed by CCswitch)
set "CLAUDE_CONFIG_DIR=%ROOT%\configs\.claude"

echo Environment ready
echo.
echo Available commands:
echo   claude      - Claude Code CLI
echo   cc-switch   - CC Switch
echo   python      - Python 3.12.8
echo   git         - Git 2.47.1
echo.
echo Type exit to quit
echo.

cmd /k
