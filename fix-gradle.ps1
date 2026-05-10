#Requires -Version 5.1
# fix-gradle.ps1 - Gradle cache lock/corruption fixer
# Fixes "Could not move temporary workspace to immutable location" errors
# by moving GRADLE_USER_HOME to a clean path without permission issues.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File fix-gradle.ps1
#   powershell -ExecutionPolicy Bypass -File fix-gradle.ps1 -ThenBuild
#   powershell -ExecutionPolicy Bypass -File fix-gradle.ps1 -GradlePath "E:\MyGradle"

param(
    [string]$GradlePath = "D:\GradleCache",
    [switch]$ThenBuild
)

$ErrorActionPreference = "Continue"
$oldGradleHome = "$env:USERPROFILE\.gradle"

Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Gradle Cache Lock Fixer" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# Step 1: Kill all Gradle/Java daemon processes
# ============================================================
Write-Host "[1/6] Stopping Gradle and Java daemons..." -ForegroundColor White

$processNames = @("java", "javaw", "gradle", "kotlin-daemon")
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

if ($killed -gt 0) {
    Write-Host "       Killed $killed process(es). Waiting 3 seconds..." -ForegroundColor Green
    Start-Sleep -Seconds 3
} else {
    Write-Host "       No running processes found." -ForegroundColor DarkGray
}

# ============================================================
# Step 2: Create new Gradle home directory
# ============================================================
Write-Host "[2/6] Setting up new Gradle home: $GradlePath ..." -ForegroundColor White

if (-not (Test-Path $GradlePath)) {
    try {
        New-Item -ItemType Directory -Path $GradlePath -Force | Out-Null
        Write-Host "       Created: $GradlePath" -ForegroundColor Green
    } catch {
        Write-Host "       [FAIL] Cannot create $GradlePath : $_" -ForegroundColor Red
        Write-Host "       Try a different path: -GradlePath `"C:\GradleCache`"" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "       Already exists: $GradlePath" -ForegroundColor DarkGray
}

# Verify the path is writable
$testFile = "$GradlePath\.write-test"
try {
    [System.IO.File]::WriteAllText($testFile, "test")
    Remove-Item $testFile -Force
    Write-Host "       Path is writable." -ForegroundColor Green
} catch {
    Write-Host "       [FAIL] Cannot write to $GradlePath" -ForegroundColor Red
    exit 1
}

# ============================================================
# Step 3: Set GRADLE_USER_HOME environment variable
# ============================================================
Write-Host "[3/6] Setting GRADLE_USER_HOME environment variable..." -ForegroundColor White

$currentGradleHome = [Environment]::GetEnvironmentVariable("GRADLE_USER_HOME", "User")

# Set for current session
$env:GRADLE_USER_HOME = $GradlePath

# Set permanently (User level)
[Environment]::SetEnvironmentVariable("GRADLE_USER_HOME", $GradlePath, "User")

if ($currentGradleHome -and $currentGradleHome -ne $GradlePath) {
    Write-Host "       Changed: $currentGradleHome -> $GradlePath" -ForegroundColor Green
} elseif (-not $currentGradleHome) {
    Write-Host "       Set: GRADLE_USER_HOME = $GradlePath" -ForegroundColor Green
} else {
    Write-Host "       Already set to $GradlePath" -ForegroundColor DarkGray
}

# Also write to Git Bash profile
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$gradleUnix = $GradlePath -replace "\\","/"
if ($gradleUnix -match "^([A-Za-z]):(.*)") {
    $gradleUnix = "/" + $Matches[1].ToLower() + $Matches[2]
}
$exportLine = "export GRADLE_USER_HOME=`"$gradleUnix`""

foreach ($rcFile in @("$env:USERPROFILE\.bashrc", "$env:USERPROFILE\.bash_profile")) {
    $rcExists = Test-Path $rcFile
    $alreadyHas = $false
    if ($rcExists) {
        $alreadyHas = Select-String -Path $rcFile -Pattern "GRADLE_USER_HOME" -Quiet
    }
    if (-not $alreadyHas) {
        if (-not $rcExists) {
            [System.IO.File]::WriteAllText($rcFile, "", $utf8NoBom)
        }
        $content = [System.IO.File]::ReadAllText($rcFile, $utf8NoBom)
        $addition = "`n# Gradle cache relocated by fix-gradle.ps1`n$exportLine`n"
        [System.IO.File]::WriteAllText($rcFile, $content + $addition, $utf8NoBom)
        $rcName = Split-Path -Leaf $rcFile
        Write-Host "       Added to ~/$rcName" -ForegroundColor Green
    }
}

# ============================================================
# Step 4: Migrate essential config from old .gradle (optional)
# ============================================================
Write-Host "[4/6] Migrating settings from old .gradle ..." -ForegroundColor White

$migrated = 0
if (Test-Path $oldGradleHome) {
    # Migrate gradle.properties if exists
    $oldProps = "$oldGradleHome\gradle.properties"
    $newProps = "$GradlePath\gradle.properties"
    if ((Test-Path $oldProps) -and -not (Test-Path $newProps)) {
        Copy-Item $oldProps $newProps -Force
        $migrated++
        Write-Host "       Migrated: gradle.properties" -ForegroundColor Green
    }

    # Migrate init scripts if exist
    $oldInit = "$oldGradleHome\init.d"
    $newInit = "$GradlePath\init.d"
    if ((Test-Path $oldInit) -and -not (Test-Path $newInit)) {
        Copy-Item $oldInit $newInit -Recurse -Force
        $migrated++
        Write-Host "       Migrated: init.d/" -ForegroundColor Green
    }
}

if ($migrated -eq 0) {
    Write-Host "       Nothing to migrate." -ForegroundColor DarkGray
}

# ============================================================
# Step 5: Clean corrupted cache (both old AND new paths)
# ============================================================
Write-Host "[5/6] Cleaning Gradle caches..." -ForegroundColor White

$cleanedItems = 0

# Clean transforms and lock files from BOTH old and new Gradle homes
foreach ($gradleDir in @($oldGradleHome, $GradlePath)) {
    if (-not (Test-Path "$gradleDir\caches")) { continue }

    # Delete transforms directories (the source of "could not move" errors)
    Get-ChildItem "$gradleDir\caches\*\transforms" -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        $retries = 3
        for ($i = 0; $i -lt $retries; $i++) {
            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            if (-not (Test-Path $_.FullName)) { break }
            Start-Sleep -Seconds 2
        }
        if (-not (Test-Path $_.FullName)) {
            $cleanedItems++
            Write-Host "       Deleted: $($_.FullName)" -ForegroundColor Green
        } else {
            Write-Host "       [WARN] Could not delete: $($_.FullName)" -ForegroundColor Yellow
        }
    }

    # Delete lock files
    Get-ChildItem "$gradleDir\caches" -Filter "*.lock" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
        $cleanedItems++
    }

    # Delete file-lock directories
    Get-ChildItem "$gradleDir\caches" -Filter "file-lock" -Directory -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        $cleanedItems++
    }
}

