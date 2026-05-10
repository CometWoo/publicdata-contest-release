import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';

// [개선] 일자리 탭을 독립 위젯으로 분리
class JobsTab extends StatelessWidget {
  final List<dynamic> jobs;
  final VoidCallback onFetchJobs;
  final VoidCallback onNavigateToHome;
  final void Function(String title) onApply;

  const JobsTab({
    super.key,
    required this.jobs,
    required this.onFetchJobs,
    required this.onNavigateToHome,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          _buildFilterChips(),
          const SizedBox(height: 16),
          Expanded(
            child: jobs.isNotEmpty ? _buildJobList() : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final tags = ['AI 추천', '우리 동네', '경비/보안', '돌봄/요양'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tags.map((tag) {
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            // [개선] InkWell에 Semantics 추가, 터치 영역 확대
            child: Semantics(
              label: '$tag 카테고리로 필터링',
              button: true,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: onFetchJobs,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    // [개선] 최소 48dp 높이 보장
                    constraints: const BoxConstraints(
                      minHeight: AppConfig.minTouchTarget,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      tag,
                      style: TextStyle(
                        color: Colors.grey[800],
                        fontWeight: FontWeight.bold,
                        // [개선] 필터 텍스트 크기 상향
                        fontSize: AppConfig.fontSizeSmall,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJobList() {
    return ListView.builder(
      itemCount: jobs.length,
      itemBuilder: (ctx, i) {
        final job = jobs[i];
        // [개선] job 데이터 null-safe 접근
        final title = job['title']?.toString() ?? '제목 없음';
        final company = job['company']?.toString() ?? '';
        final location = job['location']?.toString() ?? '';
        final workType = job['work_type']?.toString() ?? '';
        final score = job['similarity_score']?.toString() ?? '0';
        final reason = job['reason']?.toString();

        return Semantics(
          // [개선] 각 채용공고 카드에 Semantics 적용
          label: '$title, $company, $location, AI 매칭 $score%',
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[100]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'AI 매칭 $score%',
                    style: TextStyle(
                      color: Colors.blue[700],
                      fontWeight: FontWeight.bold,
                      // [개선] 매칭 점수 폰트 크기 상향
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    // [개선] 공고 제목 크기 상향
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$company · $location',
                  style: TextStyle(
                    // [개선] 보조 정보 크기 상향
                    fontSize: AppConfig.fontSizeSmall,
                    color: Colors.grey[700],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      workType,
                      style: TextStyle(
                        color: Colors.blue[600],
                        fontWeight: FontWeight.bold,
                        fontSize: AppConfig.fontSizeBody,
                      ),
                    ),
                    // [개선] 지원 버튼 최소 터치 영역 보장
                    Semantics(
                      label: '$title 공고에 지원하기',
                      button: true,
                      child: ElevatedButton(
                        onPressed: () => onApply(title),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          elevation: 0,
                          // [개선] 최소 48dp 높이
                          minimumSize: const Size(80, AppConfig.minTouchTarget),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          '지원하기',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: AppConfig.fontSizeCaption,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (reason != null)
                  Container(
                    margin: const EdgeInsets.only(top: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // [개선] 이모지 대신 아이콘 사용 — 접근성 및 일관성
                        Icon(
                          LucideIcons.lightbulb,
                          size: 16,
                          color: Colors.blue[600],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            reason,
                            style: TextStyle(
                              fontSize: AppConfig.fontSizeSmall,
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(LucideIcons.briefcase, size: 48, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          '추천된 일자리가 없습니다.',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppConfig.fontSizeBody,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '이력서 작성이 완료되지 않았거나,\n조건에 맞는 공고가 없습니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppConfig.fontSizeCaption,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 24),
        Semantics(
          label: '홈 화면으로 이동하여 이력서 작성하기',
          button: true,
          child: ElevatedButton(
            onPressed: onNavigateToHome,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[100],
              elevation: 0,
              minimumSize: const Size(160, AppConfig.minTouchTarget),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(
              '이력서 작성하기',
              style: TextStyle(
                color: Colors.blue[600],
                fontWeight: FontWeight.bold,
                fontSize: AppConfig.fontSizeCaption,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
