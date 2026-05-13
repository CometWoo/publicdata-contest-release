# Silver Voice
<img width="768" height="432" alt="Image" src="https://github.com/user-attachments/assets/3af4204f-15b6-410e-98a7-c9e4dcf078ba" />

한국 시니어를 위한 음성 기반 이력서 작성 앱입니다. 마이크 버튼을 꾹 누르고 말씀하시면, AI가 대화를 통해 이력서를 자동으로 완성합니다.

## UI
<img width="220" height="438" alt="Image" src="https://github.com/user-attachments/assets/2adf6dfa-fdb8-437a-a379-acb08cd2e28b" />
<img width="220" height="438" alt="Image" src="https://github.com/user-attachments/assets/db227d1f-e8e3-42cd-896a-c55c09c2afcb" />
<img width="220" height="438" alt="Image" src="https://github.com/user-attachments/assets/44bcf8dd-233e-45ef-ad0f-09d7331df6f9" />
<img width="220" height="438" alt="Image" src="https://github.com/user-attachments/assets/0d0c01dd-6a90-413c-9b06-0ade28bde406" />

## 주요 기능

| 기능 | 설명 |
|------|------|
| 음성 이력서 작성 | 마이크를 꾹 누르고 대화하면 AI가 이력서를 자동 채움 |
| 이력서 직접 편집 | 음성 인식 오류를 텍스트로 직접 수정 |
| AI 일자리 추천 | 완성된 이력서 기반으로 적합한 일자리 매칭 |
| 공공데이터 연동 | 한국노인인력개발원 100세누리 채용공고 실시간 조회 |

## 기술 스택

- **프레임워크**: Flutter 3.x (Dart SDK ≥ 3.2.0)
- **백엔드 통신**: WebSocket (실시간 음성 대화) + REST API (일자리 추천)
- **음성**: `record` (마이크 녹음) + `flutter_tts` (로컬 TTS) + `audioplayers` (서버 TTS)
- **공공데이터**: 한국노인인력개발원 100세누리 구인정보 OpenAPI (XML)
- **Android**: Gradle 8.3, Kotlin 1.9.25, Java 17

## 사전 요구사항

- Flutter SDK 3.x 이상
- Android Studio 또는 VS Code (Flutter 확장 설치)
- Android 기기 또는 에뮬레이터
- 백엔드 서버 실행 중 ([publicdata-contest](https://github.com/clapppp/publicdata-contest))

## 설치 및 실행

### 1. 프로젝트 클론

```bash
git clone https://github.com/CometWoo/publicdata-contest-release.git
cd publicdata-contest-release
```

### 2. 의존성 설치

```bash
flutter pub get
```

### 3. 환경변수 설정

`.env` 파일을 프로젝트 루트에 생성합니다:

```env
PUBLIC_DATA_API_KEY=발급받은_공공데이터_API_키
```

공공데이터 API 키는 [data.go.kr](https://www.data.go.kr/)에서 "한국노인인력개발원_100세누리구인정보" 활용 신청 후 발급받습니다.

### 4. 실행

```bash
# 백엔드 서버 URL을 지정하여 실행 (필수)
flutter run \
  --dart-define=SERVER_URL=https://your-server-url:8000/ \
  --dart-define=WS_URL=wss://your-server-url:8000/voice/ws

# 사용자 ID도 지정하려면
flutter run \
  --dart-define=SERVER_URL=https://your-server-url:8000/ \
  --dart-define=WS_URL=wss://your-server-url:8000/voice/ws \
  --dart-define=USER_ID=my-user-id
```

### 5. 릴리스 빌드

```bash
flutter build apk \
  --dart-define=SERVER_URL=https://your-server-url:8000/ \
  --dart-define=WS_URL=wss://your-server-url:8000/voice/ws
```

## 환경변수 목록

### `--dart-define` (빌드 시 주입)

| 변수 | 필수 | 설명 | 예시 |
|------|------|------|------|
| `SERVER_URL` | O | 백엔드 REST API 주소 | `https://xxx.proxy.runpod.net/` |
| `WS_URL` | O | 백엔드 WebSocket 주소 | `wss://xxx.proxy.runpod.net/voice/ws` |
| `USER_ID` | X | 사용자 식별자 (기본값: `test-user-001`) | `user-hong` |

### `.env` 파일

| 변수 | 필수 | 설명 |
|------|------|------|
| `PUBLIC_DATA_API_KEY` | O | 공공데이터 포털 API 키 (100세누리 구인정보) |

## 프로젝트 구조

```
lib/
 ├── main.dart                    # 앱 진입점, 상태 관리
 ├── config/
 │   └── app_config.dart          # 환경변수, UI 상수
 ├── models/
 │   └── ws_status.dart           # WebSocket 연결 상태 enum
 ├── screens/
 │   ├── home_tab.dart            # 홈 (음성 녹음 화면)
 │   ├── jobs_tab.dart            # AI 추천 일자리 목록
 │   ├── job_detail_screen.dart   # 일자리 상세 + 공공데이터
 │   ├── resume_tab.dart          # 이력서 관리 (편집 가능)
 │   └── mypage_tab.dart          # 마이페이지
 ├── services/
 │   ├── websocket_service.dart   # WebSocket 연결 관리
 │   ├── audio_service.dart       # 마이크 녹음 + 오디오 재생
 │   ├── api_service.dart         # REST API 호출
 │   ├── public_data_service.dart # 공공데이터 API 연동
 │   ├── tts_service.dart         # 로컬 TTS 엔진
 │   ├── debug_logger.dart        # 3단계 구조 로깅
 │   └── file_helper_*.dart       # 플랫폼별 파일 I/O
 └── widgets/
     ├── mic_button.dart          # 마이크 버튼 (햅틱+애니메이션)
     ├── interactive_card.dart    # 토스 스타일 터치 피드백 카드
     ├── accessible_button.dart   # 시니어 접근성 버튼
     └── debug_panel.dart         # 인앱 디버그 콘솔
```

## 디버그 모드

앱 실행 중 우측 상단 벨 아이콘을 탭하면 디버그 패널이 열립니다:
- WebSocket 연결 상태
- API 호출 로그 (메서드, 상태코드, 소요시간)
- 에러 스택트레이스

## 린트

```bash
flutter analyze
```

설정 파일: `package:flutter_lints/flutter.yaml`
