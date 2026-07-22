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
# We install CCswitch as a PORTABLE copy under tools\CCswitch (extracted from the
# official MSI). Detection looks only at that portable path -- any %LOCALAPPDATA%
# MSI install from an older setup is intentionally ignored so setup always
# (re)creates the portable copy the user wants under tools\CCswitch.
$ccsDir = Join-Path $toolsDir "CCswitch"
$ccsExe = Join-Path $ccsDir "cc-switch.exe"

# Determine installed version and latest available version
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

# Decide: skip (up to date), update (newer available), or install (not present)
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

if (-not $needInstall) {
    # up to date, nothing to do
} else {
    # -- Install CCswitch as a portable copy under tools\CCswitch ----------
    # We use the OFFICIAL MSI, but extract it with an administrative install
    # (msiexec /a) instead of a normal install (/i). Rationale:
    #   * This Tauri/WiX package hard-codes its install dir to
    #     %LOCALAPPDATA%\Programs\CC Switch via a SetDirectory custom action and
    #     ignores a command-line INSTALLDIR=, so /i can never land in tools\.
    #   * /a only unpacks the payload files to TARGETDIR and runs NONE of the
    #     install custom actions -- no forced LocalAppData path, no registry
    #     product record. That also means the whole 1603 / RemoveExistingProducts
    #     failure mode (missing cached MSI on upgrade) simply cannot occur.
    # The result is a self-contained tools\CCswitch\cc-switch.exe.
    try {
        $asset = $latestAsset
        if (-not $asset) {
            Write-Err "Windows MSI asset not found in release"
        } else {
            $verbNoun = if ($installedVer) { "Updating" } else { "Installing" }
            Write-Host "  $verbNoun CCswitch (portable, extracted from official MSI) ..."

            $msi = Join-Path $env:TEMP "ccswitch-setup.msi"
            Download-File $asset.browser_download_url $msi

            # Fresh target dir
            if (Test-Path $ccsDir) { Remove-Item $ccsDir -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $ccsDir -Force | Out-Null

            $extractRoot = Join-Path $env:TEMP "ccswitch-extract"
            if (Test-Path $extractRoot) { Remove-Item $extractRoot -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null

            $msiLog = Join-Path $toolsDir "ccswitch-install.log"
            $msiArgs = @('/a', $msi, "TARGETDIR=$extractRoot", '/quiet', '/norestart', '/log', $msiLog)
            $proc = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru

            if ($proc.ExitCode -ne 0) {
                Write-Err "CCswitch extraction failed (exit code $($proc.ExitCode))"
                if (Test-Path $msiLog) { Write-Host "  Install log: $msiLog" -ForegroundColor Yellow }
            } else {
                # Locate the extracted cc-switch.exe (nested under Programs\CC Switch\)
                $found = Get-ChildItem $extractRoot -Recurse -Filter "cc-switch.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                if (-not $found) {
                    Write-Err "cc-switch.exe not found in extracted payload"
                } else {
                    # Flatten every payload file into tools\CCswitch (keep the exe's own dir contents)
                    $srcDir = $found.Directory.FullName
                    Get-ChildItem $srcDir -Force -ErrorAction SilentlyContinue | ForEach-Object {
                        Move-Item -LiteralPath $_.FullName -Destination (Join-Path $ccsDir $_.Name) -Force -ErrorAction SilentlyContinue
                    }
                    Remove-Item $extractRoot -Recurse -Force -ErrorAction SilentlyContinue
                    Remove-Item $msi -Force -ErrorAction SilentlyContinue
                    Remove-Item $msiLog -Force -ErrorAction SilentlyContinue
                    if (Test-Path $ccsExe) {
                        $doneWord = if ($installedVer) { "updated" } else { "installed" }
                        Write-OK "CCswitch $doneWord to $ccsDir"
                    } else {
                        Write-Err "CCswitch install incomplete: $ccsExe missing"
                    }
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
