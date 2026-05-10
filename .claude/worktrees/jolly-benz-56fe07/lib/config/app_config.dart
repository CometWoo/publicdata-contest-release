// [개선] 하드코딩된 서버 URL과 userId를 config로 분리하여 보안 및 유지보수성 향상
import 'package:flutter/foundation.dart';

class AppConfig {
  // [개선] 환경변수(--dart-define)에서 주입받도록 변경. 소스코드에 URL 노출 방지
  // [수정] RunPod 인스턴스 호스트 갱신 (0oof8muhxkpy97 → 7xnxs8gfnhz39w)
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'https://7xnxs8gfnhz39w-8000.proxy.runpod.net/',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://7xnxs8gfnhz39w-8000.proxy.runpod.net/voice/ws',
  );

  // [개선] 시니어 친화적 UI 상수 — 최소 폰트 크기, 터치 영역 등을 중앙 관리
  static const double fontSizeTitle = 26.0;
  static const double fontSizeBody = 18.0;
  static const double fontSizeCaption = 16.0;
  static const double fontSizeSmall = 14.0;
  static const double minTouchTarget = 48.0;

  // [개선] 재연결 관련 설정
  static const int maxReconnectAttempts = 5;
  static const Duration reconnectBaseDelay = Duration(seconds: 2);

  static bool get isDebugBuild => kDebugMode;
}
