import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'debug_logger.dart';

// [개선] HTTP API 호출을 별도 서비스로 분리
class ApiService {
  // [개선] userId를 외부에서 주입받도록 변경 — 하드코딩 제거
  final String userId;

  // [수정] API 요청 타임아웃 설정
  static const Duration _requestTimeout = Duration(seconds: 15);

  ApiService({required this.userId});

  Future<ApiResult<List<dynamic>>> fetchJobs() async {
    final endpoint = '/recommend/$userId';
    final stopwatch = Stopwatch()..start();

    DebugLogger.logAppEvent('[API] 요청: POST ${AppConfig.serverUrl}$endpoint');

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.serverUrl}$endpoint'),
      ).timeout(_requestTimeout);
      stopwatch.stop();

      // [디버그 Level 2] API 통신 로깅
      DebugLogger.logApiRequest(
        method: 'POST',
        endpoint: endpoint,
        statusCode: res.statusCode,
        duration: stopwatch.elapsed,
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        // [개선] 응답 타입 검증 강화
        if (data is! Map<String, dynamic>) {
          return ApiResult.error('Invalid response format');
        }

        final recommendations = data['recommendations'];
        if (recommendations != null &&
            recommendations is List &&
            recommendations.isNotEmpty) {
          return ApiResult.success(recommendations);
        }

        final message = data['message']?.toString();
        if (message != null) {
          return ApiResult.error(message);
        }

        return ApiResult.success([]);
      }

      return ApiResult.error('HTTP Error: ${res.statusCode}');
    } catch (e, stackTrace) {
      stopwatch.stop();
      // [디버그 Level 2] API 실패 로깅
      DebugLogger.logApiRequest(
        method: 'POST',
        endpoint: endpoint,
        statusCode: 0,
        duration: stopwatch.elapsed,
        error: e.toString(),
      );
      // [디버그 Level 3] 에러 추적
      DebugLogger.logError(
        component: 'ApiService',
        function: 'fetchJobs',
        error: e,
        stackTrace: stackTrace,
      );
      return ApiResult.error('Network Error: $e');
    }
  }

  Future<ApiResult<bool>> resetResume() async {
    final endpoint = '/resume/$userId';
    final stopwatch = Stopwatch()..start();

    DebugLogger.logAppEvent('[API] 요청: DELETE ${AppConfig.serverUrl}$endpoint');

    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.serverUrl}$endpoint'),
      ).timeout(_requestTimeout);
      stopwatch.stop();

      // [디버그 Level 2] API 통신 로깅
      DebugLogger.logApiRequest(
        method: 'DELETE',
        endpoint: endpoint,
        statusCode: res.statusCode,
        duration: stopwatch.elapsed,
      );

      if (res.statusCode == 200) {
        return ApiResult.success(true);
      }

      return ApiResult.error('HTTP Error: ${res.statusCode}');
    } catch (e, stackTrace) {
      stopwatch.stop();
      DebugLogger.logApiRequest(
        method: 'DELETE',
        endpoint: endpoint,
        statusCode: 0,
        duration: stopwatch.elapsed,
        error: e.toString(),
      );
      // [디버그 Level 3] 에러 추적
      DebugLogger.logError(
        component: 'ApiService',
        function: 'resetResume',
        error: e,
        stackTrace: stackTrace,
      );
      return ApiResult.error('Network Error: $e');
    }
  }
}

// [개선] API 결과를 타입 안전하게 전달하는 래퍼
class ApiResult<T> {
  final T? data;
  final String? errorMessage;
  final bool isSuccess;

  ApiResult.success(this.data)
      : isSuccess = true,
        errorMessage = null;

  ApiResult.error(this.errorMessage)
      : isSuccess = false,
        data = null;
}
