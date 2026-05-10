// [UX 개선] 마이크 버튼 위젯 — 햅틱, 시각적 피드백, 안내 텍스트 포함
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/app_config.dart';
import '../models/ws_status.dart';

// [UX 개선] 마이크 버튼 상태
enum MicState { idle, recording, processing, done, error }

class MicButton extends StatefulWidget {
  final WsStatus wsStatus;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;

  const MicButton({
    super.key,
    required this.wsStatus,
    required this.onStartRecording,
    required this.onStopRecording,
  });

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with TickerProviderStateMixin {
  // [UX 개선] 버튼 확대 애니메이션
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  // [UX 개선] 물결 애니메이션 (녹음 중)
  late final AnimationController _rippleController;
  late final Animation<double> _rippleAnimation;

  // [UX 개선] 녹음 중 주기적 햅틱 타이머
  Timer? _hapticTimer;

  // [UX 개선] 완료 상태 표시용
  MicState _micState = MicState.idle;
  Timer? _doneTimer;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );

    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _rippleAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant MicButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.wsStatus != widget.wsStatus) {
      _syncState();
    }
  }

  void _syncState() {
    switch (widget.wsStatus) {
      case WsStatus.recording:
        _micState = MicState.recording;
        _rippleController.repeat();
        _startHapticTimer();
      case WsStatus.processing:
        _micState = MicState.processing;
        _rippleController.stop();
        _rippleController.reset();
        _stopHapticTimer();
      case WsStatus.speaking:
        _showDoneState();
      default:
        if (_micState == MicState.done) break;
        _micState = MicState.idle;
        _rippleController.stop();
        _rippleController.reset();
        _scaleController.reverse();
        _stopHapticTimer();
    }
    if (mounted) setState(() {});
  }

  void _showDoneState() {
    _micState = MicState.done;
    _rippleController.stop();
    _rippleController.reset();
    _stopHapticTimer();
    if (mounted) setState(() {});

    _doneTimer?.cancel();
    _doneTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() => _micState = MicState.idle);
      }
    });
  }

  // [UX 개선] 녹음 중 1초마다 선택 클릭 햅틱
  void _startHapticTimer() {
    _hapticTimer?.cancel();
    _hapticTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      HapticFeedback.selectionClick();
    });
  }

  void _stopHapticTimer() {
    _hapticTimer?.cancel();
    _hapticTimer = null;
  }

  void _onPressDown() {
    if (!widget.wsStatus.isInteractive) return;

    // [UX 개선] 누를 때 중간 강도 햅틱
    HapticFeedback.mediumImpact();
    _scaleController.forward();
    widget.onStartRecording();
  }

  void _onPressUp() {
    if (widget.wsStatus != WsStatus.recording) return;

    // [UX 개선] 뗄 때 가벼운 햅틱
    HapticFeedback.lightImpact();
    _scaleController.reverse();
    widget.onStopRecording();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _rippleController.dispose();
    _hapticTimer?.cancel();
    _doneTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // [UX 개선] 안내 텍스트
        _buildGuideText(),
        const SizedBox(height: 16),
        // [UX 개선] 마이크 버튼 (물결 + 확대 애니메이션)
        _buildAnimatedButton(),
      ],
    );
  }

  Widget _buildGuideText() {
    final String text;
    final Color color;

    switch (_micState) {
      case MicState.idle:
        text = '꾹 눌러서 말하기';
        color = Colors.grey[600]!;
      case MicState.recording:
        text = '듣고 있어요... (손을 떼면 완료)';
        color = Colors.red[600]!;
      case MicState.processing:
        text = '잠시만요...';
        color = Colors.grey[700]!;
      case MicState.done:
        text = '입력 완료!';
        color = Colors.green[600]!;
      case MicState.error:
        text = '다시 시도해주세요';
        color = Colors.red[700]!;
    }

    // [UX 개선] 연결 끊김 시 별도 안내
    if (widget.wsStatus == WsStatus.disconnected) {
      return Text(
        '서버 연결이 필요합니다',
        style: TextStyle(
          fontSize: AppConfig.fontSizeCaption,
          fontWeight: FontWeight.bold,
          color: Colors.red[400],
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: Text(
        text,
        key: ValueKey(text),
        style: TextStyle(
          fontSize: AppConfig.fontSizeCaption,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAnimatedButton() {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // [UX 개선] 물결(ripple) 애니메이션 레이어
          if (_micState == MicState.recording)
            AnimatedBuilder(
              animation: _rippleAnimation,
              builder: (context, child) {
                return Container(
                  width: 120 * _rippleAnimation.value,
                  height: 120 * _rippleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(
                      alpha: 0.3 * (1.6 - _rippleAnimation.value) / 0.6,
                    ),
                  ),
                );
              },
            ),

          // [UX 개선] 확대 애니메이션이 적용된 메인 버튼
          ScaleTransition(
            scale: _scaleAnimation,
            child: Semantics(
              label: _micState == MicState.recording
                  ? '녹음 중입니다. 손을 떼면 녹음이 끝납니다.'
                  : '이력서 작성을 위한 음성 녹음 버튼. 꾹 눌러서 말씀해 주세요.',
              button: true,
              enabled: widget.wsStatus.isInteractive ||
                  widget.wsStatus == WsStatus.recording,
              child: GestureDetector(
                onTapDown: (_) => _onPressDown(),
                onTapUp: (_) => _onPressUp(),
                onTapCancel: _onPressUp,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: _getButtonColor(),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _getButtonColor().withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: _buildButtonContent(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getButtonColor() {
    switch (_micState) {
      case MicState.idle:
        if (widget.wsStatus == WsStatus.disconnected) return Colors.grey[400]!;
        return Colors.blue[500]!;
      case MicState.recording:
        return Colors.red[500]!;
      case MicState.processing:
        return Colors.orange[400]!;
      case MicState.done:
        return Colors.green[500]!;
      case MicState.error:
        return Colors.red[700]!;
    }
  }

  Widget _buildButtonContent() {
    switch (_micState) {
      case MicState.idle:
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.mic, color: Colors.white, size: 48),
            Padding(
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
        );
      case MicState.recording:
        // [UX 개선] 녹음 중 — 큰 마이크 아이콘만 (텍스트 제거로 깔끔하게)
        return const Icon(LucideIcons.mic, color: Colors.white, size: 56);
      case MicState.processing:
        // [UX 개선] 처리 중 — 로딩 스피너
        return const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: Colors.white,
          ),
        );
      case MicState.done:
        // [UX 개선] 완료 — 체크 아이콘
        return const Icon(LucideIcons.checkCircle2, color: Colors.white, size: 48);
      case MicState.error:
        return const Icon(LucideIcons.alertCircle, color: Colors.white, size: 48);
    }
  }
}
