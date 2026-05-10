import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';
import '../models/ws_status.dart';
import '../widgets/mic_button.dart';

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
      // [레이아웃 수정] SafeArea 추가
      child: SafeArea(
        child: Stack(
          children: [
            // [레이아웃 수정] SingleChildScrollView로 감싸 키보드/소형 화면 대응
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 200),
              child: SingleChildScrollView(
                child: Column(
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

                    if (transcript.isNotEmpty || aiResponse.isNotEmpty)
                      _buildConversationBox(),

                    if (missingKorean.isNotEmpty && wsStatus == WsStatus.ready)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Text(
                          '남은 항목: ${missingKorean.join(', ')}',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: AppConfig.fontSizeSmall,
                          ),
                          // [레이아웃 수정] 긴 텍스트 줄바꿈 허용
                          textAlign: TextAlign.center,
                          softWrap: true,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // [UX 개선] 기존 단순 버튼 → MicButton 위젯으로 교체
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
            // [레이아웃 수정] Flexible로 긴 상태 텍스트 overflow 방지
            Flexible(
              child: Text(
                wsStatus.label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: AppConfig.fontSizeCaption,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (wsStatus == WsStatus.disconnected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
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
        // [레이아웃 수정] 대화 박스 최대 높이 제한 + 내부 스크롤
        constraints: const BoxConstraints(maxHeight: 200),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: SingleChildScrollView(
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
                      fontSize: AppConfig.fontSizeBody,
                    ),
                    // [레이아웃 수정] softWrap 보장
                    softWrap: true,
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
                  softWrap: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
