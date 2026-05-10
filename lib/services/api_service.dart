import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'debug_logger.dart';

// [개선] HTTP API 호출을 별도 서비스로 분리
class ApiService {
  // [개선] userId를 외부에서 주입받도록 변경 — 하드코딩 제거
  final String userId;

  ApiService({required this.userId});

  Future<ApiResult<List<dynamic>>> fetchJobs() async {
    final endpoint = '/recommend/$userId';
    final stopwatch = Stopwatch()..start(); // [디버그 Level 2] 소요시간 측정

    try {
      final res = await http.post(
        Uri.parse('${AppConfig.serverUrl}$endpoint'),
      );
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
        // [수정] recommendations가 빈 배열 + message인 경우 (이력서 미완성)도
        // 에러가 아닌 빈 목록으로 정상 반환. message는 별도 필드로 전달.
        if (recommendations != null && recommendations is List) {
          return ApiResult.success(recommendations, message: data['message']?.toString());
        }

        return ApiResult.success([], message: data['message']?.toString());
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

    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.serverUrl}$endpoint'),
      );
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

class ApiResult<T> {
  final T? data;
  final String? errorMessage;
  // [수정] 서버 안내 메시지 (이력서 미완성 등) — 에러와 구분
  final String? message;
  final bool isSuccess;

  ApiResult.success(this.data, {this.message})
      : isSuccess = true,
        errorMessage = null;

  ApiResult.error(this.errorMessage)
      : isSuccess = false,
        data = null,
        message = null;
}
