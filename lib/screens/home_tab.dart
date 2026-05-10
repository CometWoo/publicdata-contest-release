import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';
import '../models/ws_status.dart';
import '../widgets/mic_button.dart';
import '../widgets/interactive_card.dart';

class HomeTab extends StatelessWidget {
  final WsStatus wsStatus;
  final String transcript;
  final String aiResponse;
  final List<String> missingKorean;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onReconnect;
  final VoidCallback onNavigateToJobs;

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
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        // [UI 개선] 그라데이션 배경으로 깊이감 추가
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F7FA)],
        ),
      ),
      child: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 200),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // [UI 개선] 타이틀 섹션
                    _buildHeader(),
                    const SizedBox(height: 24),

                    // [UI 개선] 연결 상태 표시
                    _buildStatusBadge(),
                    const SizedBox(height: 20),

                    // [UI 개선] 대화 영역 또는 빈 상태
                    if (transcript.isNotEmpty || aiResponse.isNotEmpty)
                      _buildConversationCard()
                    else
                      _buildEmptyState(),

                    // [UI 개선] 남은 항목 칩 UI
                    if (missingKorean.isNotEmpty && wsStatus == WsStatus.ready)
                      _buildProgressSection(),
                  ],
                ),
              ),
            ),

            // [인터랙션 추가] 마이크 버튼 영역
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Center(
                child: MicButton(
                  wsStatus: wsStatus,
                  onStartRecording: onStartRecording,
                  onStopRecording: onStopRecording,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          '음성만으로\n이력서를 완성하세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: AppConfig.fontSizeTitle,
            fontWeight: FontWeight.w800,
            color: Colors.grey[900],
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '어려운 글쓰기 없이, 편하게 말씀만 하시면 됩니다.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: AppConfig.fontSizeCaption,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // [UI 개선] 상태를 뱃지 형태로 표시
  Widget _buildStatusBadge() {
    IconData icon;
    Color color;
    Color bgColor;

    switch (wsStatus) {
      case WsStatus.disconnected:
        icon = LucideIcons.wifiOff;
        color = const Color(0xFFE53935);
        bgColor = const Color(0xFFFFEBEE);
      case WsStatus.recording:
        icon = LucideIcons.mic;
        color = const Color(0xFFE53935);
        bgColor = const Color(0xFFFFEBEE);
      case WsStatus.processing:
        icon = LucideIcons.loader;
        color = const Color(0xFF757575);
        bgColor = const Color(0xFFF5F5F5);
      case WsStatus.speaking:
        icon = LucideIcons.volume2;
        color = const Color(0xFF2E7D32);
        bgColor = const Color(0xFFE8F5E9);
      default:
        icon = LucideIcons.check;
        color = const Color(0xFF1565C0);
        bgColor = const Color(0xFFE3F2FD);
    }

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                wsStatus.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // [인터랙션 추가] 재연결 버튼
        if (wsStatus == WsStatus.disconnected)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: InteractiveCard(
              onTap: onReconnect,
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              borderRadius: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.refreshCw, size: 16, color: Colors.blue[600]),
                  const SizedBox(width: 8),
                  Text(
                    '재연결 시도',
                    style: TextStyle(
                      fontSize: AppConfig.fontSizeCaption,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // [UI 개선] 빈 상태 UI
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.blue[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.messageCircle,
              size: 36,
              color: Colors.blue[300],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '아래 마이크 버튼을 꾹 눌러\n대화를 시작해보세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppConfig.fontSizeCaption,
              color: Colors.grey[500],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // [UI 개선] 말풍선 스타일 대화 카드
  Widget _buildConversationCard() {
    return Semantics(
      label: '대화 내용',
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (transcript.isNotEmpty) _buildBubble(
                text: transcript,
                isUser: true,
              ),
              if (aiResponse.isNotEmpty) _buildBubble(
                text: aiResponse,
                isUser: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // [UI 개선] 개별 말풍선
  Widget _buildBubble({required String text, required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isUser ? Colors.white : Colors.grey[800],
            fontSize: AppConfig.fontSizeBody,
            height: 1.4,
          ),
          softWrap: true,
        ),
      ),
    );
  }

  // [UI 개선] 진행률 + 칩 형태 남은 항목
  Widget _buildProgressSection() {
    final total = missingKorean.length + 5;
    final done = total - missingKorean.length;
    final progress = done / total;

    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: InteractiveCard(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '이력서 완성도',
                  style: TextStyle(
                    fontSize: AppConfig.fontSizeCaption,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: AppConfig.fontSizeCaption,
                    fontWeight: FontWeight.w700,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.grey[200],
                color: Colors.blue[500],
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: missingKorean.map((item) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: AppConfig.fontSizeSmall,
                      color: Colors.orange[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