# Clean project build cache
foreach ($dir in @(".\build", ".\android\.gradle", ".\.dart_tool")) {
    if (Test-Path $dir) {
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        $cleanedItems++
    }
}

Write-Host "       Cleaned $cleanedItems item(s)." -ForegroundColor Green

# ============================================================
# Step 6: Verify
# ============================================================
Write-Host "[6/6] Verifying..." -ForegroundColor White

$verified = $true
$envCheck = [Environment]::GetEnvironmentVariable("GRADLE_USER_HOME", "User")
if ($envCheck -eq $GradlePath) {
    Write-Host "       GRADLE_USER_HOME = $envCheck" -ForegroundColor Green
} else {
    Write-Host "       [WARN] GRADLE_USER_HOME not set correctly" -ForegroundColor Yellow
    $verified = $false
}

if (Test-Path $GradlePath) {
    Write-Host "       Directory exists: $GradlePath" -ForegroundColor Green
} else {
    Write-Host "       [WARN] Directory missing" -ForegroundColor Yellow
    $verified = $false
}

Write-Host "       Session GRADLE_USER_HOME = $env:GRADLE_USER_HOME" -ForegroundColor Green

# ============================================================
# Summary
# ============================================================
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
if ($verified) {
    Write-Host "  [OK] Fix complete." -ForegroundColor Green
} else {
    Write-Host "  [WARN] Fix applied with warnings." -ForegroundColor Yellow
}
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  What changed:" -ForegroundColor White
Write-Host "    GRADLE_USER_HOME = $GradlePath" -ForegroundColor Cyan
Write-Host "    (was: $oldGradleHome)" -ForegroundColor DarkGray
Write-Host ""
Write-Host "  Gradle will now use $GradlePath" -ForegroundColor White
Write-Host "  instead of $oldGradleHome" -ForegroundColor White
Write-Host "  This avoids file-lock issues on the User profile path." -ForegroundColor DarkGray
Write-Host ""

if ($ThenBuild) {
    Write-Host "  Building APK..." -ForegroundColor White
    Write-Host ""
    Write-Host "  [1/3] flutter clean" -ForegroundColor Cyan
    & flutter clean
    Write-Host "  [2/3] flutter pub get" -ForegroundColor Cyan
    & flutter pub get
    Write-Host "  [3/3] flutter build apk --release" -ForegroundColor Cyan
    & flutter build apk --release
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "  [FAIL] Build failed (exit code $LASTEXITCODE)." -ForegroundColor Red
        Write-Host "  If you see 'Could not move temporary workspace' again," -ForegroundColor Yellow
        Write-Host "  try running this script once more — a daemon may have" -ForegroundColor Yellow
        Write-Host "  re-created lock files during the build." -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "  [OK] APK build succeeded!" -ForegroundColor Green
    }
} else {
    Write-Host "  Next steps:" -ForegroundColor White
    Write-Host "    flutter clean" -ForegroundColor Green
    Write-Host "    flutter pub get" -ForegroundColor Green
    Write-Host "    flutter build apk" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Or run with auto-build:" -ForegroundColor DarkGray
    Write-Host "    powershell -ExecutionPolicy Bypass -File fix-gradle.ps1 -ThenBuild" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Git Bash users:" -ForegroundColor White
    Write-Host "    source ~/.bash_profile" -ForegroundColor Green
}
Write-Host ""
