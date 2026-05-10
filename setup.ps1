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
    # Git Bash PATH (~/.bashrc AND ~/.bash_profile)
    $unixPath = $NewPath -replace "\\","/"
    if ($unixPath -match "^([A-Za-z]):(.*)") {
        $unixPath = "/" + $Matches[1].ToLower() + $Matches[2]
    }
    $exportLine = "export PATH=`"`$PATH:$unixPath`""

    # Write to both .bashrc and .bash_profile for compatibility
    # IMPORTANT: Use UTF8 without BOM -- PowerShell 5.1's -Encoding UTF8 adds BOM
    # which Bash interprets as garbage characters ($'\357\273\277')
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    foreach ($rcFile in @("$env:USERPROFILE\.bashrc", "$env:USERPROFILE\.bash_profile")) {
        $rcExists = Test-Path $rcFile
        $alreadyHas = $false
        if ($rcExists) {
            $alreadyHas = Select-String -Path $rcFile -Pattern ([regex]::Escape($unixPath)) -Quiet
        }
        if (-not $alreadyHas) {
            $linesToAppend = "`n# Added by Silver Voice setup`n$exportLine`n"
            if ($rcExists) {
                $existing = [System.IO.File]::ReadAllText($rcFile, $utf8NoBom)
                [System.IO.File]::WriteAllText($rcFile, $existing + $linesToAppend, $utf8NoBom)
            } else {
                [System.IO.File]::WriteAllText($rcFile, $linesToAppend, $utf8NoBom)
            }
            $rcName = Split-Path -Leaf $rcFile
            Write-Status "     " "INFO" "Added to ~/$rcName for Git Bash"
            $added = $true
        }
    }
    # Also strip BOM from existing files if present (fix for previous runs)
    foreach ($rcFile in @("$env:USERPROFILE\.bashrc", "$env:USERPROFILE\.bash_profile")) {
        if (Test-Path $rcFile) {
            $bytes = [System.IO.File]::ReadAllBytes($rcFile)
            if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
                $clean = $bytes[3..($bytes.Length - 1)]
                [System.IO.File]::WriteAllBytes($rcFile, [byte[]]$clean)
                $rcName = Split-Path -Leaf $rcFile
                Write-Status "     " "INFO" "Removed BOM from ~/$rcName (fixing previous run)"
            }
        }
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
Write-Host "  Target: Flutter (latest stable) / Dart >= $MIN_DART_VERSION / Java $JDK_VERSION" -ForegroundColor Cyan
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

# PATH check and auto-registration (runs EVERY time, not just on install)
Write-Host ""
Write-Host "--- PATH Registration ---" -ForegroundColor White

# Find Flutter bin directory for PATH registration
$flutterBinDir = $null
if ($flutterPath) {
    $flutterBinDir = Split-Path -Parent $flutterPath
}
# Also check common locations even if flutter wasn't found in PATH
if (-not $flutterBinDir) {
    $checkPaths = @(
        "$InstallDir\flutter\bin",
        "$env:USERPROFILE\flutter\bin",
        "C:\flutter\bin",
        "C:\src\flutter\bin",
        "C:\portable\flutter\bin"
    )
    foreach ($cp in $checkPaths) {
        if (Test-Path "$cp\flutter.bat") {
            $flutterBinDir = $cp
            break
        }
    }
}

if ($flutterBinDir) {
    # Always ensure Flutter is in Windows User PATH + Git Bash ~/.bashrc
    $pathRegistered = Add-ToUserPath $flutterBinDir
    $pathEntries = $env:Path -split ";"
    $flutterInPath = $pathEntries | Where-Object { $_ -match "flutter" }
    Write-Status "     " "OK" "Flutter in PATH: $($flutterInPath -join ', ')"
    if ($pathRegistered) {
        Write-Status "     " "INFO" "PATH was missing -- registered now"
    }
} else {
    Write-Status "     " "FAIL" "Flutter not found -- will install in Phase 2"
}

