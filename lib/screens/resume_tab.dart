import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';

// [개선] 이력서 탭을 독립 위젯으로 분리 — 단일 책임 원칙
class ResumeTab extends StatelessWidget {
  final Map<String, dynamic>? resume;
  final List<String> missingKorean;
  final VoidCallback onReset;
  final VoidCallback onNavigateToHome;

  const ResumeTab({
    super.key,
    required this.resume,
    required this.missingKorean,
    required this.onReset,
    required this.onNavigateToHome,
  });

  // [개선] 매 빌드마다 생성되던 Map 리터럴을 static const로 분리
  static const Map<String, String> _fieldLabels = {
    'name': '성명',
    'age': '연령',
    'location': '거주지',
    'career': '최근 직장명 (경력)',
    'preferred_work_type': '희망 근무 형태',
    'physical_condition': '건강 상태',
  };

  // [개선] missingKorean 비교용 매핑도 static const로 분리 — 빌드마다 재생성 방지
  static const Map<String, String> _fieldToKorean = {
    'name': '이름',
    'age': '나이',
    'location': '거주지',
    'career': '경력',
    'preferred_work_type': '희망 근무형태',
    'physical_condition': '건강 상태/체력',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(child: _buildResumeCard()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '어르신의',
              style: TextStyle(
                // [개선] 시니어 폰트 크기 적용
                fontSize: AppConfig.fontSizeTitle,
                fontWeight: FontWeight.bold,
                color: Colors.blue[600],
              ),
            ),
            const Text(
              '멋진 이력서입니다!',
              style: TextStyle(
                fontSize: AppConfig.fontSizeTitle,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        // [개선] GestureDetector → Semantics + InkWell로 교체, 터치 영역 확대
        Semantics(
          label: '이력서 초기화 버튼',
          button: true,
          child: Material(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onReset,
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                // [개선] 최소 48dp 터치 영역 보장
                constraints: const BoxConstraints(
                  minWidth: AppConfig.minTouchTarget,
                  minHeight: AppConfig.minTouchTarget,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.trash2, size: 16, color: Colors.red[500]),
                      const SizedBox(width: 4),
                      Text(
                        '초기화',
                        style: TextStyle(
                          color: Colors.red[500],
                          fontWeight: FontWeight.bold,
                          // [개선] 버튼 텍스트도 최소 14sp
                          fontSize: AppConfig.fontSizeSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: ListView(
        children: [
          ..._fieldLabels.keys.map((key) => _buildField(key)),
          const SizedBox(height: 10),
          // [개선] 버튼 최소 높이 48dp 보장
          Semantics(
            label: '홈 화면으로 이동하여 음성으로 이력서 작성하기',
            button: true,
            child: ElevatedButton(
              onPressed: onNavigateToHome,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[50],
                foregroundColor: Colors.blue[600],
                elevation: 0,
                // [개선] 터치 영역 확대
                minimumSize: const Size(double.infinity, AppConfig.minTouchTarget),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '음성으로 이력서 채우러 가기',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: AppConfig.fontSizeCaption,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String key) {
    final val = resume?[key]?.toString();
    final koreanKey = _fieldToKorean[key];
    final isMissing = koreanKey != null && missingKorean.contains(koreanKey);
    final hasValue = !isMissing && val != null && val.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Semantics(
        // [개선] 각 필드에 Semantics 적용
        label: hasValue
            ? '${_fieldLabels[key]}: ${key == 'age' ? '${val}세' : val}'
            : '${_fieldLabels[key]}: 미입력. 홈에서 음성으로 입력해주세요.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _fieldLabels[key]!,
              style: TextStyle(
                // [개선] 라벨 폰트 크기 상향
                fontSize: AppConfig.fontSizeSmall,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (hasValue) ...[
                  Text(
                    key == 'age' ? '${val}세' : val!,
                    style: const TextStyle(
                      // [개선] 값 텍스트 크기 상향
                      fontSize: AppConfig.fontSizeBody,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    label: '입력 완료',
                    child: const Icon(
                      LucideIcons.checkCircle2,
                      color: Colors.green,
                      size: 18,
                    ),
                  ),
                ] else ...[
                  Text(
                    '홈에서 음성으로 입력해주세요',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: AppConfig.fontSizeCaption,
                    ),
                  ),
                ],
              ],
            ),
            const Divider(height: 20, color: Color(0xFFF5F5F5)),
          ],
        ),
      ),
    );
  }
}
