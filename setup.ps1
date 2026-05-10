# Silver Voice - Environment Setup Script (Windows PowerShell)
# Run: powershell -ExecutionPolicy Bypass -File setup.ps1

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Auto-detect Flutter SDK path ---
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCmd) {
    $searchPaths = @(
        "$env:USERPROFILE\flutter\bin",
        "$env:LOCALAPPDATA\flutter\bin",
        "C:\flutter\bin",
        "C:\src\flutter\bin",
        "C:\portable\flutter\bin",
        "D:\flutter\bin"
    )
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $parentDir = Split-Path -Parent $scriptDir
    $searchPaths += "$parentDir\flutter\bin"

    foreach ($p in $searchPaths) {
        if (Test-Path "$p\flutter.bat") {
            $env:Path += ";$p"
            break
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Silver Voice - Environment Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$hasError = $false

# --- Step 1: Flutter SDK ---
Write-Host "[1/6] Flutter SDK ..." -NoNewline
$flutterCmd = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterCmd) {
    $flutterVersion = flutter --version 2>&1 | Out-String
    $ver = ($flutterVersion -split "`n")[0].Trim()
    Write-Host " [OK] $ver" -ForegroundColor Green
    Write-Host "       Path: $($flutterCmd.Source)" -ForegroundColor DarkGray
} else {
    Write-Host " [FAIL] Flutter not found in PATH." -ForegroundColor Red
    Write-Host "    1. Install: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    Write-Host "    2. Or set PATH: `$env:Path += `";C:\your\flutter\bin`"" -ForegroundColor Yellow
    $hasError = $true
}

# --- Step 2: Dart SDK ---
Write-Host "[2/6] Dart SDK ..." -NoNewline
$dartCmd = Get-Command dart -ErrorAction SilentlyContinue
if ($dartCmd) {
    $dartVersion = dart --version 2>&1 | Out-String
    Write-Host " [OK] $($dartVersion.Trim())" -ForegroundColor Green

    if ($dartVersion -match "(\d+)\.(\d+)\.(\d+)") {
        $major = [int]$Matches[1]; $minor = [int]$Matches[2]
        if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 2)) {
            Write-Host "    [WARN] Dart 3.2.0+ required. Current: $($Matches[0])" -ForegroundColor Yellow
        }
    }
} else {
    if ($flutterCmd) {
        Write-Host " [WARN] dart not in PATH, but Flutter includes Dart" -ForegroundColor Yellow
    } else {
        Write-Host " [FAIL] Dart SDK not found." -ForegroundColor Red
        $hasError = $true
    }
}

# --- Step 3: Chrome ---
Write-Host "[3/6] Chrome browser ..." -NoNewline
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$chromePath2 = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
if ((Test-Path $chromePath) -or (Test-Path $chromePath2)) {
    Write-Host " [OK] Chrome installed" -ForegroundColor Green
} else {
    Write-Host " [WARN] Chrome not found - flutter run -d chrome unavailable" -ForegroundColor Yellow
}

# Skip steps 4-6 if Flutter is not available
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "[4/6] Flutter Web support ... [SKIP] Flutter required" -ForegroundColor DarkGray
    Write-Host "[5/6] Flutter packages ...    [SKIP] Flutter required" -ForegroundColor DarkGray
    Write-Host "[6/6] Dart analysis ...       [SKIP] Flutter required" -ForegroundColor DarkGray
} else {
    # --- Step 4: Flutter Web support ---
    Write-Host "[4/6] Flutter Web support ..." -NoNewline
    $devices = flutter devices 2>&1 | Out-String
    if ($devices -match "Chrome|chrome|Web") {
        Write-Host " [OK] Web device available" -ForegroundColor Green
    } else {
        Write-Host " [WARN] No Web device. Enabling..." -ForegroundColor Yellow
        flutter config --enable-web 2>&1 | Out-Null
    }

    # --- Step 5: Dependencies ---
    Write-Host "[5/6] Flutter packages ..." -NoNewline
    $pubResult = flutter pub get 2>&1 | Out-String
    if ($pubResult -match "Got dependencies" -or $pubResult -match "Resolving") {
        Write-Host " [OK] Dependencies installed" -ForegroundColor Green
    } else {
        Write-Host " [FAIL] Dependency install failed" -ForegroundColor Red
        Write-Host $pubResult -ForegroundColor Red
        $hasError = $true
    }

    # --- Step 6: Static analysis ---
    Write-Host "[6/6] Dart analysis ..." -NoNewline
    $analyzeResult = flutter analyze --no-pub 2>&1 | Out-String
    if ($analyzeResult -match "No issues found" -or $analyzeResult -match "0 issues") {
        Write-Host " [OK] No issues" -ForegroundColor Green
    } elseif ($analyzeResult -match "error") {
        Write-Host " [FAIL] Analysis errors found" -ForegroundColor Red
        Write-Host $analyzeResult -ForegroundColor Yellow
        $hasError = $true
    } else {
        Write-Host " [WARN] Warnings found (build OK)" -ForegroundColor Yellow
        Write-Host $analyzeResult -ForegroundColor Yellow
    }
}

# --- Summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($hasError) {
    Write-Host "  [FAIL] Some steps failed." -ForegroundColor Red
    Write-Host "  Fix the errors above and re-run." -ForegroundColor Yellow
} else {
    Write-Host "  [OK] Environment ready!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Run commands:" -ForegroundColor White
    Write-Host "    flutter run -d chrome        # Web browser" -ForegroundColor Cyan
    Write-Host "    flutter run -d windows       # Windows desktop" -ForegroundColor Cyan
    Write-Host "    flutter run -d <device_id>   # Connected mobile" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Debug server port:" -ForegroundColor White
    Write-Host "    http://localhost:PORT (shown in console)" -ForegroundColor Cyan
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
