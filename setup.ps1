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

# Convert a product GUID {XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX} into the packed
# form Windows Installer uses as registry key names (used to purge stale product
# registration so a reinstall cannot fail RegisterProduct with 1603).
function Convert-ToCompressedGuid([string]$g) {
    if (-not $g) { return $null }
    $g = $g.Trim().Trim('{', '}')
    $p = $g.Split('-')
    if ($p.Count -ne 5) { return $null }
    $rev = { param($s) -join ($s.ToCharArray()[($s.Length - 1)..0]) }
    $out = (& $rev $p[0]) + (& $rev $p[1]) + (& $rev $p[2])
    foreach ($seg in @($p[3], $p[4])) {
        for ($i = 0; $i -lt $seg.Length; $i += 2) { $out += $seg[$i + 1]; $out += $seg[$i] }
    }
    return $out
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
# Install the OFFICIAL CCswitch MSI, but keep the program files under
# tools\CCswitch so the whole toolchain stays in one portable folder.
#
# This Tauri/WiX MSI hard-codes its install dir to %LOCALAPPDATA%\Programs\CC
# Switch (a command-line INSTALLDIR= is ignored). So we:
#   1. run the real installer (msiexec /i) -> lands in %LOCALAPPDATA%
#   2. move the installed payload into tools\CCswitch
#   3. replace the %LOCALAPPDATA% dir with a junction -> tools\CCswitch
# The result is a normal install (Start-menu shortcut, Add/Remove Programs
# entry) whose files physically live in tools\CCswitch.
#
# We also keep the downloaded .msi in tools\CCswitch for reference/repair.
$ccsDir  = Join-Path $toolsDir "CCswitch"
$ccsExe  = Join-Path $ccsDir "cc-switch.exe"
$ccsLink = Join-Path $env:LOCALAPPDATA "Programs\CC Switch"

# Version already installed under tools\CCswitch, and the latest available.
$installedVer = $null
if (Test-Path $ccsExe) {
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

# Decide: skip (up to date), or (re)install (missing / newer available).
$needInstall = $false
if (Test-Path $ccsExe) {
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

if ($needInstall) {
    try {
        $asset = $latestAsset
        if (-not $asset) {
            Write-Err "Windows MSI asset not found in release"
        } else {
            if (-not (Test-Path $ccsDir)) { New-Item -ItemType Directory -Path $ccsDir -Force | Out-Null }

            # Download the MSI to a temp location (installer only -- it is deleted
            # after install so it does not clutter tools\CCswitch). Also clear any
            # older MSI that a previous version of this script left in $ccsDir.
            Get-ChildItem $ccsDir -Filter "*.msi" -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
            $msi = Join-Path $toolsDir $asset.name
            $verbNoun = if ($installedVer) { "Updating" } else { "Installing" }
            Write-Host "  $verbNoun CCswitch (official MSI) ..."
            Download-File $asset.browser_download_url $msi

            # Purge any stale registration for this product so the install is a
            # real fresh install, not a no-op "reconfigure". A half-removed prior
            # install leaves a ghost pair -- an ARP entry (often with a blank
            # version) plus a UserData Products record pointing at a cached
            # package -- which makes msiexec /i exit 0 while laying down zero
            # files, or fail RegisterProduct with 1603.
            #
            # We collect compressed product GUIDs from BOTH directions so purge
            # is self-sufficient regardless of which half survived:
            #   a) ARP DisplayName -> product GUID -> compressed GUID
            #   b) UserData Products\<compressed>\InstallProperties DisplayName
            # (b) is essential: if ARP is already gone, the UserData ghost is the
            # thing that triggers the no-op, and only a direct scan finds it.
            $compGuids = @()

            # a) ARP (all three hives); also remove the ARP key itself.
            foreach ($rp in @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")) {
                Get-ChildItem $rp -ErrorAction SilentlyContinue | ForEach-Object {
                    $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                    if ($p.DisplayName -match "CC\s*Switch") {
                        if ($_.PSChildName -match '^\{[0-9A-Fa-f\-]{36}\}$') {
                            $c = Convert-ToCompressedGuid $_.PSChildName
                            if ($c) { $compGuids += $c }
                        }
                        Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            # b) UserData Products scanned directly by DisplayName -- the key
            #    name already IS the compressed GUID.
            $udRoot = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData"
            Get-ChildItem $udRoot -ErrorAction SilentlyContinue | ForEach-Object {
                Get-ChildItem (Join-Path $_.PSPath "Products") -ErrorAction SilentlyContinue | ForEach-Object {
                    $ip = Get-ItemProperty (Join-Path $_.PSPath "InstallProperties") -ErrorAction SilentlyContinue
                    if ($ip.DisplayName -match "CC\s*Switch") { $compGuids += $_.PSChildName }
                }
            }

            # Drop UserData + HKCU Installer records for every compressed GUID found.
            foreach ($comp in ($compGuids | Select-Object -Unique)) {
                if (-not $comp) { continue }
                Get-ChildItem $udRoot -ErrorAction SilentlyContinue | ForEach-Object {
                    $pp = Join-Path $_.PSPath "Products\$comp"
                    if (Test-Path $pp) { Remove-Item -LiteralPath $pp -Recurse -Force -ErrorAction SilentlyContinue }
                }
                foreach ($sub in @("Products", "Features")) {
                    $hp = "HKCU:\SOFTWARE\Microsoft\Installer\$sub\$comp"
                    if (Test-Path $hp) { Remove-Item -LiteralPath $hp -Recurse -Force -ErrorAction SilentlyContinue }
                }
            }

            # Clear the install-target location (old dir or stale junction).
            if (Test-Path $ccsLink) {
                $it = Get-Item $ccsLink -Force
                if ($it.LinkType) { cmd /c rmdir "`"$ccsLink`"" | Out-Null } else { Remove-Item $ccsLink -Recurse -Force -ErrorAction SilentlyContinue }
            }

            # 1) Run the real installer.
            $msiLog = Join-Path $toolsDir "ccswitch-install.log"
            $proc = Start-Process msiexec.exe -ArgumentList @('/i', $msi, '/quiet', '/norestart', '/log', $msiLog) -Wait -PassThru

            # 1612 = "installation source unavailable". This happens when a stale
            # product registration survived with a LastUsedSource pointing at an
            # MSI we already deleted: msiexec treats /i as maintenance of the
            # "installed" product and hunts for the old source instead of using
            # our new package. The ghost lives in HKCU managed-install view
            # (Installer\Products|Features\<compressed>), which our purge above
            # normally clears -- but if an external leftover slips through, force
            # a re-purge of every CC Switch product code and retry once.
            if ($proc.ExitCode -eq 1612) {
                Write-Host "  1612 (stale source); purging product registration and retrying..." -ForegroundColor Yellow
                $retry = @()
                foreach ($rp in @(
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
                    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall")) {
                    Get-ChildItem $rp -ErrorAction SilentlyContinue | ForEach-Object {
                        $p = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
                        if ($p.DisplayName -match "CC\s*Switch" -and $_.PSChildName -match '^\{[0-9A-Fa-f\-]{36}\}$') {
                            $c = Convert-ToCompressedGuid $_.PSChildName; if ($c) { $retry += $c }
                            Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                Get-ChildItem $udRoot -ErrorAction SilentlyContinue | ForEach-Object {
                    Get-ChildItem (Join-Path $_.PSPath "Products") -ErrorAction SilentlyContinue | ForEach-Object {
                        $ip = Get-ItemProperty (Join-Path $_.PSPath "InstallProperties") -ErrorAction SilentlyContinue
                        if ($ip.DisplayName -match "CC\s*Switch") { $retry += $_.PSChildName }
                    }
                }
                foreach ($c in ($retry | Select-Object -Unique)) {
                    if (-not $c) { continue }
                    Get-ChildItem $udRoot -ErrorAction SilentlyContinue | ForEach-Object {
                        $pp = Join-Path $_.PSPath "Products\$c"
                        if (Test-Path $pp) { Remove-Item -LiteralPath $pp -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                    foreach ($sub in @("Products", "Features")) {
                        $hp = "HKCU:\SOFTWARE\Microsoft\Installer\$sub\$c"
                        if (Test-Path $hp) { Remove-Item -LiteralPath $hp -Recurse -Force -ErrorAction SilentlyContinue }
                    }
                    $cp = "HKLM:\SOFTWARE\Classes\Installer\Products\$c"
                    if (Test-Path $cp) { Remove-Item -LiteralPath $cp -Recurse -Force -ErrorAction SilentlyContinue }
                }
                if (Test-Path $ccsLink) {
                    $it = Get-Item $ccsLink -Force
                    if ($it.LinkType) { cmd /c rmdir "`"$ccsLink`"" | Out-Null } else { Remove-Item $ccsLink -Recurse -Force -ErrorAction SilentlyContinue }
                }
                $proc = Start-Process msiexec.exe -ArgumentList @('/i', $msi, '/quiet', '/norestart', '/log', $msiLog) -Wait -PassThru
            }

            if ($proc.ExitCode -ne 0) {
                Write-Err "CCswitch install failed (exit code $($proc.ExitCode))"
                if (Test-Path $msiLog) { Write-Host "  Install log: $msiLog" -ForegroundColor Yellow }
                Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue
            } elseif (-not (Test-Path (Join-Path $ccsLink "cc-switch.exe"))) {
                Write-Err "CCswitch installed but cc-switch.exe not found in $ccsLink"
                Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue
            } else {
                # 2) Copy the installed payload into tools\CCswitch.
                Get-ChildItem $ccsLink -Force -ErrorAction SilentlyContinue | ForEach-Object {
                    $dest = Join-Path $ccsDir $_.Name
                    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue }
                    Copy-Item -LiteralPath $_.FullName -Destination $dest -Recurse -Force
                }

                # 3) Re-point Start-menu shortcut(s) that reference the soon-to-be
                #    deleted %LOCALAPPDATA% path at tools\CCswitch, so they don't
                #    become dead links once we remove the original folder.
                $startMenu = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\CC Switch"
                if (Test-Path $startMenu) {
                    $ws = New-Object -ComObject WScript.Shell
                    Get-ChildItem $startMenu -Filter *.lnk -ErrorAction SilentlyContinue | ForEach-Object {
                        try {
                            $sc = $ws.CreateShortcut($_.FullName)
                            if ($sc.TargetPath -like "$ccsLink*") {
                                $sc.TargetPath = $sc.TargetPath -replace [regex]::Escape($ccsLink), $ccsDir
                                if ($sc.WorkingDirectory -like "$ccsLink*") {
                                    $sc.WorkingDirectory = $sc.WorkingDirectory -replace [regex]::Escape($ccsLink), $ccsDir
                                }
                                $sc.Save()
                            }
                        } catch {}
                    }
                }

                # 4) Remove the original %LOCALAPPDATA%\Programs\CC Switch folder.
                #    The program now runs from tools\CCswitch. NOTE: the ARP entry
                #    still points here, so uninstalling via Add/Remove Programs will
                #    not find these files -- that's the trade-off of not using a
                #    junction. Running cc-switch.exe from tools\CCswitch works fine.
                Remove-Item $ccsLink -Recurse -Force -ErrorAction SilentlyContinue

                # 5) Delete the temp installer MSI -- it is not kept.
                Remove-Item -LiteralPath $msi -Force -ErrorAction SilentlyContinue
                Remove-Item $msiLog -Force -ErrorAction SilentlyContinue
                if (Test-Path $ccsExe) {
                    $doneWord = if ($installedVer) { "updated" } else { "installed" }
                    Write-OK "CCswitch $doneWord to $ccsDir"
                } else {
                    Write-Err "CCswitch install incomplete: $ccsExe missing"
                }
            }
        }
    } catch {
        Write-Err "CCswitch install failed: $_"
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
if (Test-Path $ccsExe) {
    $ccv = try { (Get-Item $ccsExe).VersionInfo.ProductVersion } catch { $null }
    Write-OK "CCswitch $(if($ccv){"v$ccv "})($ccsDir)"
} else {
    Write-Err "CCswitch not found at $ccsExe"
}
$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Setup complete! All dependencies installed." -ForegroundColor Green
Write-Host ""
exit 0
