# setup.ps1 - One-click dependency installer for Claude Code portable environment
# Downloads: Node.js, Python, Git, CCswitch, claude-code CLI

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
if (-not $root) { $root = Get-Location }
$toolsDir = Join-Path $root "cladue_code\tools"

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
        & curl.exe -L -o $out $url 2>$null
    }
    $ProgressPreference = "Continue"
    if (-not (Test-Path $out)) { throw "Download failed: $url" }
}

if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }

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
    & (Join-Path $pyDir "python.exe") $getPip --quiet 2>$null
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
    & $exe ("-o" + $gitDir) -y 2>$null | Out-Null
    Start-Sleep -Seconds 5
    Remove-Item $exe -Force -ErrorAction SilentlyContinue
    if (Test-Path (Join-Path $gitDir "cmd\git.exe")) { Write-OK "Git installed" }
    else { Write-Err "Git extraction failed"; exit 1 }
}

# ============================================================
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
    & (Join-Path $nodeDir "npm.cmd") install -g "@anthropic-ai/claude-code" 2>&1 | Out-Null
    if (Test-Path $claudeCmd) { Write-OK "claude-code CLI installed" }
    else { Write-Err "claude-code installation failed"; exit 1 }
}

# ============================================================
# 6. Create Junction: ~/.claude -> cloud claude_config/
# ============================================================
$claudeConfigDir = Join-Path $root "cladue_code\claude_config"
$claudeHome = Join-Path $env:USERPROFILE ".claude"
Write-Step "Linking ~/.claude to cloud config"
$existing = Get-Item $claudeHome -ErrorAction SilentlyContinue
if ($existing -and $existing.Attributes -match "ReparsePoint") {
    Write-Skip "Junction already exists"
} else {
    if (-not (Test-Path $claudeConfigDir)) {
        New-Item -ItemType Directory -Path $claudeConfigDir -Force | Out-Null
    }
    if (Test-Path $claudeHome) {
        # Back up existing config if not a junction
        $backup = "$claudeHome.bak"
        Write-Host "  Backing up existing ~/.claude to ~/.claude.bak"
        if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
        Move-Item $claudeHome $backup
    }
    $result = & cmd /c mklink /J `"$claudeHome`" `"$claudeConfigDir`" 2>&1
    if (Test-Path $claudeHome) { Write-OK "Junction created: ~/.claude -> cloud config" }
    else { Write-Err "Failed to create junction: $result" }
}

# ============================================================
# Verify all
# ============================================================
Write-Host ""
Write-Step "Verification"
$env:PATH = "$nodeDir;$pyDir;$(Join-Path $gitDir 'cmd');$env:PATH"

$nv = & (Join-Path $nodeDir "node.exe") --version 2>&1; Write-OK "Node.js $nv"
$pv = & (Join-Path $pyDir "python.exe") --version 2>&1; Write-OK "$pv"
$gv = & (Join-Path $gitDir "cmd\git.exe") --version 2>&1; Write-OK "$gv"
$cv = & $claudeCmd --version 2>&1; Write-OK "claude $cv"

Write-Host ""
Write-Host "Setup complete! All dependencies installed." -ForegroundColor Green
Write-Host ""
exit 0
