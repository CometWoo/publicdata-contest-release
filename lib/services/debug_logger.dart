import 'package:flutter/foundation.dart';

/// [디버그 구조] 3단계 디버그 로깅 시스템
/// Level 1: 실행 확인 (앱 시작/중단)
/// Level 2: API 통신 확인 (요청 URL, 상태코드, 소요시간)
/// Level 3: 에러 추적 (컴포넌트 > 함수: 에러 메시지 + 스택 트레이스)
class DebugLogger {
  static final List<String> _logs = [];
  static const int _maxLogs = 50;

  /// 외부에서 로그 리스트를 읽기 위한 getter
  static List<String> get logs => List.unmodifiable(_logs);

  /// [Level 1] 앱 실행 상태 로깅
  static void logAppStart({required String target, required int port}) {
    final msg = '✅ App running on http://localhost:$port ($target)';
    _print(msg, level: 'APP');
  }

  static void logAppEvent(String message) {
    _print(message, level: 'APP');
  }

  /// [Level 2] API 통신 로깅 — 요청 URL, 응답 상태코드, 소요시간
  static void logApiRequest({
    required String method,
    required String endpoint,
    required int statusCode,
    required Duration duration,
    String? error,
  }) {
    final statusText = _statusText(statusCode);
    final ms = duration.inMilliseconds;

    if (error != null) {
      _print('$method $endpoint → FAILED ($ms ms) $error', level: 'API');
    } else {
      _print('$method $endpoint → $statusCode $statusText ($ms ms)', level: 'API');
    }
  }

  /// [Level 2] WebSocket 통신 로깅
  static void logWsEvent(String event, {String? detail}) {
    final detailStr = detail != null ? ' | $detail' : '';
    _print('$event$detailStr', level: 'WS');
  }

  /// [Level 3] 에러 추적 — 컴포넌트명 > 함수명: 에러 메시지
  static void logError({
    required String component,
    required String function,
    required Object error,
    StackTrace? stackTrace,
  }) {
    final msg = '$component > $function: $error';
    _print(msg, level: 'ERROR');

    if (stackTrace != null && kDebugMode) {
      debugPrint('[STACK] ${stackTrace.toString().split('\n').take(5).join('\n')}');
    }
  }

  /// 내부 출력 및 저장
  static void _print(String message, {required String level}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    final formatted = '[$level] $timestamp $message';

    debugPrint(formatted);
    _logs.add(formatted);
    if (_logs.length > _maxLogs) _logs.removeAt(0);
  }

  static String _statusText(int code) {
    switch (code) {
      case 200: return 'OK';
      case 201: return 'Created';
      case 204: return 'No Content';
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 500: return 'Internal Server Error';
      default: return '';
    }
  }

  static void clear() => _logs.clear();
}
