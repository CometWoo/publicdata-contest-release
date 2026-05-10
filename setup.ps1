#Requires -Version 5.1
# Silver Voice - Full Environment Setup (Windows PowerShell)
# Run as Administrator:
#   powershell -ExecutionPolicy Bypass -File setup.ps1
#
# What this script does:
#   1. Diagnoses installed tools (Git, Flutter, Dart, Java, Android SDK, VS Code)
#   2. Installs missing tools automatically via winget or direct download
#   3. Clones the project repo and runs flutter pub get
#   4. Runs flutter doctor for final verification

param(
    [string]$InstallDir = "C:\dev",
    [string]$RepoUrl = "https://github.com/CometWoo/publicdata-contest-release.git",
    [string]$ProjectDir = "",
    [switch]$DiagnoseOnly,
    [switch]$SkipClone
)

# --- Config ---
$FLUTTER_VERSION = "3.19.0"
$FLUTTER_ZIP_URL = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_$FLUTTER_VERSION-stable.zip"
$JDK_VERSION = "17"
$MIN_DART_VERSION = "3.2.0"

# --- Init ---
$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OriginalPath = $env:Path

function Write-Status {
    param([string]$Step, [string]$Status, [string]$Message, [string]$Detail = "")
    switch ($Status) {
        "OK"   { Write-Host "$Step " -NoNewline; Write-Host "[OK]   " -ForegroundColor Green -NoNewline; Write-Host $Message }
        "FAIL" { Write-Host "$Step " -NoNewline; Write-Host "[FAIL] " -ForegroundColor Red -NoNewline; Write-Host $Message }
        "WARN" { Write-Host "$Step " -NoNewline; Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline; Write-Host $Message }
        "SKIP" { Write-Host "$Step " -NoNewline; Write-Host "[SKIP] " -ForegroundColor DarkGray -NoNewline; Write-Host $Message }
        "INFO" { Write-Host "$Step " -NoNewline; Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline; Write-Host $Message }
        "WORK" { Write-Host "$Step " -NoNewline; Write-Host "[....] " -ForegroundColor Magenta -NoNewline; Write-Host $Message }
    }
    if ($Detail) { Write-Host "         $Detail" -ForegroundColor DarkGray }
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-ToUserPath {
    param([string]$NewPath)
    $added = $false
    # Windows PATH (PowerShell, CMD)
    $current = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($current -notlike "*$NewPath*") {
        [Environment]::SetEnvironmentVariable("Path", "$current;$NewPath", "User")
        $env:Path += ";$NewPath"
        $added = $true
    }
    # Git Bash PATH (~/.bashrc)
    $bashrc = "$env:USERPROFILE\.bashrc"
    $unixPath = $NewPath -replace "\\","/"
    if ($unixPath -match "^([A-Za-z]):(.*)") {
        $unixPath = "/" + $Matches[1].ToLower() + $Matches[2]
    }
    $exportLine = "export PATH=`"`$PATH:$unixPath`""
    $bashrcExists = Test-Path $bashrc
    if (-not $bashrcExists -or -not (Select-String -Path $bashrc -Pattern ([regex]::Escape($unixPath)) -Quiet)) {
        Add-Content -Path $bashrc -Value "`n# Added by Silver Voice setup" -Encoding UTF8
        Add-Content -Path $bashrc -Value $exportLine -Encoding UTF8
        $added = $true
        Write-Status "     " "INFO" "Added to ~/.bashrc for Git Bash"
    }
    return $added
}

function Test-CommandExists {
    param([string]$Cmd)
    return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue)
}

function Find-Flutter {
    if (Test-CommandExists "flutter") { return (Get-Command flutter).Source }
    $searchPaths = @(
        "$InstallDir\flutter\bin",
        "$env:USERPROFILE\flutter\bin",
        "$env:LOCALAPPDATA\flutter\bin",
        "C:\flutter\bin",
        "C:\src\flutter\bin",
        "C:\portable\flutter\bin",
        "D:\flutter\bin"
    )
    foreach ($p in $searchPaths) {
        if (Test-Path "$p\flutter.bat") {
            $env:Path += ";$p"
            return "$p\flutter.bat"
        }
    }
    return $null
}

