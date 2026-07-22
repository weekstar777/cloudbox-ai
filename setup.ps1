# setup.ps1 - One-click dependency installer for cloudbox-ai portable environment
# Downloads: Node.js, Python, Git, CCswitch (MSI full installer), claude-code CLI
# Configures: CLAUDE_CONFIG_DIR (user-level), portable Node.js in user PATH

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
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
        Write-Host "  Invoke-WebRequest failed, trying curl.exe..." -ForegroundColor Yellow
        $ErrorActionPreference = "SilentlyContinue"
        & curl.exe -L -o $out $url
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
# 4. CCswitch (latest MSI from GitHub, auto-updates if newer)
# ============================================================
Write-Step "CCswitch"
# Detect existing installation
$ccsExe = $null
$candidatePaths = @(
    (Join-Path $toolsDir "ccswitch\cc-switch.exe"),
    (Join-Path $toolsDir "ccswitch\CC Switch.exe"),
    "$env:ProgramFiles\CC-Switch\cc-switch.exe",
    "${env:ProgramFiles(x86)}\CC-Switch\cc-switch.exe",
    "$env:LOCALAPPDATA\CC-Switch\cc-switch.exe",
    "$env:LOCALAPPDATA\Programs\CC-Switch\cc-switch.exe",
    "$env:LOCALAPPDATA\Programs\CC Switch\cc-switch.exe",
    "$env:LOCALAPPDATA\Programs\CC Switch\CC Switch.exe"
)
foreach ($p in $candidatePaths) {
    if (Test-Path $p) { $ccsExe = $p; break }
}
if (-not $ccsExe) {
    $ccsCmd = Get-Command "cc-switch" -ErrorAction SilentlyContinue
    if (-not $ccsCmd) { $ccsCmd = Get-Command "CC Switch" -ErrorAction SilentlyContinue }
    if ($ccsCmd) { $ccsExe = $ccsCmd.Source }
}

# Determine installed version and latest available version
$installedVer = $null
if ($ccsExe) {
    try { $installedVer = [version]((Get-Item $ccsExe).VersionInfo.ProductVersion -replace '[^\d.].*$','') } catch {}
}
$latestVer = $null
$latestAsset = $null
try {
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/farion1231/cc-switch/releases/latest" -UseBasicParsing
    $latestAsset = $rel.assets | Where-Object { $_.name -match "Windows\.msi$" -and $_.name -notmatch "arm64" } | Select-Object -First 1
    if ($rel.tag_name -match '(\d+\.\d+\.\d+)') { $latestVer = [version]$Matches[1] }
} catch {
    Write-Host "  [WARN] Could not query GitHub for latest version." -ForegroundColor Yellow
}

# Decide: skip (up to date), update (newer available), or install (not present)
$needInstall = $false
if ($ccsExe) {
    if ($latestVer -and $installedVer -and $latestVer -gt $installedVer) {
        Write-Host "  Update available: v$installedVer -> v$latestVer" -ForegroundColor Cyan
        $needInstall = $true
    } else {
        $verText = if ($installedVer) { " (v$installedVer)" } else { "" }
        Write-Skip "CCswitch$verText"
    }
} else {
    $needInstall = $true
}

