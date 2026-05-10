import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';
import '../models/ws_status.dart';
import '../widgets/job_card.dart'; // [추가]

class HomeTab extends StatefulWidget {
  final WsStatus wsStatus;
  final String transcript;
  final String aiResponse;
  final List<String> missingKorean;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onReconnect;
  final VoidCallback onNavigateToJobs;
  // [추가] 일자리 목록 데이터 및 로딩 상태
  final List<dynamic> jobs;
  final bool isLoadingJobs;
  final VoidCallback onLoadJobs;

  const HomeTab({
    super.key,
    required this.wsStatus,
    required this.transcript,
    required this.aiResponse,
    required this.missingKorean,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onReconnect,
    required this.onNavigateToJobs,
    // [추가]
    required this.jobs,
    required this.isLoadingJobs,
    required this.onLoadJobs,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  bool _justCompleted = false;
  Timer? _completedTimer;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    // [추가] 위젯이 화면에 그려진 뒤 일자리 데이터 요청
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onLoadJobs();
    });
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.wsStatus == WsStatus.recording && !_waveController.isAnimating) {
      _waveController.repeat();
    } else if (widget.wsStatus != WsStatus.recording &&
        _waveController.isAnimating) {
      _waveController.stop();
      _waveController.reset();
    }

    final wasActive = oldWidget.wsStatus == WsStatus.speaking ||
        oldWidget.wsStatus == WsStatus.processing;
    final isNowReady = widget.wsStatus == WsStatus.ready;
    if (wasActive && isNowReady && widget.aiResponse.isNotEmpty) {
      setState(() => _justCompleted = true);
      _completedTimer?.cancel();
      _completedTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _justCompleted = false);
      });
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _completedTimer?.cancel();
    super.dispose();
  }

  void _showLongPressTip() {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          '마이크 버튼을 꾹 누른 채로 말씀해 주세요',
          style: TextStyle(fontSize: AppConfig.fontSizeCaption),
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 180),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          // [추가] SingleChildScrollView — 일자리 목록이 추가되어 스크롤 필요
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 200),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '음성만으로\n이력서를 완성하세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppConfig.fontSizeTitle,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '어려운 글쓰기 없이,\n편하게 말씀만 하시면 됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: AppConfig.fontSizeCaption,
                  ),
                ),
                const SizedBox(height: 32),

                _buildStatusMessage(),

                if (widget.transcript.isNotEmpty || widget.aiResponse.isNotEmpty)
                  _buildConversationBox(),

                if (widget.missingKorean.isNotEmpty &&
                    widget.wsStatus == WsStatus.ready)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      '남은 항목: ${widget.missingKorean.join(', ')}',
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: AppConfig.fontSizeSmall,
                      ),
                    ),
                  ),

                // [추가] 추천 일자리 섹션
                const SizedBox(height: 32),
                _buildJobsSection(),
              ],
            ),
          ),

          // 마이크 버튼 하단 고정
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Center(child: _buildRecordButton()),
          ),
        ],
      ),
    );
  }

  // [추가] 추천 일자리 섹션 (헤더 + 카드 목록 또는 상태)
  Widget _buildJobsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '추천 일자리',
              style: TextStyle(
                fontSize: AppConfig.fontSizeBody,
                fontWeight: FontWeight.bold,
              ),
            ),
            Semantics(
              label: '일자리 목록 새로고침',
              button: true,
              child: IconButton(
                icon: Icon(LucideIcons.refreshCw,
                    size: 20, color: Colors.blue[400]),
                onPressed: widget.onLoadJobs,
                tooltip: '새로고침',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 로딩 중: Shimmer 카드 3장
        if (widget.isLoadingJobs) ...[
          const JobCardShimmer(),
          const JobCardShimmer(),
          const JobCardShimmer(),
        ]
        // 데이터 있음: 실제 카드
        else if (widget.jobs.isNotEmpty)
          ...widget.jobs.map((job) {
            if (job is! Map<String, dynamic>) return const SizedBox.shrink();
            return JobCard(job: job);
          })
        // 데이터 없음: 안내 메시지
        else
          _buildEmptyJobsState(),
      ],
    );
  }

  // [추가] 일자리 없음 상태
  Widget _buildEmptyJobsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(LucideIcons.briefcase, size: 40, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            '등록된 일자리가 없습니다.',
            style: TextStyle(
              fontSize: AppConfig.fontSizeCaption,
              color: Colors.grey[500],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '이력서를 완성하면 맞춤 일자리를\n추천해 드려요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppConfig.fontSizeSmall,
              color: Colors.grey[400],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    final micColor = _getMicColor();
    final isRecording = widget.wsStatus == WsStatus.recording;
    final isProcessing = widget.wsStatus == WsStatus.processing;

    return Semantics(
      label: isRecording
          ? '녹음 중입니다. 손을 떼면 녹음이 끝납니다.'
          : '이력서 작성을 위한 음성 녹음 버튼. 꾹 눌러서 말씀해 주세요.',
      button: true,
      enabled: widget.wsStatus.isInteractive || isRecording,
      child: GestureDetector(
        onTap: _showLongPressTip,
        onLongPressStart: (_) => widget.onStartRecording(),
        onLongPressEnd: (_) => widget.onStopRecording(),
        child: SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isRecording)
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (_, __) => Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildWaveRing(micColor, _waveController.value),
                      _buildWaveRing(
                          micColor, (_waveController.value + 0.5) % 1.0),
                    ],
                  ),
                ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isRecording ? 140 : 120,
                height: isRecording ? 140 : 120,
                decoration: BoxDecoration(
                  color: micColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: micColor.withValues(alpha: 0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: _buildButtonContent(isRecording, isProcessing),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaveRing(Color color, double progress) {
    final size = 120.0 + progress * 90.0;
    final opacity = (1.0 - progress) * 0.45;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 2.5,
        ),
      ),
    );
  }

  Widget _buildButtonContent(bool isRecording, bool isProcessing) {
    if (isProcessing) {
      return const Center(
        child: SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
      );
    }
    if (_justCompleted) {
      return const Icon(Icons.check_rounded, color: Colors.white, size: 52);
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(LucideIcons.mic, color: Colors.white, size: 48),
        if (!isRecording)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '꾹 누르기',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Color _getMicColor() {
    if (_justCompleted) return Colors.green[500]!;
    switch (widget.wsStatus) {
      case WsStatus.disconnected:
        return Colors.grey[500]!;
      case WsStatus.recording:
        return Colors.red[500]!;
      case WsStatus.processing:
        return Colors.orange[400]!;
      case WsStatus.speaking:
        return Colors.green[600]!;
      default:
        return Colors.blue[500]!;
    }
  }

  Widget _buildStatusMessage() {
    IconData icon;
    Color color;

    switch (widget.wsStatus) {
      case WsStatus.disconnected:
        icon = LucideIcons.wifiOff;
        color = Colors.red;
      case WsStatus.recording:
        icon = LucideIcons.mic;
        color = Colors.red[600]!;
      case WsStatus.processing:
        icon = LucideIcons.loader;
        color = Colors.grey[700]!;
      case WsStatus.speaking:
        icon = LucideIcons.volume2;
        color = Colors.green[700]!;
      default:
        icon = LucideIcons.mic;
        color = Colors.blue[700]!;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              widget.wsStatus.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: AppConfig.fontSizeCaption,
              ),
            ),
          ],
        ),
        if (widget.wsStatus == WsStatus.disconnected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ElevatedButton.icon(
              onPressed: widget.onReconnect,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: const Text(
                '재연결 시도',
                style: TextStyle(fontSize: AppConfig.fontSizeCaption),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(
                  AppConfig.minTouchTarget,
                  AppConfig.minTouchTarget,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildConversationBox() {
    return Semantics(
      label: '대화 내용',
      child: Container(
        margin: const EdgeInsets.only(top: 32),
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '나: ${widget.transcript}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppConfig.fontSizeBody,
                  ),
                ),
              ),
            if (widget.aiResponse.isNotEmpty)
              Text(
                'AI: ${widget.aiResponse}',
                style: TextStyle(
                  color: Colors.blue[700],
                  fontWeight: FontWeight.bold,
                  fontSize: AppConfig.fontSizeBody,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