# ================================================================
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Silver Voice - Full Environment Setup" -ForegroundColor Cyan
Write-Host "  Target: Flutter $FLUTTER_VERSION / Dart >= $MIN_DART_VERSION / Java $JDK_VERSION" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Admin)) {
    Write-Host "  [!!] Not running as Administrator." -ForegroundColor Yellow
    Write-Host "  Some installations (winget, Java) may require admin." -ForegroundColor Yellow
    Write-Host "  Right-click PowerShell > 'Run as Administrator' recommended." -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "  Continue anyway? (y/n)"
    if ($continue -ne "y") { exit 0 }
}

# ================================================================
# PHASE 1: DIAGNOSIS
# ================================================================
Write-Host ""
Write-Host "--- PHASE 1: Environment Diagnosis ---" -ForegroundColor White
Write-Host ""

$diagnosis = @{}

# 1. Git
$step = "[1/8]"
if (Test-CommandExists "git") {
    $gitVer = (git --version 2>&1) -replace "git version ",""
    Write-Status $step "OK" "Git $gitVer"
    $diagnosis["git"] = "OK"
} else {
    Write-Status $step "FAIL" "Git not found"
    $diagnosis["git"] = "MISSING"
}

# 2. Flutter SDK
$step = "[2/8]"
$flutterPath = Find-Flutter
if ($flutterPath) {
    $flutterVer = (flutter --version --machine 2>&1 | Out-String)
    if ($flutterVer -match '"frameworkVersion"\s*:\s*"([^"]+)"') {
        $fv = $Matches[1]
        Write-Status $step "OK" "Flutter $fv" "Path: $flutterPath"
    } else {
        $fvSimple = ((flutter --version 2>&1 | Out-String) -split "`n")[0].Trim()
        Write-Status $step "OK" "$fvSimple" "Path: $flutterPath"
    }
    $diagnosis["flutter"] = "OK"
} else {
    Write-Status $step "FAIL" "Flutter SDK not found"
    $diagnosis["flutter"] = "MISSING"
}

# 3. Dart SDK
$step = "[3/8]"
if (Test-CommandExists "dart") {
    $dartVer = (dart --version 2>&1) -replace "Dart SDK version: ",""
    Write-Status $step "OK" "Dart $dartVer"
    if ($dartVer -match "(\d+)\.(\d+)\.(\d+)") {
        $major = [int]$Matches[1]; $minor = [int]$Matches[2]
        if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 2)) {
            Write-Status $step "WARN" "Dart >= $MIN_DART_VERSION required, current: $($Matches[0])"
            $diagnosis["dart"] = "OUTDATED"
        } else {
            $diagnosis["dart"] = "OK"
        }
    } else {
        $diagnosis["dart"] = "OK"
    }
} elseif ($diagnosis["flutter"] -eq "OK") {
    Write-Status $step "WARN" "dart not in PATH directly, but Flutter includes Dart"
    $diagnosis["dart"] = "OK"
} else {
    Write-Status $step "FAIL" "Dart SDK not found"
    $diagnosis["dart"] = "MISSING"
}

# 4. Java (JDK)
$step = "[4/8]"
if (Test-CommandExists "java") {
    $javaVer = (java -version 2>&1 | Out-String)
    if ($javaVer -match '(\d+)[\.\d]*') {
        $jmajor = $Matches[1]
        if ([int]$jmajor -ge 17) {
            Write-Status $step "OK" "Java $jmajor" "Required: >= 17"
            $diagnosis["java"] = "OK"
        } else {
            Write-Status $step "WARN" "Java $jmajor found, but >= 17 required"
            $diagnosis["java"] = "OUTDATED"
        }
    } else {
        Write-Status $step "OK" "Java found"
        $diagnosis["java"] = "OK"
    }
} else {
    Write-Status $step "FAIL" "Java (JDK) not found"
    $diagnosis["java"] = "MISSING"
}

# 5. Android Studio
$step = "[5/8]"
$asPath = "${env:ProgramFiles}\Android\Android Studio\bin\studio64.exe"
$asPath2 = "${env:ProgramFiles(x86)}\Android\Android Studio\bin\studio64.exe"
$asLocal = "$env:LOCALAPPDATA\Programs\Android Studio\bin\studio64.exe"
if ((Test-Path $asPath) -or (Test-Path $asPath2) -or (Test-Path $asLocal)) {
    Write-Status $step "OK" "Android Studio installed"
    $diagnosis["android_studio"] = "OK"
} else {
    Write-Status $step "WARN" "Android Studio not found (optional for CLI builds)"
    $diagnosis["android_studio"] = "MISSING"
}

