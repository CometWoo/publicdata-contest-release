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

# 6. Android SDK + required components
$step = "[6/8]"
$androidSdkPath = if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
                  elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
                  elseif (Test-Path "$env:LOCALAPPDATA\Android\Sdk") { "$env:LOCALAPPDATA\Android\Sdk" }
                  else { $null }

# Required components for Flutter 3.41+
$requiredPlatform = "android-36"
$requiredBuildTools = "28.0.3"

if ($androidSdkPath -and (Test-Path $androidSdkPath)) {
    Write-Status $step "OK" "Android SDK" "Path: $androidSdkPath"
    $diagnosis["android_sdk"] = "OK"

    # Check cmdline-tools (needed to install missing components)
    if (Test-Path "$androidSdkPath\cmdline-tools\latest\bin\sdkmanager.bat") {
        Write-Status "     " "OK" "cmdline-tools installed"
        $diagnosis["cmdline_tools"] = "OK"
    } else {
        Write-Status "     " "FAIL" "cmdline-tools not found (needed to install SDK components)"
        $diagnosis["cmdline_tools"] = "MISSING"
    }

    # Check platform android-36
    if (Test-Path "$androidSdkPath\platforms\$requiredPlatform") {
        Write-Status "     " "OK" "platforms;$requiredPlatform installed"
        $diagnosis["platform_36"] = "OK"
    } else {
        Write-Status "     " "FAIL" "platforms;$requiredPlatform missing"
        $diagnosis["platform_36"] = "MISSING"
    }

    # Check build-tools 28.0.3
    if (Test-Path "$androidSdkPath\build-tools\$requiredBuildTools") {
        Write-Status "     " "OK" "build-tools;$requiredBuildTools installed"
        $diagnosis["build_tools_28"] = "OK"
    } else {
        Write-Status "     " "FAIL" "build-tools;$requiredBuildTools missing"
        $diagnosis["build_tools_28"] = "MISSING"
    }

    # Check platform-tools
    if (Test-Path "$androidSdkPath\platform-tools\adb.exe") {
        Write-Status "     " "OK" "platform-tools installed"
        $diagnosis["platform_tools"] = "OK"
    } else {
        Write-Status "     " "FAIL" "platform-tools missing"
        $diagnosis["platform_tools"] = "MISSING"
    }

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
    $diagnosis["cmdline_tools"] = "MISSING"
    $diagnosis["platform_36"] = "MISSING"
    $diagnosis["build_tools_28"] = "MISSING"
    $diagnosis["platform_tools"] = "MISSING"
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

# --- Install cmdline-tools (needed for all SDK component management) ---
$needsCmdlineTools = ($diagnosis["cmdline_tools"] -ne "OK")
$needsSdkComponents = ($diagnosis["platform_36"] -ne "OK" -or $diagnosis["build_tools_28"] -ne "OK" -or $diagnosis["platform_tools"] -ne "OK")

if ($needsCmdlineTools -or $diagnosis["android_sdk"] -ne "OK") {
    $installStep++
    if (-not $androidSdkPath) { $androidSdkPath = "$InstallDir\Android\Sdk" }
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

    if (Test-Path "$cmdlineDir\latest\bin\sdkmanager.bat") {
        # Set ANDROID_HOME
        [Environment]::SetEnvironmentVariable("ANDROID_HOME", $androidSdkPath, "User")
        $env:ANDROID_HOME = $androidSdkPath
        $env:Path += ";$androidSdkPath\cmdline-tools\latest\bin;$androidSdkPath\platform-tools"
        Write-Status "[$installStep/$installTotal]" "OK" "cmdline-tools ready"
    } else {
        Write-Status "[$installStep/$installTotal]" "FAIL" "sdkmanager not found after extraction"
        Write-Host "         Install Android Studio instead: https://developer.android.com/studio" -ForegroundColor Yellow
    }
}

# --- Install missing SDK components via sdkmanager ---
$sdkMgr = "$androidSdkPath\cmdline-tools\latest\bin\sdkmanager.bat"
if ($needsSdkComponents -and (Test-Path $sdkMgr)) {
    $installStep++
    $componentsToInstall = @()

    if ($diagnosis["platform_36"] -ne "OK") {
        $componentsToInstall += "platforms;$requiredPlatform"
    }
    if ($diagnosis["build_tools_28"] -ne "OK") {
        $componentsToInstall += "build-tools;$requiredBuildTools"
    }
    if ($diagnosis["platform_tools"] -ne "OK") {
        $componentsToInstall += "platform-tools"
    }

    $compList = $componentsToInstall -join ", "
    Write-Status "[$installStep/$installTotal]" "WORK" "Installing SDK components: $compList"

    $sdkArgs = @("--sdk_root=$androidSdkPath") + $componentsToInstall
    echo "y`ny`ny`ny`ny`ny`ny`ny`ny" | & $sdkMgr @sdkArgs 2>&1 | Out-String | Out-Null

    # Verify
    $allOk = $true
    foreach ($comp in $componentsToInstall) {
        if ($comp -eq "platforms;$requiredPlatform" -and (Test-Path "$androidSdkPath\platforms\$requiredPlatform")) {
            Write-Status "     " "OK" "$comp installed"
        } elseif ($comp -eq "build-tools;$requiredBuildTools" -and (Test-Path "$androidSdkPath\build-tools\$requiredBuildTools")) {
            Write-Status "     " "OK" "$comp installed"
        } elseif ($comp -eq "platform-tools" -and (Test-Path "$androidSdkPath\platform-tools\adb.exe")) {
            Write-Status "     " "OK" "$comp installed"
        } else {
            Write-Status "     " "WARN" "$comp may need manual install"
            $allOk = $false
        }
    }
    if ($allOk) {
        Write-Status "[$installStep/$installTotal]" "OK" "All SDK components installed"
    }

    Add-ToUserPath "$androidSdkPath\cmdline-tools\latest\bin" | Out-Null
    Add-ToUserPath "$androidSdkPath\platform-tools" | Out-Null

    # Tell Flutter where the SDK is
    if (Test-CommandExists "flutter") {
        flutter config --android-sdk="$androidSdkPath" 2>&1 | Out-Null
    }
}

# --- Android SDK license ---
if ($diagnosis["android_license"] -ne "OK" -and (Test-Path $sdkMgr)) {
    $installStep++
    Write-Status "[$installStep/$installTotal]" "WORK" "Accepting Android SDK licenses..."
    echo "y`ny`ny`ny`ny`ny`ny`ny`ny" | & $sdkMgr --sdk_root="$androidSdkPath" --licenses 2>&1 | Out-String | Out-Null
    Write-Status "[$installStep/$installTotal]" "OK" "Android SDK licenses accepted"
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

    # Clean corrupted Gradle transforms cache
    # Gradle fails when it can't move temp workspaces to immutable locations.
    # Deleting the entire transforms folder for each cache version forces
    # a clean rebuild on next build.
    $gradleCaches = "$env:USERPROFILE\.gradle\caches"
    if (Test-Path $gradleCaches) {
        $transformsDirs = Get-ChildItem "$gradleCaches\*\transforms" -Directory -ErrorAction SilentlyContinue
        if ($transformsDirs) {
            Write-Host "  Cleaning Gradle transforms cache..." -ForegroundColor DarkGray
            foreach ($tDir in $transformsDirs) {
                Remove-Item $tDir.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
            Write-Status "     " "INFO" "Gradle transforms cache cleaned ($($transformsDirs.Count) dir(s))"
        }
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
    Write-Host "         Running flutter clean..." -ForegroundColor DarkGray
    flutter clean 2>&1 | Out-String | Out-Null

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

# ================================================================
# [추가] PHASE 5: ANDROID EMULATOR SETUP
# ================================================================
# 기존 코드 미수정. 에뮬레이터 관련 기능만 이 블록에 추가.
# AVD 기본 구성: Pixel 6 / API 34 / Google Play / x86_64
# ================================================================

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  [추가] PHASE 5: Android Emulator Setup" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# [추가] 에뮬레이터 구성 상수
$EMU_AVD_NAME = "Silver_Voice_Pixel6_API34"
$EMU_DEVICE   = "pixel_6"
$EMU_API      = "34"
$EMU_ABI      = "x86_64"
$EMU_IMAGE    = "system-images;android-$EMU_API;google_apis_playstore;$EMU_ABI"

# [추가] androidSdkPath 재확인 (Phase 1~4가 건너뛰어진 경우 대비)
if (-not $androidSdkPath -or -not (Test-Path $androidSdkPath)) {
    $androidSdkPath = if ($env:ANDROID_HOME)                          { $env:ANDROID_HOME }
                      elseif ($env:ANDROID_SDK_ROOT)                  { $env:ANDROID_SDK_ROOT }
                      elseif (Test-Path "$env:LOCALAPPDATA\Android\Sdk") { "$env:LOCALAPPDATA\Android\Sdk" }
                      else                                            { "$InstallDir\Android\Sdk" }
}

$emuSdkMgr = "$androidSdkPath\cmdline-tools\latest\bin\sdkmanager.bat"
$emuAvdMgr = "$androidSdkPath\cmdline-tools\latest\bin\avdmanager.bat"
$emuExe    = "$androidSdkPath\emulator\emulator.exe"
$emuAdb    = "$androidSdkPath\platform-tools\adb.exe"
$emuSysImg = "$androidSdkPath\system-images\android-$EMU_API\google_apis_playstore\$EMU_ABI"

# ----------------------------------------------------------------
# [추가] PHASE 5-1: 에뮬레이터 환경 진단
# ----------------------------------------------------------------
Write-Host "--- [E] Emulator Diagnosis ---" -ForegroundColor White
Write-Host ""

$emuDiag    = @{}
$emuFoundAvd = $null

# E1. ADB
$step = "[E1/6]"
if ((Test-Path $emuAdb) -or (Test-CommandExists "adb")) {
    Write-Status $step "OK" "ADB found"
    $emuDiag["adb"] = "OK"
    if ($env:Path -notlike "*platform-tools*") { $env:Path += ";$androidSdkPath\platform-tools" }
} else {
    Write-Status $step "FAIL" "ADB 없음 — platform-tools 미설치"
    $emuDiag["adb"] = "MISSING"
}

# E2. Emulator 실행 파일
$step = "[E2/6]"
if (Test-Path $emuExe) {
    Write-Status $step "OK" "Emulator binary found"
    $emuDiag["emulator"] = "OK"
    if ($env:Path -notlike "*\emulator*") { $env:Path += ";$androidSdkPath\emulator" }
} else {
    Write-Status $step "FAIL" "emulator.exe 없음 (emulator 패키지 미설치)"
    $emuDiag["emulator"] = "MISSING"
}

# E3. System image (API 34 / google_apis_playstore / x86_64)
$step = "[E3/6]"
if (Test-Path $emuSysImg) {
    Write-Status $step "OK" "System image: android-$EMU_API / google_apis_playstore / $EMU_ABI"
    $emuDiag["sys_image"] = "OK"
} else {
    Write-Status $step "FAIL" "System image 없음: $EMU_IMAGE"
    $emuDiag["sys_image"] = "MISSING"
}

# E4. AVD 존재 여부
$step = "[E4/6]"
if (Test-CommandExists "flutter") {
    $emuListOut = flutter emulators 2>&1 | Out-String
    if ($emuListOut -match $EMU_AVD_NAME) {
        Write-Status $step "OK" "AVD '$EMU_AVD_NAME' 존재"
        $emuDiag["avd"] = "OK"
        $emuFoundAvd = $EMU_AVD_NAME
    } elseif ($emuListOut -match "([A-Za-z0-9_.\-]+)\s+•") {
        $emuFoundAvd = $Matches[1]
        Write-Status $step "WARN" "다른 AVD 발견: $emuFoundAvd (기존 AVD 사용)"
        $emuDiag["avd"] = "FOUND_OTHER"
    } else {
        Write-Status $step "FAIL" "AVD 없음 → '$EMU_AVD_NAME' 자동 생성 예정"
        $emuDiag["avd"] = "MISSING"
    }
} elseif (Test-Path $emuAvdMgr) {
    $avdListRaw = & $emuAvdMgr list avd 2>&1 | Out-String
    if ($avdListRaw -match $EMU_AVD_NAME) {
        Write-Status $step "OK" "AVD '$EMU_AVD_NAME' 존재 (avdmanager 확인)"
        $emuDiag["avd"] = "OK"
        $emuFoundAvd = $EMU_AVD_NAME
    } else {
        Write-Status $step "FAIL" "AVD 없음 → 자동 생성 예정"
        $emuDiag["avd"] = "MISSING"
    }
} else {
    Write-Status $step "WARN" "Flutter/avdmanager 없어 AVD 확인 불가"
    $emuDiag["avd"] = "UNKNOWN"
}

# E5. Hyper-V / HAXM (하드웨어 가속)
$step = "[E5/6]"
try {
    $hvFeature = Get-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online -ErrorAction Stop
    if ($hvFeature.State -eq "Enabled") {
        Write-Status $step "OK" "Hyper-V 활성화됨 (하드웨어 가속 가능)"
        $emuDiag["accel"] = "OK"
    } else {
        $haxmKey = Get-ItemProperty "HKLM:\SOFTWARE\Intel\HAXM" -ErrorAction SilentlyContinue
        if ($haxmKey) {
            Write-Status $step "OK" "Intel HAXM 설치됨 (하드웨어 가속 가능)"
            $emuDiag["accel"] = "OK"
        } else {
            Write-Status $step "WARN" "Hyper-V/HAXM 비활성화 — 에뮬레이터 속도 저하 가능"
            $emuDiag["accel"] = "WARN"
        }
    }
} catch {
    Write-Status $step "WARN" "가상화 상태 확인 실패 (권한 부족 가능성)"
    $emuDiag["accel"] = "WARN"
}

# E6. avdmanager
$step = "[E6/6]"
if (Test-Path $emuAvdMgr) {
    Write-Status $step "OK" "avdmanager found"
    $emuDiag["avdmgr"] = "OK"
} else {
    Write-Status $step "FAIL" "avdmanager 없음 — cmdline-tools 미설치"
    $emuDiag["avdmgr"] = "MISSING"
}

Write-Host ""

# ----------------------------------------------------------------
# [추가] PHASE 5-2: 없는 항목 자동 설치
# ----------------------------------------------------------------
Write-Host "--- [E] Emulator Auto-Install ---" -ForegroundColor White
Write-Host ""

# E-INST 1: emulator 패키지
if ($emuDiag["emulator"] -ne "OK" -and (Test-Path $emuSdkMgr)) {
    Write-Status "[E-INST]" "WORK" "emulator 패키지 설치 중..."
    echo "y" | & $emuSdkMgr --sdk_root="$androidSdkPath" emulator 2>&1 | Out-String | Out-Null
    if (Test-Path $emuExe) {
        Write-Status "[E-INST]" "OK" "emulator 패키지 설치 완료"
        $emuDiag["emulator"] = "OK"
        $env:Path += ";$androidSdkPath\emulator"
        Add-ToUserPath "$androidSdkPath\emulator" | Out-Null
    } else {
        Write-Status "[E-INST]" "FAIL" "emulator 설치 실패 — Android Studio 설치 권장"
    }
} elseif ($emuDiag["emulator"] -ne "OK") {
    Write-Status "[E-INST]" "SKIP" "sdkmanager 없어 emulator 자동 설치 불가"
}

# E-INST 2: ADB (platform-tools)
if ($emuDiag["adb"] -ne "OK" -and (Test-Path $emuSdkMgr)) {
    Write-Status "[E-INST]" "WORK" "platform-tools (ADB) 설치 중..."
    echo "y" | & $emuSdkMgr --sdk_root="$androidSdkPath" "platform-tools" 2>&1 | Out-String | Out-Null
    if (Test-Path $emuAdb) {
        Write-Status "[E-INST]" "OK" "ADB 설치 완료"
        $emuDiag["adb"] = "OK"
        $env:Path += ";$androidSdkPath\platform-tools"
        Add-ToUserPath "$androidSdkPath\platform-tools" | Out-Null
    } else {
        Write-Status "[E-INST]" "FAIL" "ADB 설치 실패"
    }
}

# E-INST 3: System image (API 34) — 용량 크므로 사용자 확인
if ($emuDiag["sys_image"] -ne "OK" -and (Test-Path $emuSdkMgr)) {
    Write-Host ""
    Write-Host "  System image (~1.5 GB) 다운로드가 필요합니다." -ForegroundColor Yellow
    $dlConfirm = Read-Host "  계속 진행할까요? (y/n)"
    if ($dlConfirm -eq "y") {
        Write-Status "[E-INST]" "WORK" "System image 설치 중: $EMU_IMAGE (시간이 오래 걸립니다)..."
        echo "y" | & $emuSdkMgr --sdk_root="$androidSdkPath" "$EMU_IMAGE" 2>&1 | Out-String | Out-Null
        if (Test-Path $emuSysImg) {
            Write-Status "[E-INST]" "OK" "System image 설치 완료"
            $emuDiag["sys_image"] = "OK"
        } else {
            Write-Status "[E-INST]" "FAIL" "System image 설치 실패"
            Write-Host "         수동 실행: sdkmanager `"$EMU_IMAGE`"" -ForegroundColor Yellow
        }
    } else {
        Write-Status "[E-INST]" "SKIP" "System image 설치 건너뜀 — AVD 생성 불가"
    }
} elseif ($emuDiag["sys_image"] -ne "OK") {
    Write-Status "[E-INST]" "SKIP" "sdkmanager 없어 System image 자동 설치 불가"
}

# E-INST 4: Hyper-V 활성화 (관리자 권한 필요)
if ($emuDiag["accel"] -eq "WARN") {
    if (Test-Admin) {
        Write-Status "[E-INST]" "WORK" "Hyper-V 활성화 중..."
        try {
            Enable-WindowsOptionalFeature -FeatureName Microsoft-Hyper-V-All -Online -NoRestart -ErrorAction Stop | Out-Null
            Write-Status "[E-INST]" "OK" "Hyper-V 활성화 완료 (재부팅 후 적용)"
            Write-Host "         [!!] 재부팅 후 에뮬레이터 성능이 향상됩니다." -ForegroundColor Yellow
            $emuDiag["accel"] = "OK"
        } catch {
            Write-Status "[E-INST]" "WARN" "Hyper-V 자동 활성화 실패: $_"
            Write-Host "         수동 활성화: 설정 > Windows 기능 켜기/끄기 > Hyper-V" -ForegroundColor Yellow
        }
    } else {
        Write-Status "[E-INST]" "WARN" "Hyper-V 활성화는 관리자 권한 필요 — 관리자로 재실행 권장"
    }
}

# E-INST 5: AVD 생성
if ($emuDiag["avd"] -eq "MISSING" -and (Test-Path $emuAvdMgr) -and $emuDiag["sys_image"] -eq "OK") {
    Write-Status "[E-INST]" "WORK" "AVD 생성 중: $EMU_AVD_NAME (Pixel 6 / API $EMU_API)..."
    $avdCreateOut = & $emuAvdMgr create avd `
        --name    "$EMU_AVD_NAME" `
        --device  "$EMU_DEVICE" `
        --package "$EMU_IMAGE" `
        --force 2>&1 | Out-String

    $avdVerify = if (Test-CommandExists "flutter") { flutter emulators 2>&1 | Out-String }
                 else { & $emuAvdMgr list avd 2>&1 | Out-String }

    if ($avdVerify -match $EMU_AVD_NAME) {
        Write-Status "[E-INST]" "OK" "AVD '$EMU_AVD_NAME' 생성 완료 (Pixel 6 / API $EMU_API / Google Play)"
        $emuDiag["avd"] = "OK"
        $emuFoundAvd = $EMU_AVD_NAME
    } else {
        Write-Status "[E-INST]" "FAIL" "AVD 생성 실패"
        Write-Host $avdCreateOut -ForegroundColor Red
    }
} elseif ($emuDiag["avd"] -eq "MISSING") {
    Write-Status "[E-INST]" "SKIP" "AVD 생성 건너뜀 — system image 또는 avdmanager 없음"
}

Write-Host ""

# ----------------------------------------------------------------
# [추가] PHASE 5-3: 에뮬레이터 실행 및 Flutter 앱 런치
# ----------------------------------------------------------------
Write-Host "--- [E] Emulator Launch & Flutter Run ---" -ForegroundColor White
Write-Host ""

if (-not $emuFoundAvd) {
    Write-Status "[EMU]" "FAIL" "실행 가능한 AVD 없음. 에뮬레이터 실행 건너뜁니다."
    Write-Host "         AVD 생성 후: flutter emulators --launch $EMU_AVD_NAME" -ForegroundColor Yellow
} elseif (-not (Test-Path $emuExe)) {
    Write-Status "[EMU]" "FAIL" "emulator.exe 없음. 실행 불가."
} else {
    Write-Status "[EMU]" "WORK" "에뮬레이터 실행 중: $emuFoundAvd ..."

    # 백그라운드로 에뮬레이터 실행
    Start-Process -FilePath $emuExe `
        -ArgumentList @("-avd", $emuFoundAvd, "-no-snapshot-load") `
        -WindowStyle Normal

    Write-Host "         에뮬레이터 부팅 대기 중... (1~3분 소요)" -ForegroundColor DarkGray

    $adbCmd = if (Test-Path $emuAdb) { $emuAdb } else { "adb" }

    # 디바이스 연결 대기
    & $adbCmd wait-for-device 2>&1 | Out-Null

    # sys.boot_completed = 1 폴링
    $emuTimeout = 180
    $emuElapsed = 0
    $emuBooted  = $false

    while ($emuElapsed -lt $emuTimeout) {
        $bootVal = (& $adbCmd shell getprop sys.boot_completed 2>&1) -replace "\s", ""
        if ($bootVal -eq "1") {
            $emuBooted = $true
            break
        }
        Start-Sleep -Seconds 5
        $emuElapsed += 5
        Write-Host "         [$emuElapsed s / ${emuTimeout}s] 부팅 대기..." -ForegroundColor DarkGray
    }

    if ($emuBooted) {
        Write-Status "[EMU]" "OK" "에뮬레이터 부팅 완료 (${emuElapsed}s)"
        Write-Host ""

        # Flutter 앱 실행
        $runDir = $null
        if ($ProjectDir -and (Test-Path "$ProjectDir\pubspec.yaml")) {
            $runDir = $ProjectDir
        } elseif (Test-Path "pubspec.yaml") {
            $runDir = (Get-Location).Path
        }

        if ($runDir) {
            Write-Status "[RUN]" "WORK" "flutter run 실행 중 ($runDir)..."
            Set-Location $runDir
            & flutter run
        } else {
            Write-Status "[RUN]" "WARN" "pubspec.yaml 없음. 프로젝트 폴더에서 직접 실행하세요:"
            Write-Host "         cd $InstallDir\publicdata-contest-release" -ForegroundColor Green
            Write-Host "         flutter run" -ForegroundColor Green
        }
    } else {
        Write-Status "[EMU]" "WARN" "부팅 타임아웃 (${emuTimeout}s 초과)"
        Write-Host "         에뮬레이터 창 확인 후 부팅 완료되면 실행: flutter run" -ForegroundColor Yellow
    }
}

# ----------------------------------------------------------------
# [추가] Emulator 빠른 참조
# ----------------------------------------------------------------
Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  [추가] Android Emulator 빠른 참조" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  AVD 목록:              flutter emulators" -ForegroundColor Green
Write-Host "  에뮬레이터 실행:       flutter emulators --launch $EMU_AVD_NAME" -ForegroundColor Green
Write-Host "  앱 실행:               flutter run" -ForegroundColor Green
Write-Host "  연결된 기기 목록:      flutter devices" -ForegroundColor Green
Write-Host "  특정 에뮬레이터 지정:  flutter run -d emulator-5554" -ForegroundColor Green
Write-Host "  에뮬레이터 종료:       adb emu kill" -ForegroundColor Green
Write-Host ""
Write-Host "  진단만:                .\setup.ps1 -DiagnoseOnly" -ForegroundColor DarkGray
Write-Host "  클론 없이:             .\setup.ps1 -SkipClone" -ForegroundColor DarkGray
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""
