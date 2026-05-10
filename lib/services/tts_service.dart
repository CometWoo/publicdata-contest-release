// [수정] 로컬 TTS 서비스 — flutter_tts 패키지를 사용한 한국어 음성 출력
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'debug_logger.dart';

// [수정] TTS 상태 열거형
enum TtsState { idle, playing, paused, error }

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsState _state = TtsState.idle;
  TtsState get state => _state;

  String? _lastError;
  String? get lastError => _lastError;

  // [수정] 외부에서 상태 변화를 수신하는 콜백
  VoidCallback? onStateChanged;
  void Function(String error)? onError;

  // [수정] 초기화 — 한국어 설정 및 시니어 친화적 음성 파라미터
  Future<bool> init() async {
    try {
      // [수정] 한국어 설정
      final languages = await _flutterTts.getLanguages;
      DebugLogger.logAppEvent('[TTS] 사용 가능한 언어: $languages');

      final setResult = await _flutterTts.setLanguage('ko-KR');
      if (setResult != 1) {
        DebugLogger.logAppEvent('[TTS] 한국어 설정 실패, 기본 언어 사용');
      }

      // [수정] 시니어 친화적 음성 파라미터 — 느린 속도, 높은 볼륨
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // [수정] Android 전용 설정
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _flutterTts.setEngine('com.google.android.tts');
      }

      // [수정] iOS 전용 설정 — 다른 오디오와 혼합 허용
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.ambient,
          [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }

      // [수정] 이벤트 리스너 등록
      _flutterTts.setStartHandler(() {
        _setState(TtsState.playing);
        DebugLogger.logAppEvent('[TTS] 재생 시작');
      });

      _flutterTts.setCompletionHandler(() {
        _setState(TtsState.idle);
        DebugLogger.logAppEvent('[TTS] 재생 완료');
      });

      _flutterTts.setCancelHandler(() {
        _setState(TtsState.idle);
        DebugLogger.logAppEvent('[TTS] 재생 취소됨');
      });

      _flutterTts.setPauseHandler(() {
        _setState(TtsState.paused);
      });

      _flutterTts.setContinueHandler(() {
        _setState(TtsState.playing);
      });

      _flutterTts.setErrorHandler((msg) {
        _lastError = msg;
        _setState(TtsState.error);
        DebugLogger.logAppEvent('[ERROR] TTS 오류: $msg');
        onError?.call('TTS 오류: $msg');
      });

      DebugLogger.logAppEvent('[TTS] 초기화 완료 (ko-KR, rate=0.45)');
      return true;
    } catch (e, stackTrace) {
      DebugLogger.logError(
        component: 'TtsService',
        function: 'init',
        error: e,
        stackTrace: stackTrace,
      );
      _lastError = e.toString();
      _setState(TtsState.error);
      onError?.call('TTS 초기화 실패: $e');
      return false;
    }
  }

  // [수정] 텍스트를 음성으로 변환하여 재생
  Future<bool> speak(String text) async {
    if (text.trim().isEmpty) return false;

    try {
      DebugLogger.logAppEvent('[TTS] 요청: "${text.substring(0, text.length > 30 ? 30 : text.length)}..."');

      // 이미 재생 중이면 중지 후 새로 시작
      if (_state == TtsState.playing) {
        await stop();
      }

      final result = await _flutterTts.speak(text);
      if (result == 1) {
        _setState(TtsState.playing);
        return true;
      } else {
        DebugLogger.logAppEvent('[ERROR] TTS speak 실패: result=$result');
        _setState(TtsState.error);
        onError?.call('음성 출력에 실패했습니다.');
        return false;
      }
    } catch (e, stackTrace) {
      DebugLogger.logError(
        component: 'TtsService',
        function: 'speak',
        error: e,
        stackTrace: stackTrace,
      );
      _lastError = e.toString();
      _setState(TtsState.error);
      onError?.call('음성 출력 중 오류가 발생했습니다.');
      return false;
    }
  }

  // [수정] 재생 중지
  Future<void> stop() async {
    await _flutterTts.stop();
    _setState(TtsState.idle);
  }

  // [수정] 일시정지
  Future<void> pause() async {
    await _flutterTts.pause();
  }

  // [수정] 음성 속도 변경 (0.0 ~ 1.0)
  Future<void> setSpeechRate(double rate) async {
    await _flutterTts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  // [수정] 한국어 TTS 사용 가능 여부 확인
  Future<bool> isKoreanAvailable() async {
    try {
      final isAvailable = await _flutterTts.isLanguageAvailable('ko-KR');
      return isAvailable == 1 || isAvailable == true;
    } catch (_) {
      return false;
    }
  }

  void _setState(TtsState newState) {
    if (_state != newState) {
      _state = newState;
      onStateChanged?.call();
    }
  }

  void dispose() {
    _flutterTts.stop();
  }
}
