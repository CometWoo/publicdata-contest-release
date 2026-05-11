# Contributing Guide

Silver Voice 프로젝트에 기여해 주셔서 감사합니다.

## 개발 환경 설정

### 필수 도구

| 도구 | 버전 | 확인 명령어 |
|------|------|-------------|
| Flutter SDK | 3.x 이상 | `flutter --version` |
| Dart SDK | 3.2.0 이상 | `dart --version` |
| Android Studio | 최신 | — |
| Java | 17 | `java -version` |
| Git | 최신 | `git --version` |

### 초기 설정

```bash
git clone https://github.com/CometWoo/publicdata-contest-release.git
cd publicdata-contest-release
flutter pub get
```

## 브랜치 전략

```
main              ← 안정 버전 (직접 push 금지)
 └── feature/xxx  ← 기능 개발
 └── fix/xxx      ← 버그 수정
 └── docs/xxx     ← 문서 작업
```

### 브랜치 이름 규칙

```
feature/이력서-편집-기능
fix/홈-화면-width-잘림
docs/readme-업데이트
```

## 작업 흐름

### 1. 이슈 확인 또는 생성

작업 전 GitHub Issues에서 관련 이슈를 확인하거나 새로 생성합니다.

### 2. 브랜치 생성

```bash
git checkout main
git pull origin main
git checkout -b feature/기능-이름
```

### 3. 개발

```bash
# 실행
flutter run --dart-define=SERVER_URL=https://... --dart-define=WS_URL=wss://...

# 린트 확인 (커밋 전 필수)
flutter analyze
```

### 4. 커밋

```bash
git add 변경된-파일들
git commit -m "feat: 커밋 메시지"
```

#### 커밋 메시지 규칙

```
<타입>: <설명>

[본문 (선택)]
```

| 타입 | 용도 |
|------|------|
| `feat` | 새 기능 추가 |
| `fix` | 버그 수정 |
| `refactor` | 코드 개선 (기능 변경 없음) |
| `docs` | 문서 변경 |
| `style` | 코드 포맷팅 |
| `test` | 테스트 추가/수정 |

예시:
```
feat: 이력서 관리 페이지 텍스트 편집 기능 추가
fix: 홈 화면 width 1/4 잘림 현상 수정
refactor: API 응답 에러 처리 분리
```

### 5. PR 생성

```bash
git push origin feature/기능-이름
```

GitHub에서 Pull Request를 생성합니다.

#### PR 템플릿

```markdown
## 변경 사항
- 무엇을 왜 변경했는지

## 테스트
- [ ] flutter analyze 통과
- [ ] 실기기에서 동작 확인
- [ ] 기존 기능 정상 작동 확인
```

## 코드 컨벤션

### 파일 구조

| 디렉토리 | 역할 | 예시 |
|----------|------|------|
| `lib/screens/` | 화면 위젯 (탭/페이지) | `home_tab.dart` |
| `lib/widgets/` | 재사용 가능한 공통 위젯 | `interactive_card.dart` |
| `lib/services/` | 비즈니스 로직 (API, WS, 오디오) | `api_service.dart` |
| `lib/models/` | 데이터 모델, enum | `ws_status.dart` |
| `lib/config/` | 설정 상수 | `app_config.dart` |

### 코딩 규칙

1. **시니어 접근성 필수**
   - 최소 터치 영역: 48x48dp (`AppConfig.minTouchTarget`)
   - 최소 폰트 크기: 14px (`AppConfig.fontSizeSmall`)
   - 모든 인터랙티브 요소에 `Semantics` 위젯 적용

2. **한글 사용**
   - 모든 사용자 대면 텍스트는 한국어
   - 코드 주석은 한국어 또는 영어 (혼용 가능)

3. **주석 태그**
   ```dart
   // [수정] 변경 이유
   // [추가] 새로 추가한 코드의 목적
   // [개선] 기존 코드 개선 내용
   ```

4. **상수 관리**
   - UI 수치는 `AppConfig`에 중앙 관리
   - 매직 넘버 직접 사용 금지

5. **null 안전성**
   - `?.` 연산자 적극 사용
   - API 응답 필드는 항상 null 체크

### 린트

`flutter analyze`가 에러 없이 통과해야 PR을 올릴 수 있습니다.

```bash
flutter analyze
```

## 주의사항

- `app_config.dart`에 서버 URL을 하드코딩하지 마세요. `--dart-define`으로 주입합니다.
- `.env` 파일과 API 키를 절대 커밋하지 마세요.
- `android/`, `ios/`, `windows/`, `linux/`, `macos/` 하위의 자동 생성 파일 변경은 별도 커밋으로 분리해 주세요.
