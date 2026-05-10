# Silver Voice - 환경 설치 및 검증 스크립트 (Windows PowerShell)
# 실행: powershell -ExecutionPolicy Bypass -File setup.ps1

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Silver Voice - Environment Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$hasError = $false

# ─── Step 1: Flutter SDK ───
Write-Host "[1/6] Flutter SDK 확인..." -NoNewline
$flutterVersion = flutter --version 2>&1 | Out-String
if ($LASTEXITCODE -eq 0 -or $flutterVersion -match "Flutter") {
    $ver = ($flutterVersion -split "`n")[0].Trim()
    Write-Host " ✅ $ver" -ForegroundColor Green
} else {
    Write-Host " ❌ Flutter가 설치되어 있지 않습니다." -ForegroundColor Red
    Write-Host "    설치: https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    $hasError = $true
}

# ─── Step 2: Dart SDK ───
Write-Host "[2/6] Dart SDK 확인..." -NoNewline
$dartVersion = dart --version 2>&1 | Out-String
if ($LASTEXITCODE -eq 0 -or $dartVersion -match "Dart") {
    Write-Host " ✅ $($dartVersion.Trim())" -ForegroundColor Green

    # 버전 체크 (>=3.2.0 필요)
    if ($dartVersion -match "(\d+)\.(\d+)\.(\d+)") {
        $major = [int]$Matches[1]; $minor = [int]$Matches[2]
        if ($major -lt 3 -or ($major -eq 3 -and $minor -lt 2)) {
            Write-Host "    ⚠️ 경고: Dart 3.2.0 이상이 필요합니다. 현재: $($Matches[0])" -ForegroundColor Yellow
        }
    }
} else {
    Write-Host " ❌ Dart SDK가 설치되어 있지 않습니다." -ForegroundColor Red
    $hasError = $true
}

# ─── Step 3: Chrome (Web 빌드용) ───
Write-Host "[3/6] Chrome 브라우저 확인..." -NoNewline
$chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
$chromePath2 = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
if ((Test-Path $chromePath) -or (Test-Path $chromePath2)) {
    Write-Host " ✅ Chrome 설치됨" -ForegroundColor Green
} else {
    Write-Host " ⚠️ Chrome 미설치 — flutter run -d chrome 사용 불가" -ForegroundColor Yellow
}

# ─── Step 4: Flutter Web 지원 활성화 ───
Write-Host "[4/6] Flutter Web 지원 확인..." -NoNewline
$devices = flutter devices 2>&1 | Out-String
if ($devices -match "Chrome|chrome|Web") {
    Write-Host " ✅ Web 디바이스 사용 가능" -ForegroundColor Green
} else {
    Write-Host " ⚠️ Web 디바이스 없음. 활성화 시도 중..." -ForegroundColor Yellow
    flutter config --enable-web 2>&1 | Out-Null
}

# ─── Step 5: 의존성 설치 ───
Write-Host "[5/6] Flutter 패키지 의존성 설치..." -NoNewline
$pubResult = flutter pub get 2>&1 | Out-String
if ($pubResult -match "Got dependencies" -or $pubResult -match "Resolving") {
    Write-Host " ✅ 의존성 설치 완료" -ForegroundColor Green
} else {
    Write-Host " ❌ 의존성 설치 실패" -ForegroundColor Red
    Write-Host $pubResult -ForegroundColor Red
    $hasError = $true
}

# ─── Step 6: 정적 분석 ───
Write-Host "[6/6] Dart 정적 분석..." -NoNewline
$analyzeResult = flutter analyze --no-pub 2>&1 | Out-String
if ($analyzeResult -match "No issues found" -or $analyzeResult -match "0 issues") {
    Write-Host " ✅ 분석 이슈 없음" -ForegroundColor Green
} elseif ($analyzeResult -match "error") {
    Write-Host " ❌ 분석 에러 발견" -ForegroundColor Red
    Write-Host $analyzeResult -ForegroundColor Yellow
    $hasError = $true
} else {
    Write-Host " ⚠️ 경고 있음 (빌드는 가능)" -ForegroundColor Yellow
    Write-Host $analyzeResult -ForegroundColor Yellow
}

# ─── 요약 ───
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
if ($hasError) {
    Write-Host "  ❌ 일부 단계가 실패했습니다." -ForegroundColor Red
    Write-Host "  위의 오류를 해결한 후 다시 실행하세요." -ForegroundColor Yellow
} else {
    Write-Host "  ✅ 환경 준비 완료!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  실행 명령어:" -ForegroundColor White
    Write-Host "    flutter run -d chrome        # 웹 브라우저" -ForegroundColor Cyan
    Write-Host "    flutter run -d windows       # Windows 데스크톱" -ForegroundColor Cyan
    Write-Host "    flutter run -d <device_id>   # 연결된 모바일" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  디버그 서버 포트:" -ForegroundColor White
    Write-Host "    http://localhost:PORT (실행 시 콘솔에 표시)" -ForegroundColor Cyan
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