if (-not $needInstall) {
    # up to date, nothing to do
} else {
    # Clean up old portable CCswitch directory (from previous setup versions)
    $oldCcsDir = Join-Path $toolsDir "ccswitch"
    if (Test-Path $oldCcsDir) {
        Write-Host "  Removing old portable CCswitch..."
        Remove-Item $oldCcsDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "Old portable CCswitch removed"
    }

    # ── Thorough uninstall of any existing CC Switch ──────────────────
    # The MSI upgrade path (RemoveExistingProducts) fails with Error 1714/1612
    # when the Windows Installer cached MSI is missing or corrupted.
    # Strategy: force-uninstall via WMI first, then surgically remove every
    # trace from the registry so the new MSI installs as a clean first-time.

    $ErrorActionPreference = "SilentlyContinue"

    # Step 1: Try WMI uninstall (handles missing cached MSI better than msiexec /x)
    $wmiProduct = Get-WmiObject Win32_Product -Filter "Name LIKE '%CC%Switch%'" -ErrorAction SilentlyContinue
    if ($wmiProduct) {
        Write-Host "  Uninstalling CC Switch via WMI: $($wmiProduct.Name) v$($wmiProduct.Version)..."
        $wmiResult = $wmiProduct.Uninstall()
        if ($wmiResult.ReturnValue -eq 0) {
            Write-OK "CC Switch uninstalled via WMI"
        } else {
            Write-Host "  WMI uninstall returned $($wmiResult.ReturnValue), continuing with manual cleanup..." -ForegroundColor Yellow
        }
    }

    # Step 2: Try msiexec /x for each product code found in Uninstall keys
    $uninstallPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($regPath in $uninstallPaths) {
        Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($props.DisplayName -match "CC\s*Switch") {
                $prodCode = $_.PSChildName
                Write-Host "  Trying msiexec /x $prodCode ..."
                $p = Start-Process msiexec -ArgumentList "/x `"$prodCode`" /quiet /norestart" -Wait -PassThru -ErrorAction SilentlyContinue
                if ($p -and $p.ExitCode -eq 0) { Write-OK "msiexec /x succeeded" }
                # Remove the Uninstall key regardless (force cleanup)
                Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    # Step 3: Remove Windows Installer internal database entries
    # These are what FindRelatedProducts uses; if any remain, the new MSI
    # will try RemoveExistingProducts and fail.

    # 3a: Collect compressed product GUIDs from Products keys
    $installerProductPaths = @(
        "HKCR:\Installer\Products",
        "HKLM:\SOFTWARE\Classes\Installer\Products"
    )
    $ccsCompressedGuids = @()
    foreach ($regPath in $installerProductPaths) {
        Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($props.ProductName -match "CC\s*Switch") {
                $ccsCompressedGuids += $_.PSChildName
                Write-Host "  Found Installer Product: $($props.ProductName) [$($_.PSChildName)]"
            }
        }
    }

    # 3b: Also collect from UserData (the product might only be registered here)
    $userDataPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData"
    if (Test-Path $userDataPath) {
        Get-ChildItem $userDataPath -ErrorAction SilentlyContinue | ForEach-Object {
            $productsPath = Join-Path $_.PSPath "Products"
            if (Test-Path $productsPath) {
                Get-ChildItem $productsPath -ErrorAction SilentlyContinue | ForEach-Object {
                    $ipPath = Join-Path $_.PSPath "InstallProperties"
                    if (Test-Path $ipPath) {
                        $ip = Get-ItemProperty $ipPath -ErrorAction SilentlyContinue
                        if ($ip.DisplayName -match "CC\s*Switch") {
                            if ($ccsCompressedGuids -notcontains $_.PSChildName) {
                                $ccsCompressedGuids += $_.PSChildName
                            }
                            Write-Host "  Removing Installer UserData: $($ip.DisplayName)"
                            Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                            Write-OK "UserData entry removed"
                        }
                    }
                }
            }
        }
    }

    # 3c: Remove UpgradeCode entries that reference any CC Switch product
    $upgradeCodePaths = @(
        "HKCR:\Installer\UpgradeCodes",
        "HKLM:\SOFTWARE\Classes\Installer\UpgradeCodes"
    )
    if ($ccsCompressedGuids.Count -gt 0) {
        foreach ($regPath in $upgradeCodePaths) {
            Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
                $keyPath = $_.PSPath
                foreach ($vn in $_.GetValueNames()) {
                    if ($ccsCompressedGuids -contains $vn) {
                        Write-Host "  Removing UpgradeCode entry: $($_.PSChildName)"
                        Remove-Item $keyPath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-OK "UpgradeCode removed"
                        break
                    }
                }
            }
        }
    }

    # 3d: Remove Products entries
    foreach ($regPath in $installerProductPaths) {
        Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            if ($props.ProductName -match "CC\s*Switch") {
                Write-Host "  Removing Installer Product: $($props.ProductName)"
                Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-OK "Product entry removed"
            }
        }
    }

    # 3e: Also search per-user hives (HKU\<SID>\Software\Classes\Installer)
    try {
        $hku = [Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::Users, [Microsoft.Win32.RegistryView]::Default)
        foreach ($sidName in $hku.GetSubKeyNames()) {
            foreach ($subPath in @("Software\Classes\Installer\Products", "Software\Classes\Installer\UpgradeCodes")) {
                $subKey = $hku.OpenSubKey("$sidName\$subPath", $true)
                if ($subKey) {
                    foreach ($name in $subKey.GetSubKeyNames()) {
                        if ($subPath -match "Products") {
                            $prodKey = $subKey.OpenSubKey($name)
                            if ($prodKey) {
                                $pn = $prodKey.GetValue("ProductName")
                                $prodKey.Close()
                                if ($pn -match "CC\s*Switch") {
                                    Write-Host "  Removing HKU product: $pn (SID=$sidName)"
                                    $subKey.DeleteSubKeyTree($name, $false)
                                    Write-OK "HKU product removed"
                                }
                            }
                        } elseif ($ccsCompressedGuids.Count -gt 0) {
                            $ucKey = $subKey.OpenSubKey($name)
                            if ($ucKey) {
                                $match = $false
                                foreach ($vn in $ucKey.GetValueNames()) {
                                    if ($ccsCompressedGuids -contains $vn) { $match = $true; break }
                                }
                                $ucKey.Close()
                                if ($match) {
                                    Write-Host "  Removing HKU UpgradeCode (SID=$sidName)"
                                    $subKey.DeleteSubKeyTree($name, $false)
                                    Write-OK "HKU UpgradeCode removed"
                                }
                            }
                        }
                    }
                    $subKey.Close()
                }
            }
        }
        $hku.Close()
    } catch {}

    # Step 4: Remove CC Switch installation directories
    $ccsDirs = @(
        "$env:LOCALAPPDATA\Programs\CC Switch",
        "$env:LOCALAPPDATA\Programs\CC-Switch",
        "$env:USERPROFILE\.cc-switch"
    )
    foreach ($d in $ccsDirs) {
        if (Test-Path $d) {
            Write-Host "  Removing install directory: $d"
            Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue
            Write-OK "Directory removed"
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

    try {
        # Reuse the release asset already queried above (avoid a second GitHub call)
        $asset = $latestAsset
        if ($asset) {
            $ccsDir = Join-Path $toolsDir "ccswitch"
            $msi = Join-Path $env:TEMP "ccswitch-setup.msi"
            Download-File $asset.browser_download_url $msi
            $verbNoun = if ($installedVer) { "Updating" } else { "Installing" }
            Write-Host "  $verbNoun CCswitch (MSI) to $ccsDir ..."
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
                $doneWord = if ($installedVer) { "updated" } else { "installed" }
                Write-OK "CCswitch $doneWord (MSI)"
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
        }
    } catch {
        Write-Err "GitHub query failed: $_"
    }
}

# ============================================================
# 5. claude-code CLI (installs if missing, updates if newer available)
# ============================================================
Write-Step "claude-code CLI"
$claudeCmd = Join-Path $nodeDir "claude.cmd"
$npmCmd = Join-Path $nodeDir "npm.cmd"
$env:PATH = "$nodeDir;$env:PATH"
if (Test-Path $claudeCmd) {
    # Already installed - check npm registry for a newer version
    $ErrorActionPreference = "SilentlyContinue"
    $localVer = (& $claudeCmd --version 2>$null) -replace '[^\d.].*$',''
    $latestVer = (& $npmCmd view "@anthropic-ai/claude-code" version 2>$null)
    $ErrorActionPreference = "Stop"
    if ($localVer -and $latestVer -and $localVer -ne $latestVer) {
        Write-Host "  Update available: v$localVer -> v$latestVer, updating..." -ForegroundColor Cyan
        $ErrorActionPreference = "SilentlyContinue"
        & $npmCmd install -g "@anthropic-ai/claude-code@latest" | Out-Null
        $ErrorActionPreference = "Stop"
        Write-OK "claude-code updated to v$latestVer"
    } else {
        $vt = if ($localVer) { " (v$localVer)" } else { "" }
        Write-Skip "claude-code$vt"
    }
} else {
    Write-Host "  Installing via npm (may take a few minutes)..."
    $ErrorActionPreference = "SilentlyContinue"
    & $npmCmd install -g "@anthropic-ai/claude-code" | Out-Null
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
$nv = & (Join-Path $nodeDir "node.exe") --version; Write-OK "Node.js $nv"
$pv = & (Join-Path $pyDir "python.exe") --version; Write-OK "$pv"
$gv = & (Join-Path $gitDir "cmd\git.exe") --version; Write-OK "$gv"
$cv = & $claudeCmd --version; Write-OK "claude $cv"
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Setup complete! All dependencies installed." -ForegroundColor Green
Write-Host ""
exit 0
