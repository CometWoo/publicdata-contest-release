import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';
import '../models/ws_status.dart';
import '../widgets/accessible_button.dart';

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
      color: Colors.white,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // [개선] 시니어용 폰트 크기 상향 (24 → 26)
          const Text(
            '음성만으로\n이력서를 완성하세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppConfig.fontSizeTitle,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // [개선] 보조 텍스트 폰트 크기 상향 및 색상 대비 개선
          Text(
            '어려운 글쓰기 없이,\n편하게 말씀만 하시면 됩니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[700], // [개선] grey → grey[700]로 대비율 향상
              fontSize: AppConfig.fontSizeCaption,
            ),
          ),
          const SizedBox(height: 40),

          // [개선] 녹음 버튼에 Semantics 적용 — 스크린 리더 지원
          _buildRecordButton(),
          const SizedBox(height: 24),

          // [개선] 상태 메시지에 아이콘 병행 — 색상만으로 구분하지 않음
          _buildStatusMessage(),

          if (transcript.isNotEmpty || aiResponse.isNotEmpty)
            _buildConversationBox(),

          if (missingKorean.isNotEmpty && wsStatus == WsStatus.ready)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                '남은 항목: ${missingKorean.join(', ')}',
                style: TextStyle(
                  color: Colors.grey[700],
                  // [개선] 보조 텍스트도 최소 14sp
                  fontSize: AppConfig.fontSizeSmall,
                ),
              ),
            ),

          const Spacer(),

          // [개선] GestureDetector → AccessibleCardButton으로 교체
          AccessibleCardButton(
            title: '어르신 맞춤 일자리',
            subtitle: '이력서를 작성하시면 딱 맞는 일자리를 추천해 드려요.',
            semanticsLabel: '어르신 맞춤 일자리 추천 화면으로 이동',
            onTap: onNavigateToJobs,
            trailing: Icon(LucideIcons.chevronRight, color: Colors.blue[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    final micColor = _getMicColor();
    final isRecording = wsStatus == WsStatus.recording;

    // [개선] Semantics로 녹음 버튼의 역할과 상태를 스크린 리더에 전달
    return Semantics(
      label: isRecording
          ? '녹음 중입니다. 손을 떼면 녹음이 끝납니다.'
          : '이력서 작성을 위한 음성 녹음 버튼. 꾹 눌러서 말씀해 주세요.',
      button: true,
      enabled: wsStatus.isInteractive || isRecording,
      child: GestureDetector(
        onTapDown: (_) => onStartRecording(),
        onTapUp: (_) => onStopRecording(),
        onTapCancel: onStopRecording,
        child: AnimatedContainer(
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.mic, color: Colors.white, size: 48),
              // [개선] 버튼 내부에 텍스트 라벨 추가 — 색상 외 시각적 단서
              if (!isRecording)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    '말하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getMicColor() {
    switch (wsStatus) {
      case WsStatus.disconnected:
        return Colors.grey[500]!;
      case WsStatus.recording:
        return Colors.red[500]!;
      case WsStatus.speaking:
        return Colors.green[600]!;
      default:
        return Colors.blue[500]!;
    }
  }

  // [개선] 상태 메시지에 아이콘 + 텍스트 병행 — 색맹/색약 사용자 대응
  Widget _buildStatusMessage() {
    IconData icon;
    Color color;

    switch (wsStatus) {
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
              wsStatus.label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: AppConfig.fontSizeCaption,
              ),
            ),
          ],
        ),
        if (wsStatus == WsStatus.disconnected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            // [개선] TextButton → ElevatedButton으로 터치 영역 확대
            child: ElevatedButton.icon(
              onPressed: onReconnect,
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
            if (transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '나: $transcript',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    // [개선] 대화 텍스트 크기 상향
                    fontSize: AppConfig.fontSizeBody,
                  ),
                ),
              ),
            if (aiResponse.isNotEmpty)
              Text(
                'AI: $aiResponse',
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