# 6. Android SDK
$step = "[6/8]"
$androidSdkPath = if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
                  elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
                  elseif (Test-Path "$env:LOCALAPPDATA\Android\Sdk") { "$env:LOCALAPPDATA\Android\Sdk" }
                  else { $null }
if ($androidSdkPath -and (Test-Path $androidSdkPath)) {
    Write-Status $step "OK" "Android SDK" "Path: $androidSdkPath"
    $diagnosis["android_sdk"] = "OK"

    # Check license
    $licensePath = "$androidSdkPath\licenses\android-sdk-license"
    if (Test-Path $licensePath) {
        Write-Status "     " "OK" "Android SDK license accepted"
        $diagnosis["android_license"] = "OK"
    } else {
        Write-Status "     " "WARN" "Android SDK license not accepted"
        $diagnosis["android_license"] = "MISSING"
    }
} else {
    Write-Status $step "FAIL" "Android SDK not found"
    $diagnosis["android_sdk"] = "MISSING"
    $diagnosis["android_license"] = "MISSING"
}

# 7. Chrome
$step = "[7/8]"
$chromeExe = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$chromeExe2 = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
if ((Test-Path $chromeExe) -or (Test-Path $chromeExe2)) {
    Write-Status $step "OK" "Chrome installed (for Web builds)"
    $diagnosis["chrome"] = "OK"
} else {
    Write-Status $step "WARN" "Chrome not found (needed for flutter run -d chrome)"
    $diagnosis["chrome"] = "MISSING"
}

# 8. VS Code
$step = "[8/8]"
if (Test-CommandExists "code") {
    $codeVer = (code --version 2>&1 | Select-Object -First 1)
    Write-Status $step "OK" "VS Code $codeVer"
    $diagnosis["vscode"] = "OK"
} else {
    Write-Status $step "WARN" "VS Code not found (optional)"
    $diagnosis["vscode"] = "MISSING"
}

# PATH check
Write-Host ""
Write-Host "--- PATH Registration ---" -ForegroundColor White
$pathEntries = $env:Path -split ";"
$flutterInPath = $pathEntries | Where-Object { $_ -match "flutter" }
$androidInPath = $pathEntries | Where-Object { $_ -match "android|Android" }

if ($flutterInPath) {
    Write-Status "     " "OK" "Flutter in PATH: $($flutterInPath -join ', ')"
} else {
    Write-Status "     " "FAIL" "Flutter not in system PATH"
}
if ($androidInPath) {
    Write-Status "     " "OK" "Android in PATH: $($androidInPath -join ', ')"
} else {
    Write-Status "     " "WARN" "Android tools not in PATH"
}

# --- Diagnosis summary ---
Write-Host ""
$missing = ($diagnosis.Values | Where-Object { $_ -ne "OK" }).Count
if ($missing -eq 0) {
    Write-Host "Diagnosis: All $($diagnosis.Count) items OK." -ForegroundColor Green
} else {
    Write-Host "Diagnosis: $missing item(s) need attention." -ForegroundColor Yellow
}

if ($DiagnoseOnly) {
    Write-Host ""
    Write-Host "Diagnose-only mode. Use without -DiagnoseOnly to install." -ForegroundColor Cyan
    exit 0
}

# ================================================================
# PHASE 2: AUTO-INSTALL
# ================================================================
Write-Host ""
Write-Host "--- PHASE 2: Auto-Install Missing Tools ---" -ForegroundColor White
Write-Host ""

$hasWinget = Test-CommandExists "winget"
if (-not $hasWinget) {
    Write-Host "winget not found. Will use direct downloads where possible." -ForegroundColor Yellow
}

$installStep = 0
$installTotal = ($diagnosis.Values | Where-Object { $_ -ne "OK" }).Count
if ($installTotal -eq 0) {
    Write-Host "Nothing to install. All tools are ready." -ForegroundColor Green
}

