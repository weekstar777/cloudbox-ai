# setup.ps1 - One-click dependency installer for cloudbox-ai portable environment
<<<<<<< HEAD
# Downloads: Node.js, Python, Git, CCswitch (MSI full installer), claude-code CLI
# Configures: CLAUDE_CONFIG_DIR (user-level), portable Node.js in user PATH

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
=======
# Downloads: Node.js, Python, Git, CCswitch, claude-code CLI
# Configures: CLAUDE_CONFIG_DIR (user-level), portable Node.js in user PATH

$ErrorActionPreference = "Stop"
>>>>>>> ae99286c746c46257465c70671cd5d8063c7ba63
$root = $PSScriptRoot
if (-not $root) { $root = Get-Location }
$toolsDir = Join-Path $root "tools"

function Write-Step($msg) { Write-Host "[setup] $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Err($msg)  { Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Write-Skip($msg) { Write-Host "  [SKIP] $msg (already installed)" -ForegroundColor Yellow }

function Download-File($url, $out) {
    Write-Host "  Downloading: $url"
    $ProgressPreference = "SilentlyContinue"
    try {
        Invoke-WebRequest -Uri $url -OutFile $out -UseBasicParsing
    } catch {
<<<<<<< HEAD
        Write-Host "  Invoke-WebRequest failed, trying curl.exe..." -ForegroundColor Yellow
        $ErrorActionPreference = "SilentlyContinue"
        & curl.exe -L -o $out $url
=======
        $ErrorActionPreference = "SilentlyContinue"
        & curl.exe -L -o $out $url 2>$null
>>>>>>> ae99286c746c46257465c70671cd5d8063c7ba63
        $ErrorActionPreference = "Stop"
    }
    $ProgressPreference = "Continue"
    if (-not (Test-Path $out)) { throw "Download failed: $url" }
}

if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }

# ============================================================
# 0. Initialize configs directory
# ============================================================
Write-Step "Initializing configs directory"
$configsDir = Join-Path $root "configs"
$configSubDirs = @(".cc-switch", ".claude", ".codex", ".gemini", "opencode", ".openclaw", ".hermes")
foreach ($sub in $configSubDirs) {
    $dir = Join-Path $configsDir $sub
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-OK "Created configs\$sub"
    }
}
Write-OK "configs directory ready"

# ============================================================
# 1. Node.js v22.14.0
# ============================================================
$nodeDir = Join-Path $toolsDir "node-v22.14.0-win-x64"
Write-Step "Node.js v22.14.0"
if (Test-Path (Join-Path $nodeDir "node.exe")) {
    Write-Skip "Node.js"
} else {
    $zip = Join-Path $toolsDir "node.zip"
    Download-File "https://nodejs.org/dist/v22.14.0/node-v22.14.0-win-x64.zip" $zip
    Write-Host "  Extracting..."
    Expand-Archive -Path $zip -DestinationPath $toolsDir -Force
    Remove-Item $zip -Force
    if (Test-Path (Join-Path $nodeDir "node.exe")) { Write-OK "Node.js installed" }
    else { Write-Err "Node.js extraction failed"; exit 1 }
}

# ============================================================
# 2. Python 3.12.8
# ============================================================
$pyDir = Join-Path $toolsDir "python-full"
Write-Step "Python 3.12.8"
if (Test-Path (Join-Path $pyDir "python.exe")) {
    Write-Skip "Python"
} else {
    $zip = Join-Path $toolsDir "python.zip"
    Download-File "https://www.nuget.org/api/v2/package/python/3.12.8" $zip
    Write-Host "  Extracting..."
    $tmp = Join-Path $toolsDir "python-nuget"
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $src = Join-Path $tmp "tools"
    if (Test-Path $src) {
        if (Test-Path $pyDir) { Remove-Item $pyDir -Recurse -Force }
        Move-Item $src $pyDir
    }
    Remove-Item $tmp -Recurse -Force
    Remove-Item $zip -Force

    # Install pip
    Write-Host "  Installing pip..."
    $getPip = Join-Path $pyDir "get-pip.py"
    Download-File "https://bootstrap.pypa.io/get-pip.py" $getPip
    $pth = Join-Path $pyDir "python312._pth"
    if (Test-Path $pth) {
        @("python312.zip", ".", "import site") | Set-Content -Path $pth
    }
    $ErrorActionPreference = "SilentlyContinue"
    & (Join-Path $pyDir "python.exe") $getPip --quiet 2>$null
    $ErrorActionPreference = "Stop"
    Remove-Item $getPip -Force -ErrorAction SilentlyContinue

    if (Test-Path (Join-Path $pyDir "python.exe")) { Write-OK "Python installed (with pip)" }
    else { Write-Err "Python installation failed"; exit 1 }
}

