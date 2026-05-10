import 'package:flutter/foundation.dart';

class AppConfig {
  static const String serverUrl = String.fromEnvironment('SERVER_URL');
  static const String wsUrl = String.fromEnvironment('WS_URL');

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
