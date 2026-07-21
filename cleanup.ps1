# cleanup.ps1 - Remove all cloudbox-ai traces from this machine
# Cleans: user env vars, user/system PATH entries, CCswitch MSI
# Does NOT uninstall Node.js/Python/Git (they are portable, just delete tools/)
# Does NOT delete any files/folders

$ErrorActionPreference = "SilentlyContinue"

function Write-Step($msg) { Write-Host "[cleanup] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "  [SKIP] $msg (not found)" -ForegroundColor Yellow }
function Write-Warn($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow }

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
# 3. System PATH - remove cloudbox-ai entries (requires admin)
# ============================================================
Write-Step "System PATH"

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

$sysPath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
$entries = $sysPath -split ';' | Where-Object { $_.Trim() -ne '' }
$cleaned = $entries | Where-Object { $_ -notmatch 'cloudbox-ai' }
$removed = $entries.Count - $cleaned.Count

if ($removed -gt 0) {
    if ($isAdmin) {
        [System.Environment]::SetEnvironmentVariable('Path', ($cleaned -join ';'), 'Machine')
        Write-OK "Removed $removed entries from system PATH"
    } else {
        Write-Warn "Found $removed cloudbox-ai entries in system PATH but need admin rights to remove"
        Write-Warn "Re-run cleanup.bat as Administrator to clean system PATH"
    }
} else {
    Write-Skip "System PATH (no cloudbox-ai entries)"
}

# ============================================================
# 4. Uninstall CCswitch (MSI)
# ============================================================
Write-Step "CCswitch MSI"

$ccsUninstalled = $false
$uninstallPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
)
foreach ($regPath in $uninstallPaths) {
    Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
        $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
        if ($props.DisplayName -match "CC\s*Switch") {
            $code = $_.PSChildName
            Write-Host "  Uninstalling: $($props.DisplayName)..."
            $proc = Start-Process msiexec -ArgumentList "/x `"$code`" /quiet /norestart" -Wait -PassThru
            if ($proc.ExitCode -eq 0) {
                Write-OK "CCswitch uninstalled"
                $ccsUninstalled = $true
            } else {
                Write-Warn "CCswitch uninstall returned exit code $($proc.ExitCode)"
            }
        }
    }
}
if (-not $ccsUninstalled) { Write-Skip "CCswitch MSI" }

# ============================================================
# Done
# ============================================================
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Cleanup complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "This machine is now trace-free." -ForegroundColor Green
Write-Host "To also remove files, manually delete the cloudbox-ai folder." -ForegroundColor Cyan
Write-Host "Run setup.bat to reconfigure when needed." -ForegroundColor Cyan
Write-Host ""
exit 0
