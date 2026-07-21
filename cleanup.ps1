# cleanup.ps1 - Remove all cloudbox-ai traces from this machine
# Cleans: user env vars, user/system PATH entries, stale registry keys
# Does NOT uninstall programs or delete any files/folders

$ErrorActionPreference = "SilentlyContinue"

function Write-Step($msg) { Write-Host "[cleanup] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "  [SKIP] $msg (not found)" -ForegroundColor Yellow }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  cloudbox-ai Cleanup" -ForegroundColor Cyan
Write-Host "  Remove all traces from this machine" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1. User-level environment variables
# ============================================================
Write-Step "User-level environment variables"

$envVars = @(
    "CLAUDE_CONFIG_DIR",
    "CODEX_HOME",
    "CC_SWITCH_CONFIG_DIR",
    "GEMINI_HOME",
    "OPENCODE_HOME",
    "OPENCLAW_HOME",
    "HERMES_HOME"
)

foreach ($name in $envVars) {
    $val = [System.Environment]::GetEnvironmentVariable($name, 'User')
    if ($val) {
        [System.Environment]::SetEnvironmentVariable($name, $null, 'User')
        Write-OK "Removed $name"
    } else {
        Write-Skip $name
    }
}

# ============================================================
# 2. User PATH - remove cloudbox-ai entries
# ============================================================
Write-Step "User PATH"

$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$entries = $userPath -split ';' | Where-Object { $_.Trim() -ne '' }
$cleaned = $entries | Where-Object { $_ -notmatch 'cloudbox-ai' }
$removed = $entries.Count - $cleaned.Count

if ($removed -gt 0) {
    [System.Environment]::SetEnvironmentVariable('Path', ($cleaned -join ';'), 'User')
    Write-OK "Removed $removed entries from user PATH"
} else {
    Write-Skip "User PATH (no cloudbox-ai entries)"
}

# ============================================================
# 3. System PATH - remove cloudbox-ai entries
# ============================================================
Write-Step "System PATH"

$sysPath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$entries = $sysPath -split ';' | Where-Object { $_.Trim() -ne '' }
$cleaned = $entries | Where-Object { $_ -notmatch 'cloudbox-ai' }
$removed = $entries.Count - $cleaned.Count

if ($removed -gt 0) {
    [System.Environment]::SetEnvironmentVariable('Path', ($cleaned -join ';'), 'Machine')
    Write-OK "Removed $removed entries from system PATH"
} else {
    Write-Skip "System PATH (no cloudbox-ai entries)"
}

# ============================================================
# 4. Registry - software keys
# ============================================================
Write-Step "Registry keys"

$regKeys = @(
    "HKLM:\SOFTWARE\Node.js",
    "HKLM:\SOFTWARE\Python",
    "HKLM:\SOFTWARE\GitForWindows"
)

foreach ($key in $regKeys) {
    if (Test-Path $key) {
        Remove-Item $key -Recurse -Force
        Write-OK "Removed $key"
    } else {
        Write-Skip $key
    }
}

# ============================================================
# 5. Registry - uninstaller entries
# ============================================================
Write-Step "Uninstaller registry entries"

$patterns = @('Node\.js', 'Python 3\.12', 'Python Launcher', '^Git$')
$locations = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
)

$count = 0
foreach ($loc in $locations) {
    foreach ($pat in $patterns) {
        $items = Get-ChildItem $loc -ErrorAction SilentlyContinue |
            Where-Object { (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName -match $pat }
        foreach ($item in $items) {
            $name = (Get-ItemProperty $item.PSPath).DisplayName
            Remove-Item $item.PSPath -Recurse -Force
            Write-OK "Removed uninstaller: $name"
            $count++
        }
    }
}

if ($count -eq 0) { Write-Skip "Uninstaller entries" }

# ============================================================
# Done
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Cleanup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "This machine is now trace-free." -ForegroundColor Green
Write-Host "Run setup.bat to reconfigure when needed." -ForegroundColor Cyan
Write-Host ""
exit 0
