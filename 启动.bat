@echo off
cd /d "%~dp0"

echo.
echo ========================================
echo   Claude Portable Environment
echo ========================================
echo.

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "PATH=%ROOT%\tools\node-v22.14.0-win-x64;%ROOT%\tools\python-full;%ROOT%\tools\python-full\Scripts;%ROOT%\tools\git-full\cmd;%ROOT%\tools\ccswitch;%PATH%"

echo Environment ready
echo.
echo Available commands:
echo   claude      - Claude Code CLI
echo   cc-switch   - Config API relay
echo   python      - Python 3.14.6
echo   git         - Git 2.55.0
echo.
echo Type exit to quit
echo.

cmd /k