# --- Install Git ---
if ($diagnosis["git"] -ne "OK") {
    $installStep++
    Write-Status "[$installStep/$installTotal]" "WORK" "Installing Git..."
    if ($hasWinget) {
        & winget install --id Git.Git --accept-package-agreements --accept-source-agreements -e 2>&1 | Out-String | Out-Null
        $env:Path += ";C:\Program Files\Git\cmd"
    } else {
        Write-Status "[$installStep/$installTotal]" "FAIL" "Please install Git manually: https://git-scm.com/download/win"
    }
    if (Test-CommandExists "git") {
        Write-Status "[$installStep/$installTotal]" "OK" "Git installed"
    } else {
        Write-Status "[$installStep/$installTotal]" "FAIL" "Git install failed. Install manually and re-run."
        exit 1
    }
}

# --- Install Java (JDK 17) ---
if ($diagnosis["java"] -ne "OK") {
    $installStep++
    Write-Status "[$installStep/$installTotal]" "WORK" "Installing JDK $JDK_VERSION (Microsoft OpenJDK)..."
    if ($hasWinget) {
        & winget install --id Microsoft.OpenJDK.$JDK_VERSION --accept-package-agreements --accept-source-agreements -e 2>&1 | Out-String | Out-Null
        $jdkPath = "C:\Program Files\Microsoft\jdk-$JDK_VERSION*\bin"
        $jdkResolved = (Resolve-Path $jdkPath -ErrorAction SilentlyContinue | Select-Object -First 1).Path
        if ($jdkResolved) { $env:Path += ";$jdkResolved" }
    } else {
        Write-Status "[$installStep/$installTotal]" "FAIL" "Please install JDK 17 manually: https://learn.microsoft.com/en-us/java/openjdk/download"
    }
    if (Test-CommandExists "java") {
        Write-Status "[$installStep/$installTotal]" "OK" "JDK $JDK_VERSION installed"
    } else {
        Write-Status "[$installStep/$installTotal]" "WARN" "JDK may need a terminal restart to be detected"
    }
}

# --- Install Flutter SDK ---
if ($diagnosis["flutter"] -ne "OK") {
    $installStep++
    $flutterDir = "$InstallDir\flutter"
    Write-Status "[$installStep/$installTotal]" "WORK" "Installing Flutter $FLUTTER_VERSION to $flutterDir ..."

    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    $zipPath = "$env:TEMP\flutter_$FLUTTER_VERSION.zip"

    if (-not (Test-Path $zipPath)) {
        Write-Host "         Downloading Flutter SDK (~1.1 GB)..." -ForegroundColor DarkGray
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($FLUTTER_ZIP_URL, $zipPath)
            Write-Host "         Download complete." -ForegroundColor DarkGray
        } catch {
            Write-Status "[$installStep/$installTotal]" "FAIL" "Download failed: $_"
            Write-Host "         Manual download: $FLUTTER_ZIP_URL" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "         Using cached zip: $zipPath" -ForegroundColor DarkGray
    }

    Write-Host "         Extracting (this takes a few minutes)..." -ForegroundColor DarkGray
    try {
        Expand-Archive -Path $zipPath -DestinationPath $InstallDir -Force
        Write-Host "         Extraction complete." -ForegroundColor DarkGray
    } catch {
        Write-Status "[$installStep/$installTotal]" "FAIL" "Extraction failed: $_"
        exit 1
    }

    $flutterBin = "$flutterDir\bin"
    if (Test-Path "$flutterBin\flutter.bat") {
        Add-ToUserPath $flutterBin | Out-Null
        $env:Path += ";$flutterBin"
        Write-Status "[$installStep/$installTotal]" "OK" "Flutter $FLUTTER_VERSION installed to $flutterDir"
        Write-Status "     " "INFO" "Added to User PATH: $flutterBin"
    } else {
        Write-Status "[$installStep/$installTotal]" "FAIL" "Flutter extraction incomplete. Check $flutterDir"
        exit 1
    }
}

# --- Android SDK license ---
if ($diagnosis["android_license"] -ne "OK" -and $diagnosis["android_sdk"] -eq "OK") {
    $installStep++
    Write-Status "[$installStep/$installTotal]" "WORK" "Accepting Android SDK licenses..."
    $sdkManager = "$androidSdkPath\cmdline-tools\latest\bin\sdkmanager.bat"
    if (Test-Path $sdkManager) {
        echo "y" | & $sdkManager --licenses 2>&1 | Out-Null
        Write-Status "[$installStep/$installTotal]" "OK" "Android SDK licenses accepted"
    } else {
        Write-Status "[$installStep/$installTotal]" "WARN" "sdkmanager not found. Run: flutter doctor --android-licenses"
    }
}

