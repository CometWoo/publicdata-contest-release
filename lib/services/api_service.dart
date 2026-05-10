import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

// [개선] HTTP API 호출을 별도 서비스로 분리
class ApiService {
  // [개선] userId를 외부에서 주입받도록 변경 — 하드코딩 제거
  final String userId;

  ApiService({required this.userId});

  Future<ApiResult<List<dynamic>>> fetchJobs() async {
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.serverUrl}/recommend/$userId'),
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
    } catch (e) {
      return ApiResult.error('Network Error: $e');
    }
  }

  Future<ApiResult<bool>> resetResume() async {
    try {
      final res = await http.delete(
        Uri.parse('${AppConfig.serverUrl}/resume/$userId'),
      );

      if (res.statusCode == 200) {
        return ApiResult.success(true);
      }

      return ApiResult.error('HTTP Error: ${res.statusCode}');
    } catch (e) {
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
