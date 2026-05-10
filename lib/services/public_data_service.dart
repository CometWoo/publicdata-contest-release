// [추가] 공공데이터 포털 시니어 일자리 API 서비스
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'debug_logger.dart';

class PublicDataService {
  static const String _baseUrl =
      'https://apis.data.go.kr/B552474/SenuriService/getJobList';

  // [수정] 요청 타임아웃 설정
  static const Duration _requestTimeout = Duration(seconds: 15);

  String get _serviceKey {
    final key = dotenv.env['PUBLIC_DATA_API_KEY'] ?? '';
    if (key.isEmpty) {
      DebugLogger.logError(
        component: 'PublicDataService',
        function: '_serviceKey',
        error: 'PUBLIC_DATA_API_KEY not found in .env — API 호출이 실패합니다',
      );
    }
    return key;
  }

  Future<PublicDataResult> fetchJobs({
    int pageNo = 1,
    int numOfRows = 20,
  }) async {
    final key = _serviceKey;
    if (key.isEmpty) {
      return PublicDataResult.error('API 키가 설정되지 않았습니다. .env 파일을 확인하세요.');
    }

    final stopwatch = Stopwatch()..start();

    // [수정] serviceKey를 queryParameters에 넣으면 이중 percent-encoding 발생.
    // 공공데이터 키는 이미 URL-encoded 상태로 발급되므로 직접 문자열로 조립.
    final url = '$_baseUrl?serviceKey=$key&pageNo=$pageNo&numOfRows=$numOfRows';
    final uri = Uri.parse(url);

    DebugLogger.logAppEvent('[API] 요청: $url');

    try {
      final res = await http.get(uri).timeout(_requestTimeout);
      stopwatch.stop();

      DebugLogger.logApiRequest(
        method: 'GET',
        endpoint: '/B552474/SenuriService/getJobList',
        statusCode: res.statusCode,
        duration: stopwatch.elapsed,
      );
      DebugLogger.logAppEvent(
        '[API] 응답: statusCode=${res.statusCode}, 소요시간=${stopwatch.elapsedMilliseconds}ms',
      );

      if (res.statusCode != 200) {
        DebugLogger.logAppEvent('[ERROR] HTTP 실패: ${res.statusCode} body=${res.body.substring(0, (res.body.length > 200) ? 200 : res.body.length)}');
        return PublicDataResult.error('HTTP Error: ${res.statusCode}');
      }

      return _parseXml(res.body);
    } on Exception catch (e, stackTrace) {
      stopwatch.stop();
      DebugLogger.logError(
        component: 'PublicDataService',
        function: 'fetchJobs',
        error: e,
        stackTrace: stackTrace,
      );
      DebugLogger.logAppEvent('[ERROR] 네트워크 실패: $e');
      return PublicDataResult.error('네트워크 오류: $e');
    }
  }

  PublicDataResult _parseXml(String body) {
    try {
      final doc = XmlDocument.parse(body);

      final resultCode =
          doc.findAllElements('resultCode').firstOrNull?.innerText;
      if (resultCode != '00') {
        final resultMsg =
            doc.findAllElements('resultMsg').firstOrNull?.innerText ?? '알 수 없는 오류';
        return PublicDataResult.error('API 오류: $resultMsg');
      }

      final totalCount = int.tryParse(
            doc.findAllElements('totalCount').firstOrNull?.innerText ?? '0',
          ) ?? 0;

      final items = doc.findAllElements('item').map((item) {
        return PublicJobItem(
          jobId: _text(item, 'jobId'),
          recrtTitle: _text(item, 'recrtTitle'),
          oranNm: _text(item, 'oranNm'),
          workPlcNm: _text(item, 'workPlcNm'),
          emplymShpNm: _text(item, 'emplymShpNm'),
          acptMthd: _text(item, 'acptMthd'),
          deadline: _text(item, 'deadline'),
          frDd: _text(item, 'frDd'),
          toDd: _text(item, 'toDd'),
          stmNm: _text(item, 'stmNm'),
        );
      }).toList();

      return PublicDataResult.success(items, totalCount);
    } catch (e, stackTrace) {
      DebugLogger.logError(
        component: 'PublicDataService',
        function: '_parseXml',
        error: e,
        stackTrace: stackTrace,
      );
      return PublicDataResult.error('XML 파싱 오류: $e');
    }
  }

  String _text(XmlElement parent, String tag) {
    return parent.findElements(tag).firstOrNull?.innerText ?? '';
  }
}

// [추가] 공공데이터 API 응답 모델
class PublicJobItem {
  final String jobId;
  final String recrtTitle;
  final String oranNm;
  final String workPlcNm;
  final String emplymShpNm;
  final String acptMthd;
  final String deadline;
  final String frDd;
  final String toDd;
  final String stmNm;

  const PublicJobItem({
    required this.jobId,
    required this.recrtTitle,
    required this.oranNm,
    required this.workPlcNm,
    required this.emplymShpNm,
    required this.acptMthd,
    required this.deadline,
    required this.frDd,
    required this.toDd,
    required this.stmNm,
  });

  String get formattedPeriod {
    if (frDd.isEmpty && toDd.isEmpty) return '';
    final from = _formatDate(frDd);
    final to = _formatDate(toDd);
    return '$from ~ $to';
  }

  String _formatDate(String yyyymmdd) {
    if (yyyymmdd.length != 8) return yyyymmdd;
    return '${yyyymmdd.substring(0, 4)}.${yyyymmdd.substring(4, 6)}.${yyyymmdd.substring(6, 8)}';
  }
}

// [추가] API 결과 래퍼
class PublicDataResult {
  final List<PublicJobItem>? items;
  final int totalCount;
  final String? errorMessage;
  final bool isSuccess;

  PublicDataResult.success(this.items, this.totalCount)
      : isSuccess = true,
        errorMessage = null;

  PublicDataResult.error(this.errorMessage)
      : isSuccess = false,
        items = null,
        totalCount = 0;
}