# ============================================================
# 3. Git (PortableGit)
# ============================================================
$gitDir = Join-Path $toolsDir "git-full"
Write-Step "Git (PortableGit)"
if (Test-Path (Join-Path $gitDir "cmd\git.exe")) {
    Write-Skip "Git"
} else {
    $exe = Join-Path $toolsDir "PortableGit.exe"
    Download-File "https://registry.npmmirror.com/-/binary/git-for-windows/v2.47.1.windows.1/PortableGit-2.47.1-64-bit.7z.exe" $exe
    Write-Host "  Extracting (this may take a moment)..."
    if (Test-Path $gitDir) { Remove-Item $gitDir -Recurse -Force }
    New-Item -ItemType Directory -Path $gitDir -Force | Out-Null
    $ErrorActionPreference = "SilentlyContinue"
    & $exe ("-o" + $gitDir) -y 2>$null | Out-Null
    $ErrorActionPreference = "Stop"
    Start-Sleep -Seconds 5
    Remove-Item $exe -Force -ErrorAction SilentlyContinue
    if (Test-Path (Join-Path $gitDir "cmd\git.exe")) { Write-OK "Git installed" }
    else { Write-Err "Git extraction failed"; exit 1 }
}

# ============================================================
<<<<<<< HEAD
# 4. CCswitch (latest MSI from GitHub)
# ============================================================
Write-Step "CCswitch"
# Detect existing installation
$ccsExe = $null
$candidatePaths = @(
    (Join-Path $toolsDir "ccswitch\CC Switch.exe"),
    "$env:ProgramFiles\CC-Switch\CC Switch.exe",
    "${env:ProgramFiles(x86)}\CC-Switch\CC Switch.exe",
    "$env:LOCALAPPDATA\CC-Switch\CC Switch.exe",
    "$env:LOCALAPPDATA\Programs\CC-Switch\CC Switch.exe",
    "$env:LOCALAPPDATA\Programs\CC Switch\CC Switch.exe"
)
foreach ($p in $candidatePaths) {
    if (Test-Path $p) { $ccsExe = $p; break }
}
if (-not $ccsExe) {
    $ccsCmd = Get-Command "CC Switch" -ErrorAction SilentlyContinue
    if ($ccsCmd) { $ccsExe = $ccsCmd.Source }
}
if ($ccsExe) {
    Write-Skip "CCswitch"
} else {
    # Clean up old portable CCswitch directory (from previous setup versions)
    $oldCcsDir = Join-Path $toolsDir "ccswitch"
    if (Test-Path $oldCcsDir) {
        Write-Host "  Removing old portable CCswitch..."
        Remove-Item $oldCcsDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "Old portable CCswitch removed"
    }

    # Remove stale MSI registration from any previous failed install
    $ErrorActionPreference = "SilentlyContinue"
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($regPath in $uninstallPaths) {
        Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -match "CC\s*Switch") {
                Write-Host "  Removing stale CCswitch registration: $($props.DisplayName)"
                $prodCode = $_.PSChildName
                # Try silent uninstall of the stale registration
                Start-Process msiexec -ArgumentList "/x `"$prodCode`" /quiet /norestart" -Wait -ErrorAction SilentlyContinue
                Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-OK "Stale registration removed"
            }
        }
    }
    $ErrorActionPreference = "Stop"

    # Check for pending reboot
    $rebootPending = $false
    try {
        $pfro = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name PendingFileRenameOperations -ErrorAction Stop
        if ($pfro.PendingFileRenameOperations) { $rebootPending = $true }
    } catch {}
    if ($rebootPending) {
        Write-Host "  [WARN] System has a pending reboot (MsiSystemRebootPending)." -ForegroundColor Yellow
        Write-Host "  Attempting install anyway; if it fails, reboot and re-run setup." -ForegroundColor Yellow
    }

    Write-Host "  Querying GitHub for latest release..."
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/farion1231/cc-switch/releases/latest" -UseBasicParsing
        $asset = $rel.assets | Where-Object { $_.name -match "Windows\.msi$" -and $_.name -notmatch "arm64" } | Select-Object -First 1
        if ($asset) {
            $ccsDir = Join-Path $toolsDir "ccswitch"
            $msi = Join-Path $env:TEMP "ccswitch-setup.msi"
            Download-File $asset.browser_download_url $msi
            Write-Host "  Installing CCswitch (MSI) to $ccsDir ..."
            if (-not (Test-Path $ccsDir)) { New-Item -ItemType Directory -Path $ccsDir -Force | Out-Null }
            $msiLog = Join-Path $toolsDir "ccswitch-install.log"
            $msiArgs = "/i `"$msi`" INSTALLDIR=`"$ccsDir`" /quiet /norestart /log `"$msiLog`""
            $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
            if ($isAdmin) {
                $proc = Start-Process msiexec -ArgumentList $msiArgs -Wait -PassThru
            } else {
                $proc = Start-Process msiexec -ArgumentList $msiArgs -Wait -PassThru -Verb RunAs
            }
            Remove-Item $msi -Force -ErrorAction SilentlyContinue
            if ($proc.ExitCode -eq 0) {
                Remove-Item $msiLog -Force -ErrorAction SilentlyContinue
                Write-OK "CCswitch installed (MSI)"
            } else {
                Write-Err "CCswitch MSI install failed (exit code $($proc.ExitCode))"
                if ($rebootPending) {
                    Write-Host "  A system reboot is pending. Please reboot and re-run setup.bat." -ForegroundColor Yellow
                }
                if (Test-Path $msiLog) {
                    Write-Host "  Install log: $msiLog" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Err "Windows MSI asset not found in release"
=======
# 4. CCswitch (latest from GitHub)
# ============================================================
$ccsDir = Join-Path $toolsDir "ccswitch"
Write-Step "CCswitch"
if (Test-Path (Join-Path $ccsDir "*.exe")) {
    Write-Skip "CCswitch"
} else {
    Write-Host "  Querying GitHub for latest release..."
    try {
        $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/farion1231/cc-switch/releases/latest" -UseBasicParsing
        $asset = $rel.assets | Where-Object { $_.name -match "Windows-Portable.zip" -and $_.name -notmatch "arm64" } | Select-Object -First 1
        if ($asset) {
            $zip = Join-Path $toolsDir "ccswitch.zip"
            Download-File $asset.browser_download_url $zip
            Write-Host "  Extracting..."
            if (Test-Path $ccsDir) { Remove-Item $ccsDir -Recurse -Force }
            Expand-Archive -Path $zip -DestinationPath $ccsDir -Force
            Remove-Item $zip -Force
            # Flatten subdirectory if exists
            $sub = Get-ChildItem $ccsDir -Directory | Select-Object -First 1
            if ($sub -and -not (Test-Path (Join-Path $ccsDir "*.exe"))) {
                Get-ChildItem $sub.FullName | Move-Item -Destination $ccsDir -Force
                Remove-Item $sub.FullName -Force -Recurse -ErrorAction SilentlyContinue
            }
            Write-OK "CCswitch installed"
        } else {
            Write-Err "Windows Portable asset not found in release"
>>>>>>> ae99286c746c46257465c70671cd5d8063c7ba63
        }
    } catch {
        Write-Err "GitHub query failed: $_"
    }
}

# ============================================================
# 5. claude-code CLI
# ============================================================
Write-Step "claude-code CLI"
$claudeCmd = Join-Path $nodeDir "claude.cmd"
if (Test-Path $claudeCmd) {
    Write-Skip "claude-code"
} else {
    Write-Host "  Installing via npm (may take a few minutes)..."
    $env:PATH = "$nodeDir;$env:PATH"
    $ErrorActionPreference = "SilentlyContinue"
<<<<<<< HEAD
    & (Join-Path $nodeDir "npm.cmd") install -g "@anthropic-ai/claude-code" | Out-Null
=======
    & (Join-Path $nodeDir "npm.cmd") install -g "@anthropic-ai/claude-code" 2>&1 | Out-Null
>>>>>>> ae99286c746c46257465c70671cd5d8063c7ba63
    $ErrorActionPreference = "Stop"
    if (Test-Path $claudeCmd) { Write-OK "claude-code CLI installed" }
    else { Write-Err "claude-code installation failed"; exit 1 }
}

# ============================================================
# 6. Set user-level environment variables (portable config dirs)
# ============================================================
Write-Step "Setting user-level environment variables"

$envVars = @{
    "CLAUDE_CONFIG_DIR"    = Join-Path $root "configs\.claude"
<<<<<<< HEAD
    "CODEX_HOME"           = Join-Path $root "configs\.codex"
    "CC_SWITCH_CONFIG_DIR" = Join-Path $root "configs\.cc-switch"
    "GEMINI_HOME"          = Join-Path $root "configs\.gemini"
    "OPENCODE_HOME"        = Join-Path $root "configs\opencode"
    "OPENCLAW_HOME"        = Join-Path $root "configs\.openclaw"
    "HERMES_HOME"          = Join-Path $root "configs\.hermes"
=======
>>>>>>> ae99286c746c46257465c70671cd5d8063c7ba63
}

foreach ($name in $envVars.Keys) {
    $desired = $envVars[$name]
    $current = [System.Environment]::GetEnvironmentVariable($name, 'User')
    if ($current -ne $desired) {
        [System.Environment]::SetEnvironmentVariable($name, $desired, 'User')
        Write-OK "$name = $desired"
    } else {
        Write-Skip "$name"
    }
}

# Add portable Node.js to user PATH (if not already present)
$nodeAbsDir = $nodeDir
$userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
$pathEntries = $userPath -split ';' | Where-Object { $_.Trim() -ne '' }

# Remove stale cloudbox node paths (old versions)
$cleanedEntries = $pathEntries | Where-Object { $_ -notmatch 'cloudbox-ai\\tools\\node-' }
# Add current portable node path
if ($cleanedEntries -notcontains $nodeAbsDir) {
    $cleanedEntries = @($nodeAbsDir) + $cleanedEntries
    Write-OK "Added $nodeAbsDir to user PATH"
} else {
    Write-Skip "Node.js in user PATH"
}
$newPath = ($cleanedEntries | Select-Object -Unique) -join ';'
if ($newPath -ne $userPath) {
    [System.Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
}

Write-OK "Environment variables configured"

# ============================================================
# Verify all
# ============================================================
Write-Host ""
Write-Step "Verification"
$env:PATH = "$nodeDir;$pyDir;$(Join-Path $gitDir 'cmd');$env:PATH"

$ErrorActionPreference = "SilentlyContinue"
<<<<<<< HEAD
$nv = & (Join-Path $nodeDir "node.exe") --version; Write-OK "Node.js $nv"
$pv = & (Join-Path $pyDir "python.exe") --version; Write-OK "$pv"
$gv = & (Join-Path $gitDir "cmd\git.exe") --version; Write-OK "$gv"
$cv = & $claudeCmd --version; Write-OK "claude $cv"
=======
$nv = & (Join-Path $nodeDir "node.exe") --version 2>&1; Write-OK "Node.js $nv"
$pv = & (Join-Path $pyDir "python.exe") --version 2>&1; Write-OK "$pv"
$gv = & (Join-Path $gitDir "cmd\git.exe") --version 2>&1; Write-OK "$gv"
$cv = & $claudeCmd --version 2>&1; Write-OK "claude $cv"
>>>>>>> ae99286c746c46257465c70671cd5d8063c7ba63
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Setup complete! All dependencies installed." -ForegroundColor Green
Write-Host ""
exit 0
