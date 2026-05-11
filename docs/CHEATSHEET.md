# Silver Voice 개발 치트시트

복사해서 바로 쓸 수 있는 명령어 모음입니다.

---

## 1. Flutter 기본

```powershell
# 환경 확인
flutter doctor -v

# 에뮬레이터 실행
flutter emulators --launch Medium_Phone

# 의존성 설치
flutter pub get

# 정적 분석 (린트)
flutter analyze

# 빌드 캐시 정리
flutter clean
```

---

## 2. 앱 실행

### 서버 URL 지정 실행 (필수)

```powershell
flutter run --dart-define=SERVER_URL=https://서버주소:8000/ --dart-define=WS_URL=wss://서버주소:8000/voice/ws
```

### 실제 예시 (RunPod)

```powershell
flutter run --dart-define=SERVER_URL=https://cm85jv2aud1899-8000.proxy.runpod.net/ --dart-define=WS_URL=wss://cm85jv2aud1899-8000.proxy.runpod.net/voice/ws
```

### .env 설정 (공공데이터 API 키)

```powershell
cp .env.example .env
# .env 파일을 열어서 아래 입력:
# PUBLIC_DATA_API_KEY=b989a98fd4bd839b1a1e8f8f3fe5dd428629d05a4b3d1ba3d13d0317e5d5368f
```

### 참고: --dart-define vs .env 차이

| 방식 | 용도 | 시점 |
|------|------|------|
| `--dart-define` | 서버 URL (SERVER_URL, WS_URL) | 컴파일 타임 (빌드할 때 고정) |
| `.env` 파일 | 공공데이터 API 키 | 런타임 (앱 실행할 때 읽음) |

서버 URL을 바꾸려면 앱을 다시 빌드해야 합니다.

---

## 3. Git 기본 흐름

```
git add    →  "이 파일을 추적해줘"  (스테이징)
git commit →  "이 변경을 기록해줘"  (로컬 저장)
git push   →  "GitHub에 올려줘"    (원격 업로드)
```

### 파일 수정 후 GitHub에 올리기

```powershell
cd C:\portable\publicdata-contest-release

# 1. 변경 파일 확인
git status

# 2. 파일 스테이징
git add 파일경로

# 3. 커밋
git commit -m "feat: 변경 내용 설명"

# 4. GitHub에 푸시
git push origin main
```

---

## 4. Claude Code 워크트리 → 로컬 병합 → GitHub

Claude Code가 작업한 코드를 내가 확인한 뒤 GitHub에 올리는 방법입니다.

### 방법 A: 로컬 워크트리 브랜치를 직접 머지

워크트리가 내 PC에 있을 때 사용합니다.

```powershell
# Step 1 — 본체 main으로 이동
cd C:\portable\publicdata-contest-release

# Step 2 — 자동생성 파일 충돌 방지 (Flutter가 건드린 파일들)
git stash

# Step 3 — 워크트리 브랜치를 main에 병합
git merge claude/friendly-sutherland-9430df

# Step 4 — 에디터에서 코드 확인

# Step 5 — 확인 후 GitHub에 푸시
git push origin main

# Step 6 — 임시 저장 복원
git stash pop

# Step 7 — (선택) 워크트리 정리
git worktree remove .claude\worktrees\friendly-sutherland-9430df
git branch -d claude/friendly-sutherland-9430df
```

### 방법 B: GitHub 원격 브랜치에서 가져와서 머지

다른 PC이거나 워크트리가 없을 때 사용합니다.

```powershell
# Step 1 — 프로젝트로 이동
cd C:\portable\publicdata-contest-release

# Step 2 — 자동생성 파일 충돌 방지
git stash

# Step 3 — GitHub에서 최신 정보 가져오기 (병합은 안 함)
git fetch origin

# Step 4 — 원격 브랜치를 main에 병합
git merge origin/claude/friendly-sutherland-9430df

# Step 5 — 에디터에서 코드 확인

# Step 6 — 확인 후 GitHub에 푸시
git push origin main

# Step 7 — 임시 저장 복원
git stash pop
```

### 방법 A vs B 차이

| | A (로컬 머지) | B (원격 머지) |
|---|---|---|
| 머지 대상 | `claude/브랜치명` | `origin/claude/브랜치명` |
| 출처 | 내 PC의 워크트리 | GitHub 원격 |
| `git fetch` | 불필요 | 필요 |
| 워크트리 필요 | O | X |

---

## 5. GitHub에서 머지된 내용 가져오기 (PR 머지 후)

Claude Code가 PR을 만들고 GitHub에서 이미 머지된 경우:

```powershell
cd C:\portable\publicdata-contest-release
git stash
git pull origin main
git stash pop
```

---

## 6. APK 빌드 및 배포

### 빌드 준비

```powershell
# Java/Gradle 프로세스 정리 (메모리 확보)
taskkill /F /IM java.exe 2>$null
```

### APK 빌드

```powershell
cd C:\portable\publicdata-contest-release
flutter clean
flutter pub get
flutter build apk --release --dart-define=SERVER_URL=https://서버주소:8000/ --dart-define=WS_URL=wss://서버주소:8000/voice/ws
```

생성 위치:
```
build\app\outputs\flutter-apk\app-release.apk
```

### GitHub Release 배포

```powershell
gh release create v1.1.0 "build\app\outputs\flutter-apk\app-release.apk" --title "Silver Voice v1.1.0" --notes "변경 내용 설명"
```

배포 확인:
```
https://github.com/CometWoo/publicdata-contest-release/releases
```

---

## 7. 트러블슈팅

### Gradle 캐시 손상 (Kotlin 버전 충돌 등)

```powershell
# Gradle 캐시 전체 삭제 (다음 빌드 시 자동 재다운로드)
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\caches" -ErrorAction SilentlyContinue
flutter clean
flutter pub get
```

### git pull/merge 시 "local changes would be overwritten" 에러

```powershell
# Flutter 자동생성 파일 충돌 — stash로 해결
git stash
git pull origin main
git stash pop
```

### git push 시 "non-fast-forward" 에러

```powershell
# 로컬이 원격보다 뒤처진 상태 — pull 먼저
git stash
git pull origin main
git stash pop
git push origin main
```

### 앱 빌드 시 메모리 부족

```powershell
# 1. 다른 프로그램 종료
# 2. Gradle 힙 메모리 확인
#    android/gradle.properties 에서:
#    org.gradle.jvmargs=-Xmx2G
# 3. 재시도
flutter clean
flutter pub get
flutter run
```
