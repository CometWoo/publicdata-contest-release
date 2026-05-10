// [추가] 공공데이터 API 연동 일자리 상세정보 화면
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';
import '../services/public_data_service.dart';

class JobDetailScreen extends StatefulWidget {
  final Map<String, dynamic> job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final PublicDataService _publicDataService = PublicDataService();

  bool _isLoading = true;
  String? _errorMessage;
  List<PublicJobItem> _publicJobs = [];
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchPublicData();
  }

  Future<void> _fetchPublicData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _publicDataService.fetchJobs(
      pageNo: 1,
      numOfRows: 10,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.isSuccess) {
        _publicJobs = result.items ?? [];
        _totalCount = result.totalCount;
      } else {
        _errorMessage = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.job['title']?.toString() ?? '제목 없음';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: Colors.grey[800]),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '공고 상세정보',
          style: TextStyle(
            color: Colors.grey[900],
            fontWeight: FontWeight.bold,
            fontSize: AppConfig.fontSizeBody,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildJobHeader(title),
            const SizedBox(height: 24),
            _buildPublicDataSection(),
          ],
        ),
      ),
    );
  }

  // [추가] AI 추천 공고 요약 헤더
  Widget _buildJobHeader(String title) {
    final company = widget.job['company']?.toString() ?? '';
    final location = widget.job['location']?.toString() ?? '';
    final workType = widget.job['work_type']?.toString() ?? '';
    final score = widget.job['similarity_score']?.toString() ?? '0';
    final reason = widget.job['reason']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'AI 매칭 $score%',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
                fontSize: AppConfig.fontSizeSmall,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(LucideIcons.building2, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                company,
                style: TextStyle(
                  fontSize: AppConfig.fontSizeCaption,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(LucideIcons.mapPin, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text(
                location,
                style: TextStyle(
                  fontSize: AppConfig.fontSizeCaption,
                  color: Colors.grey[700],
                ),
              ),
            ],
          ),
          if (workType.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.clock, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  workType,
                  style: TextStyle(
                    fontSize: AppConfig.fontSizeCaption,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
          if (reason != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(LucideIcons.lightbulb, size: 16, color: Colors.blue[600]),
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
        ],
      ),
    );
  }

  // [추가] 공공데이터 API 연동 섹션
  Widget _buildPublicDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.database, size: 20, color: Colors.blue[700]),
            const SizedBox(width: 8),
            Text(
              '공공데이터 채용정보',
              style: TextStyle(
                fontSize: AppConfig.fontSizeBody,
                fontWeight: FontWeight.bold,
                color: Colors.grey[900],
              ),
            ),
            const Spacer(),
            if (_totalCount > 0)
              Text(
                '총 ${_formatCount(_totalCount)}건',
                style: TextStyle(
                  fontSize: AppConfig.fontSizeSmall,
                  color: Colors.grey[500],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          _buildLoadingSkeleton()
        else if (_errorMessage != null)
          _buildErrorState()
        else if (_publicJobs.isEmpty)
          _buildEmptyState()
        else
          ..._publicJobs.map(_buildPublicJobCard),
      ],
    );
  }

  // [추가] 로딩 스켈레톤 UI
  Widget _buildLoadingSkeleton() {
    return Column(
      children: List.generate(3, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skeletonBox(width: 80, height: 20),
              const SizedBox(height: 12),
              _skeletonBox(width: double.infinity, height: 22),
              const SizedBox(height: 8),
              _skeletonBox(width: 200, height: 16),
              const SizedBox(height: 8),
              _skeletonBox(width: 160, height: 16),
            ],
          ),
        );
      }),
    );
  }

  Widget _skeletonBox({required double height, double? width}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // [추가] 에러 상태 + 재시도 버튼
  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.alertCircle, size: 48, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _errorMessage ?? '알 수 없는 오류가 발생했습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppConfig.fontSizeCaption,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 20),
          Semantics(
            label: '공공데이터 다시 불러오기',
            button: true,
            child: ElevatedButton.icon(
              onPressed: _fetchPublicData,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text(
                '다시 시도',
                style: TextStyle(fontSize: AppConfig.fontSizeCaption),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                minimumSize: const Size(140, AppConfig.minTouchTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // [추가] 데이터 없음 상태
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.inbox, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            '등록된 공공 채용정보가 없습니다.',
            style: TextStyle(
              fontSize: AppConfig.fontSizeCaption,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  // [추가] 공공데이터 채용공고 카드
  Widget _buildPublicJobCard(PublicJobItem item) {
    final bool isOpen = item.deadline == '접수중';

    return Semantics(
      label: '${item.recrtTitle}, ${item.oranNm}, ${item.workPlcNm}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isOpen ? Colors.green[50] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.deadline.isNotEmpty ? item.deadline : '상태 미정',
                    style: TextStyle(
                      color: isOpen ? Colors.green[700] : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (item.stmNm.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple[50],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      item.stmNm,
                      style: TextStyle(
                        color: Colors.purple[700],
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item.recrtTitle.isNotEmpty ? item.recrtTitle : '제목 없음',
              style: const TextStyle(
                fontSize: AppConfig.fontSizeBody,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildInfoRow(LucideIcons.building2, item.oranNm),
            if (item.workPlcNm.isNotEmpty)
              _buildInfoRow(LucideIcons.mapPin, item.workPlcNm),
            if (item.acptMthd.isNotEmpty)
              _buildInfoRow(LucideIcons.send, '접수방법: ${item.acptMthd}'),
            if (item.formattedPeriod.isNotEmpty)
              _buildInfoRow(LucideIcons.calendar, item.formattedPeriod),
            if (item.emplymShpNm.isNotEmpty &&
                !item.emplymShpNm.startsWith('CM'))
              _buildInfoRow(LucideIcons.briefcase, item.emplymShpNm),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[500]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppConfig.fontSizeSmall,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}만';
    }
    return count.toString();
  }
}
