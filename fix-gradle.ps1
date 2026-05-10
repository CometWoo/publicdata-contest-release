#Requires -Version 5.1
# fix-gradle.ps1 - Gradle cache lock/corruption fixer
# Fixes "Could not move temporary workspace to immutable location" errors
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File fix-gradle.ps1
#   powershell -ExecutionPolicy Bypass -File fix-gradle.ps1 -ThenBuild

param(
    [switch]$ThenBuild
)

$ErrorActionPreference = "Continue"
$gradleHome = "$env:USERPROFILE\.gradle"
$cachesDir = "$gradleHome\caches"
$fixCount = 0

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Gradle Cache Lock Fixer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# --- Step 1: Kill all Gradle/Java daemon processes ---
Write-Host "[1/5] Stopping Gradle and Java daemons..." -ForegroundColor White

$processNames = @("java", "javaw", "gradle", "dart", "dartvm", "kotlin-daemon")
$killed = 0
foreach ($name in $processNames) {
    $procs = Get-Process -Name $name -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        try {
            $p.Kill()
            $killed++
        } catch {}
    }
}

if (Test-Path "$gradleHome\daemon") {
    & gradle --stop 2>&1 | Out-Null
}

if ($killed -gt 0) {
    Write-Host "       Killed $killed process(es). Waiting 3 seconds..." -ForegroundColor Green
    Start-Sleep -Seconds 3
} else {
    Write-Host "       No running processes found." -ForegroundColor DarkGray
}

# --- Step 2: Remove corrupted transforms directories ---
Write-Host "[2/5] Cleaning corrupted transforms cache..." -ForegroundColor White

if (Test-Path $cachesDir) {
    $cacheVersions = Get-ChildItem $cachesDir -Directory -ErrorAction SilentlyContinue
    foreach ($ver in $cacheVersions) {
        $transformsDir = Join-Path $ver.FullName "transforms"
        if (Test-Path $transformsDir) {
            $items = Get-ChildItem $transformsDir -Directory -ErrorAction SilentlyContinue
            $tempItems = $items | Where-Object { $_.Name -match "^[a-f0-9]+-[a-f0-9]{8}-" }
            $targetItems = $items | Where-Object { $_.Name -match "^[a-f0-9]+$" -and $_.Name.Length -eq 32 }

            foreach ($temp in $tempItems) {
                Remove-Item $temp.FullName -Recurse -Force -ErrorAction SilentlyContinue
                $fixCount++
            }
            foreach ($target in $targetItems) {
                Remove-Item $target.FullName -Recurse -Force -ErrorAction SilentlyContinue
                $fixCount++
            }

            if ($fixCount -gt 0) {
                Write-Host "       Cleaned $fixCount item(s) from $($ver.Name)\transforms" -ForegroundColor Green
            }
        }
    }
} else {
    Write-Host "       No Gradle cache found." -ForegroundColor DarkGray
}

if ($fixCount -eq 0) {
    Write-Host "       No corrupted entries found. Cleaning entire transforms..." -ForegroundColor Yellow
    Get-ChildItem "$cachesDir\*\transforms" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        $fixCount++
    }
    Write-Host "       Removed $fixCount transforms directory(ies)." -ForegroundColor Green
}

# --- Step 3: Remove lock files ---
Write-Host "[3/5] Removing lock files..." -ForegroundColor White

$lockFiles = Get-ChildItem $cachesDir -Filter "*.lock" -Recurse -ErrorAction SilentlyContinue
$lockCount = $lockFiles.Count
foreach ($lock in $lockFiles) {
    Remove-Item $lock.FullName -Force -ErrorAction SilentlyContinue
}

$gcLockFiles = Get-ChildItem $cachesDir -Filter "gc.properties" -Recurse -ErrorAction SilentlyContinue
foreach ($gc in $gcLockFiles) {
    Remove-Item $gc.FullName -Force -ErrorAction SilentlyContinue
    $lockCount++
}

Write-Host "       Removed $lockCount lock file(s)." -ForegroundColor Green

# --- Step 4: Fix file permissions ---
Write-Host "[4/5] Resetting file permissions..." -ForegroundColor White

$readOnlyFiles = Get-ChildItem $cachesDir -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.IsReadOnly }
$roCount = 0
foreach ($ro in $readOnlyFiles) {
    $ro.IsReadOnly = $false
    $roCount++
}

Write-Host "       Fixed $roCount read-only file(s)." -ForegroundColor Green

# --- Step 5: Clean project build cache ---
Write-Host "[5/5] Cleaning project build cache..." -ForegroundColor White

$projectBuild = ".\build"
$projectAndroidBuild = ".\android\.gradle"
$cleaned = @()
if (Test-Path $projectBuild) {
    Remove-Item $projectBuild -Recurse -Force -ErrorAction SilentlyContinue
    $cleaned += "build/"
}
if (Test-Path $projectAndroidBuild) {
    Remove-Item $projectAndroidBuild -Recurse -Force -ErrorAction SilentlyContinue
    $cleaned += "android/.gradle/"
}
if (Test-Path ".\.dart_tool") {
    Remove-Item ".\.dart_tool" -Recurse -Force -ErrorAction SilentlyContinue
    $cleaned += ".dart_tool/"
}

if ($cleaned.Count -gt 0) {
    Write-Host "       Cleaned: $($cleaned -join ', ')" -ForegroundColor Green
} else {
    Write-Host "       No project build cache found." -ForegroundColor DarkGray
}

# --- Summary ---
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Fix complete." -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

if ($ThenBuild) {
    Write-Host "  Running: flutter clean + pub get + build apk..." -ForegroundColor White
    Write-Host ""
    flutter clean 2>&1 | Out-Null
    flutter pub get 2>&1
    flutter build apk --release 2>&1
} else {
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host "    flutter clean" -ForegroundColor Green
    Write-Host "    flutter pub get" -ForegroundColor Green
    Write-Host "    flutter build apk" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Or run with auto-build:" -ForegroundColor DarkGray
    Write-Host "    powershell -ExecutionPolicy Bypass -File fix-gradle.ps1 -ThenBuild" -ForegroundColor DarkGray
}
Write-Host ""
