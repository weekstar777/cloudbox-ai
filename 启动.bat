@echo off
cd /d "%~dp0"

echo.
echo ========================================
echo   cloudbox-ai Portable Environment
echo ========================================
echo.

set "ROOT=%~dp0"
set "ROOT=%ROOT:~0,-1%"
set "PATH=%ROOT%\tools\node-v22.14.0-win-x64;%ROOT%\tools\python-full;%ROOT%\tools\python-full\Scripts;%ROOT%\tools\git-full\cmd;%ROOT%\tools\ccswitch;%PATH%"

rem Config dirs (portable, resolved from this folder's own location)
rem Other tools' config dirs are managed by CCswitch internally
set "CLAUDE_CONFIG_DIR=%ROOT%\configs\.claude"

echo Environment ready
echo.
echo Available commands:
echo   claude      - Claude Code CLI
echo   cc-switch   - Config API relay
echo   python      - Python 3.12.8
echo   git         - Git 2.47.1
echo.
echo Type exit to quit
echo.

cmd /k
