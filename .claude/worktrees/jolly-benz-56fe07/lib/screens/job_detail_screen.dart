import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';

/// 일자리 상세 페이지.
/// [job] 은 API 응답의 recommendation 항목(Map<String, dynamic>).
/// 뒤로가기: AppBar 자동 back 버튼.
/// 지원하기: 하단 고정 버튼 → 확인 다이얼로그.
class JobDetailScreen extends StatelessWidget {
  final Map<String, dynamic> job;

  const JobDetailScreen({super.key, required this.job});

  // 필드 헬퍼 — null이거나 빈 문자열이면 null 반환
  String? _str(String key) {
    final v = job[key]?.toString();
    return (v == null || v.isEmpty) ? null : v;
  }

  void _onApply(BuildContext context) {
    final title = _str('title') ?? '해당 공고';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '지원 완료',
          style: TextStyle(
            fontSize: AppConfig.fontSizeBody,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '"$title" 공고에 지원을 요청했습니다.\n담당자가 연락드릴 예정입니다.',
          style: const TextStyle(fontSize: AppConfig.fontSizeCaption),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '확인',
              style: TextStyle(fontSize: AppConfig.fontSizeCaption),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title    = _str('title')     ?? '직종명 없음';
    final company  = _str('company');
    final location = _str('location');
    final workType = _str('work_type');
    final salary   = _str('salary')   ?? _str('wage');
    final score    = job['similarity_score'];
    final scoreStr = score != null
        ? (score is num ? score.toStringAsFixed(0) : score.toString())
        : null;
    final reason      = _str('reason');
    final description = _str('description');
    final deadline    = _str('deadline') ?? _str('end_date');
    final contact     = _str('contact')  ?? _str('phone');
    final category    = _str('category') ?? _str('job_category');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Semantics(
          label: '뒤로가기',
          button: true,
          child: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.black87),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Text(
          '일자리 상세',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: AppConfig.fontSizeBody,
          ),
        ),
      ),
      // 하단 고정 지원 버튼과 스크롤 영역을 분리
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── 헤더 카드 ──────────────────────────────────────
                  _HeaderCard(
                    title: title,
                    company: company,
                    location: location,
                    workType: workType,
                    salary: salary,
                    scoreStr: scoreStr,
                    category: category,
                  ),
                  const SizedBox(height: 16),

                  // ── AI 추천 이유 ───────────────────────────────────
                  if (reason != null) ...[
                    _SectionCard(
                      icon: LucideIcons.lightbulb,
                      iconColor: Colors.amber[700]!,
                      title: 'AI 추천 이유',
                      child: Text(
                        reason,
                        style: TextStyle(
                          fontSize: AppConfig.fontSizeCaption,
                          color: Colors.grey[800],
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 상세 설명 ──────────────────────────────────────
                  if (description != null) ...[
                    _SectionCard(
                      icon: LucideIcons.fileText,
                      iconColor: Colors.blue[600]!,
                      title: '업무 내용',
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: AppConfig.fontSizeCaption,
                          color: Colors.grey[800],
                          height: 1.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── 근무 조건 ──────────────────────────────────────
                  _SectionCard(
                    icon: LucideIcons.clipboardList,
                    iconColor: Colors.green[700]!,
                    title: '근무 조건',
                    child: Column(
                      children: [
                        if (workType != null)
                          _DetailRow(label: '근무형태', value: workType),
                        if (salary != null)
                          _DetailRow(label: '급여', value: salary),
                        if (location != null)
                          _DetailRow(label: '근무지역', value: location),
                        if (deadline != null)
                          _DetailRow(label: '마감일', value: deadline),
                        if (contact != null)
                          _DetailRow(label: '연락처', value: contact),
                        // 위 필드가 하나도 없을 때 대비
                        if (workType == null &&
                            salary == null &&
                            location == null &&
                            deadline == null &&
                            contact == null)
                          Text(
                            '상세 근무 조건은 담당자에게 문의하세요.',
                            style: TextStyle(
                              fontSize: AppConfig.fontSizeCaption,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── 알 수 없는 나머지 필드 동적 표시 ───────────────
                  ..._buildExtraFields(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // ── 하단 고정 지원하기 버튼 ───────────────────────────────
          _ApplyButton(onApply: () => _onApply(context)),
        ],
      ),
    );
  }

  /// API 응답에 알려지지 않은 추가 필드가 있을 때 자동으로 렌더링
  List<Widget> _buildExtraFields() {
    const knownKeys = {
      'title', 'company', 'location', 'work_type', 'salary', 'wage',
      'similarity_score', 'reason', 'description', 'deadline', 'end_date',
      'contact', 'phone', 'category', 'job_category',
    };
    final extras = job.entries
        .where((e) => !knownKeys.contains(e.key) && e.value != null)
        .toList();
    if (extras.isEmpty) return [];
    return [
      const SizedBox(height: 16),
      _SectionCard(
        icon: LucideIcons.info,
        iconColor: Colors.grey[600]!,
        title: '추가 정보',
        child: Column(
          children: extras.map((e) {
            final label = e.key
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
                .join(' ');
            return _DetailRow(label: label, value: e.value.toString());
          }).toList(),
        ),
      ),
    ];
  }
}

// ── 서브 위젯들 ──────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final String title;
  final String? company;
  final String? location;
  final String? workType;
  final String? salary;
  final String? scoreStr;
  final String? category;

  const _HeaderCard({
    required this.title,
    this.company,
    this.location,
    this.workType,
    this.salary,
    this.scoreStr,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 카테고리 + 매칭 점수
          if (category != null || scoreStr != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  if (category != null)
                    _Badge(text: category!, color: Colors.grey[100]!,
                        textColor: Colors.grey[700]!),
                  if (scoreStr != null)
                    _Badge(
                      text: 'AI 매칭 $scoreStr%',
                      color: Colors.blue[50]!,
                      textColor: Colors.blue[700]!,
                    ),
                ],
              ),
            ),

          // 직종명
          Text(
            title,
            style: const TextStyle(
              fontSize: AppConfig.fontSizeTitle,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),

          if (company != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.business_outlined, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    company!,
                    style: TextStyle(
                      fontSize: AppConfig.fontSizeCaption,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (location != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    location!,
                    style: TextStyle(
                      fontSize: AppConfig.fontSizeCaption,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (salary != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.payments_outlined, size: 18, color: Colors.green[700]),
                const SizedBox(width: 8),
                Text(
                  salary!,
                  style: TextStyle(
                    fontSize: AppConfig.fontSizeCaption,
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;

  const _Badge(
      {required this.text, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: AppConfig.fontSizeBody,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppConfig.fontSizeSmall,
                color: Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: AppConfig.fontSizeSmall,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplyButton extends StatelessWidget {
  final VoidCallback onApply;

  const _ApplyButton({required this.onApply});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Semantics(
        label: '이 공고에 지원하기',
        button: true,
        child: SizedBox(
          width: double.infinity,
          height: AppConfig.minTouchTarget + 8,
          child: ElevatedButton(
            onPressed: onApply,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              '지원하기',
              style: TextStyle(
                color: Colors.white,
                fontSize: AppConfig.fontSizeBody,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