# Find and register JAVA_HOME (runs every time)
$javaHome = $env:JAVA_HOME
if (-not $javaHome -or -not (Test-Path $javaHome)) {
    $jdkSearchPaths = @(
        "C:\Program Files\Microsoft\jdk-*",
        "C:\Program Files\Eclipse Adoptium\jdk-*",
        "C:\Program Files\Java\jdk-*",
        "C:\Program Files\Java\jdk*"
    )
    foreach ($pattern in $jdkSearchPaths) {
        $found = Resolve-Path $pattern -ErrorAction SilentlyContinue | Sort-Object -Descending | Select-Object -First 1
        if ($found) {
            $javaHome = $found.Path
            break
        }
    }
}
if ($javaHome -and (Test-Path $javaHome)) {
    # Set JAVA_HOME for Windows
    if (-not $env:JAVA_HOME -or $env:JAVA_HOME -ne $javaHome) {
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, "User")
        $env:JAVA_HOME = $javaHome
    }
    if ($env:Path -notlike "*$javaHome\bin*") {
        $env:Path += ";$javaHome\bin"
    }
    Add-ToUserPath "$javaHome\bin" | Out-Null

    # Also write JAVA_HOME to bash_profile for Git Bash
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $javaUnix = $javaHome -replace "\\","/"
    if ($javaUnix -match "^([A-Za-z]):(.*)") {
        $javaUnix = "/" + $Matches[1].ToLower() + $Matches[2]
    }
    foreach ($rcFile in @("$env:USERPROFILE\.bashrc", "$env:USERPROFILE\.bash_profile")) {
        if (-not (Test-Path $rcFile)) {
            [System.IO.File]::WriteAllText($rcFile, "", $utf8NoBom)
        }
        $content = [System.IO.File]::ReadAllText($rcFile, $utf8NoBom)
        if ($content -notmatch "JAVA_HOME") {
            $javaExport = "`nexport JAVA_HOME=`"$javaUnix`"`nexport PATH=`"`$PATH:`$JAVA_HOME/bin`"`n"
            [System.IO.File]::WriteAllText($rcFile, $content + $javaExport, $utf8NoBom)
            $rcName = Split-Path -Leaf $rcFile
            Write-Status "     " "INFO" "JAVA_HOME added to ~/$rcName"
        }
    }
    Write-Status "     " "OK" "JAVA_HOME: $javaHome"
} else {
    Write-Status "     " "WARN" "JAVA_HOME not set -- will install JDK in Phase 2"
}

$pathEntries = $env:Path -split ";"
$androidInPath = $pathEntries | Where-Object { $_ -match "android|Android" }
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
        $jdkPath = "C:\Program Files\Microsoft\jdk-$JDK_VERSION*"
        $jdkResolved = (Resolve-Path $jdkPath -ErrorAction SilentlyContinue | Select-Object -First 1).Path
        if ($jdkResolved) {
            $env:Path += ";$jdkResolved\bin"
            $env:JAVA_HOME = $jdkResolved
            [Environment]::SetEnvironmentVariable("JAVA_HOME", $jdkResolved, "User")
            Write-Status "     " "INFO" "JAVA_HOME set to $jdkResolved"
        }
    } else {
        Write-Status "[$installStep/$installTotal]" "FAIL" "Please install JDK 17 manually: https://learn.microsoft.com/en-us/java/openjdk/download"
    }
    if (Test-CommandExists "java") {
        Write-Status "[$installStep/$installTotal]" "OK" "JDK $JDK_VERSION installed"
    } else {
        Write-Status "[$installStep/$installTotal]" "WARN" "JDK may need a terminal restart to be detected"
    }
}

# --- Install Flutter SDK (latest stable via git) ---
if ($diagnosis["flutter"] -ne "OK") {
    $installStep++
    $flutterDir = "$InstallDir\flutter"
    Write-Status "[$installStep/$installTotal]" "WORK" "Installing Flutter (latest stable) to $flutterDir ..."

    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }

    if (-not (Test-CommandExists "git")) {
        Write-Status "[$installStep/$installTotal]" "FAIL" "Git is required to install Flutter. Install Git first."
        exit 1
    }

    Write-Host "         Cloning Flutter stable branch (this takes a few minutes)..." -ForegroundColor DarkGray
    $cloneOut = & git clone https://github.com/flutter/flutter.git -b stable "$flutterDir" 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0 -and -not (Test-Path "$flutterDir\bin\flutter.bat")) {
        Write-Status "[$installStep/$installTotal]" "FAIL" "Flutter clone failed"
        Write-Host $cloneOut -ForegroundColor Red
        exit 1
    }

    $flutterBin = "$flutterDir\bin"
    if (Test-Path "$flutterBin\flutter.bat") {
        Add-ToUserPath $flutterBin | Out-Null
        $env:Path += ";$flutterBin"

        Write-Host "         Running initial Flutter setup (flutter doctor)..." -ForegroundColor DarkGray
        & flutter doctor 2>&1 | Out-String | Out-Null

        $installedVer = ((& flutter --version 2>&1 | Out-String) -split "`n")[0].Trim()
        Write-Status "[$installStep/$installTotal]" "OK" "$installedVer installed to $flutterDir"
        Write-Status "     " "INFO" "Added to User PATH: $flutterBin"
    } else {
        Write-Status "[$installStep/$installTotal]" "FAIL" "Flutter clone incomplete. Check $flutterDir"
        exit 1
    }
}