# --- Flutter precache & config ---
if (Test-CommandExists "flutter") {
    Write-Host ""
    Write-Host "--- Configuring Flutter ---" -ForegroundColor White

    Write-Host "  Enabling web support..." -ForegroundColor DarkGray
    flutter config --enable-web 2>&1 | Out-Null

    Write-Host "  Running flutter precache..." -ForegroundColor DarkGray
    flutter precache 2>&1 | Out-Null

    if ($diagnosis["android_license"] -ne "OK") {
        Write-Host "  Accepting Android licenses via Flutter..." -ForegroundColor DarkGray
        echo "y`ny`ny`ny`ny`ny`ny`ny`ny`ny`n" | flutter doctor --android-licenses 2>&1 | Out-Null
    }
}

# ================================================================
# PHASE 3: CLONE & SETUP PROJECT
# ================================================================
Write-Host ""
Write-Host "--- PHASE 3: Project Setup ---" -ForegroundColor White
Write-Host ""

if ($SkipClone) {
    Write-Host "Clone skipped (-SkipClone flag)." -ForegroundColor DarkGray
} else {
    if (-not (Test-CommandExists "git")) {
        Write-Status "[CLONE]" "FAIL" "Git not available. Cannot clone."
        exit 1
    }
    if (-not (Test-CommandExists "flutter")) {
        Write-Status "[CLONE]" "FAIL" "Flutter not available. Cannot set up project."
        exit 1
    }

    $repoName = ($RepoUrl -split "/")[-1] -replace "\.git$",""
    if (-not $ProjectDir) { $ProjectDir = "$InstallDir\$repoName" }

    if (Test-Path "$ProjectDir\.git") {
        Write-Status "[CLONE]" "SKIP" "Repo already cloned at $ProjectDir"
        Set-Location $ProjectDir
        Write-Host "         Pulling latest..." -ForegroundColor DarkGray
        & git pull origin main 2>&1 | Out-Null
    } else {
        Write-Status "[CLONE]" "WORK" "Cloning $RepoUrl ..."
        $cloneOutput = & git clone $RepoUrl $ProjectDir 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Status "[CLONE]" "FAIL" "git clone failed"
            Write-Host $cloneOutput -ForegroundColor Red
            exit 1
        }
        Set-Location $ProjectDir
        Write-Status "[CLONE]" "OK" "Cloned to $ProjectDir"
    }

    Write-Host ""
    Write-Status "[DEPS]" "WORK" "Running flutter pub get..."
    $pubOutput = flutter pub get 2>&1 | Out-String
    if ($pubOutput -match "Got dependencies" -or $pubOutput -match "Resolving" -or $pubOutput -match "Changed") {
        Write-Status "[DEPS]" "OK" "Dependencies installed"
    } else {
        Write-Status "[DEPS]" "WARN" "pub get output:"
        Write-Host $pubOutput -ForegroundColor Yellow
    }
}

# ================================================================
# PHASE 4: FINAL VERIFICATION
# ================================================================
Write-Host ""
Write-Host "--- PHASE 4: Final Verification (flutter doctor) ---" -ForegroundColor White
Write-Host ""

if (Test-CommandExists "flutter") {
    flutter doctor -v
} else {
    Write-Host "Flutter not available. Restart terminal and run: flutter doctor -v" -ForegroundColor Yellow
}

# ================================================================
# SUMMARY
# ================================================================
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  Setup Complete" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Project: $ProjectDir" -ForegroundColor White
Write-Host ""
Write-Host "  Run commands:" -ForegroundColor White
Write-Host "    cd $ProjectDir" -ForegroundColor Green
Write-Host "    flutter run -d chrome          # Web browser" -ForegroundColor Green
Write-Host "    flutter run -d windows         # Windows desktop" -ForegroundColor Green
Write-Host "    flutter run -d <device_id>     # Connected mobile" -ForegroundColor Green
Write-Host "    flutter build apk              # Android APK" -ForegroundColor Green
Write-Host ""
Write-Host "  If commands fail, restart your terminal (PATH update)." -ForegroundColor Yellow
Write-Host ""
Write-Host "  Git Bash users:" -ForegroundColor White
Write-Host "    source ~/.bashrc                 # reload PATH" -ForegroundColor Green
Write-Host "    OR restart Git Bash" -ForegroundColor DarkGray
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
