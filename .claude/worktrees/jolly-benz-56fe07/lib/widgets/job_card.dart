import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';
import '../screens/job_detail_screen.dart';

/// 홈 탭과 일자리 탭에서 공용으로 쓰는 일자리 카드 위젯.
/// 탭 시 [JobDetailScreen]으로 Navigator.push.
class JobCard extends StatelessWidget {
  final Map<String, dynamic> job;

  const JobCard({super.key, required this.job});

  @override
  Widget build(BuildContext context) {
    final title    = job['title']?.toString()    ?? '직종명 없음';
    final company  = job['company']?.toString()  ?? '';
    final location = job['location']?.toString() ?? '';
    final workType = job['work_type']?.toString() ?? '';
    final salary   = job['salary']?.toString()   ??
                     job['wage']?.toString()     ?? '';
    final score    = job['similarity_score'];
    final scoreStr = score != null
        ? (score is num ? score.toStringAsFixed(0) : score.toString())
        : '';

    return Semantics(
      label: '$title, $company, $location — 상세 보기',
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AI 매칭 점수 배지
                    if (scoreStr.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'AI 매칭 $scoreStr%',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),

                    // 직종명
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: AppConfig.fontSizeBody,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 회사명
                    if (company.isNotEmpty)
                      _InfoRow(icon: Icons.business_outlined, text: company),
                    // 근무지역
                    if (location.isNotEmpty)
                      _InfoRow(icon: Icons.location_on_outlined, text: location),
                    // 근무형태
                    if (workType.isNotEmpty)
                      _InfoRow(
                          icon: LucideIcons.briefcase, text: workType, isLucide: true),
                    // 급여
                    if (salary.isNotEmpty)
                      _InfoRow(icon: Icons.payments_outlined, text: salary),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(LucideIcons.chevronRight, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final dynamic icon; // IconData (Material or Lucide)
  final String text;
  final bool isLucide;

  const _InfoRow({
    required this.icon,
    required this.text,
    this.isLucide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon as IconData, size: 14, color: Colors.grey[600]),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppConfig.fontSizeSmall,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer 플레이스홀더 — 로딩 중 JobCard 자리에 표시
class JobCardShimmer extends StatefulWidget {
  const JobCardShimmer({super.key});

  @override
  State<JobCardShimmer> createState() => _JobCardShimmerState();
}

class _JobCardShimmerState extends State<JobCardShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _anim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0xFFEBEBEB),
              Color(0xFFF5F5F5),
              Color(0xFFEBEBEB),
            ],
            stops: const [0.0, 0.5, 1.0],
            transform: _SlidingGradientTransform(_anim.value),
          ).createShader(bounds),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ShimmerBox(width: 80, height: 20, radius: 6),
              const SizedBox(height: 10),
              _ShimmerBox(width: double.infinity, height: 22, radius: 6),
              const SizedBox(height: 8),
              _ShimmerBox(width: 160, height: 16, radius: 4),
              const SizedBox(height: 6),
              _ShimmerBox(width: 120, height: 16, radius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox(
      {required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  final double slidePercent;
  const _SlidingGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0, 0);
  }
}