# --- Install Android SDK (command-line tools) ---
if ($diagnosis["android_sdk"] -ne "OK") {
    $installStep++
    $androidSdkPath = "$InstallDir\Android\Sdk"
    $cmdlineDir = "$androidSdkPath\cmdline-tools"
    $cmdlineZipUrl = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
    $cmdlineZip = "$env:TEMP\android-cmdline-tools.zip"

    Write-Status "[$installStep/$installTotal]" "WORK" "Installing Android SDK command-line tools..."

    if (-not (Test-Path $androidSdkPath)) {
        New-Item -ItemType Directory -Path $androidSdkPath -Force | Out-Null
    }

    if (-not (Test-Path "$cmdlineDir\latest\bin\sdkmanager.bat")) {
        if (-not (Test-Path $cmdlineZip)) {
            Write-Host "         Downloading Android command-line tools (~150 MB)..." -ForegroundColor DarkGray
            try {
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                $wc = New-Object System.Net.WebClient
                $wc.DownloadFile($cmdlineZipUrl, $cmdlineZip)
            } catch {
                Write-Status "[$installStep/$installTotal]" "FAIL" "Download failed: $_"
                Write-Host "         Manual: https://developer.android.com/studio#command-line-tools-only" -ForegroundColor Yellow
            }
        }

        if (Test-Path $cmdlineZip) {
            Write-Host "         Extracting..." -ForegroundColor DarkGray
            $tempExtract = "$env:TEMP\android-cmdline-extract"
            Expand-Archive -Path $cmdlineZip -DestinationPath $tempExtract -Force
            if (-not (Test-Path $cmdlineDir)) {
                New-Item -ItemType Directory -Path $cmdlineDir -Force | Out-Null
            }
            if (Test-Path "$tempExtract\cmdline-tools") {
                if (Test-Path "$cmdlineDir\latest") {
                    Remove-Item "$cmdlineDir\latest" -Recurse -Force
                }
                Rename-Item "$tempExtract\cmdline-tools" "latest"
                Move-Item "$tempExtract\latest" "$cmdlineDir\latest" -Force
            }
            Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    $sdkManager = "$cmdlineDir\latest\bin\sdkmanager.bat"
    if (Test-Path $sdkManager) {
        # Set ANDROID_HOME
        [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidSdkPath, "User")
        $env:ANDROID_HOME = $androidSdkPath
        $env:Path += ";$androidSdkPath\cmdline-tools\latest\bin;$androidSdkPath\platform-tools"

        Write-Host "         Installing platform-tools and build-tools..." -ForegroundColor DarkGray
        echo "y" | & $sdkManager --sdk_root="$androidSdkPath" "platform-tools" "build-tools;34.0.0" "platforms;android-34" 2>&1 | Out-String | Out-Null

        Write-Host "         Accepting licenses..." -ForegroundColor DarkGray
        echo "y`ny`ny`ny`ny`ny`ny`ny`ny" | & $sdkManager --sdk_root="$androidSdkPath" --licenses 2>&1 | Out-String | Out-Null

        Add-ToUserPath "$androidSdkPath\cmdline-tools\latest\bin" | Out-Null
        Add-ToUserPath "$androidSdkPath\platform-tools" | Out-Null

        # Tell Flutter where the SDK is
        if (Test-CommandExists "flutter") {
            flutter config --android-sdk="$androidSdkPath" 2>&1 | Out-Null
        }

        Write-Status "[$installStep/$installTotal]" "OK" "Android SDK installed to $androidSdkPath"
    } else {
        Write-Status "[$installStep/$installTotal]" "FAIL" "sdkmanager not found after extraction"
        Write-Host "         Install Android Studio instead: https://developer.android.com/studio" -ForegroundColor Yellow
    }
}

# --- Android SDK license (if SDK exists but licenses not accepted) ---
if ($diagnosis["android_license"] -ne "OK" -and ($diagnosis["android_sdk"] -eq "OK" -or (Test-Path "$androidSdkPath\cmdline-tools\latest\bin\sdkmanager.bat"))) {
    $installStep++
    Write-Status "[$installStep/$installTotal]" "WORK" "Accepting Android SDK licenses..."
    $sdkMgr = "$androidSdkPath\cmdline-tools\latest\bin\sdkmanager.bat"
    if (Test-Path $sdkMgr) {
        echo "y`ny`ny`ny`ny`ny`ny`ny`ny" | & $sdkMgr --sdk_root="$androidSdkPath" --licenses 2>&1 | Out-String | Out-Null
        Write-Status "[$installStep/$installTotal]" "OK" "Android SDK licenses accepted"
    } else {
        Write-Status "[$installStep/$installTotal]" "WARN" "Run: flutter doctor --android-licenses"
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
Write-Host "    source ~/.bash_profile           # reload PATH" -ForegroundColor Green
Write-Host "    OR close and reopen Git Bash" -ForegroundColor DarkGray
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
