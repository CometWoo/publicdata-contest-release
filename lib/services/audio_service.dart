import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

// [개선] 조건부 import로 웹 플랫폼 호환성 확보 (dart:io 직접 사용 제거)
import 'file_helper_stub.dart'
    if (dart.library.io) 'file_helper_io.dart'
    if (dart.library.html) 'file_helper_web.dart' as file_helper;

import 'tts_service.dart';
import 'debug_logger.dart';

// [개선] 오디오 녹음/재생 로직을 별도 서비스로 분리하여 단일 책임 원칙 준수
class AudioService {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // [수정] 로컬 TTS 서비스 통합
  final TtsService ttsService = TtsService();

  final List<String> _playQueue = [];
  bool _isPlaying = false;

  // [개선] 재생 완료/에러를 외부에 알리는 콜백
  VoidCallback? onPlaybackComplete;
  void Function(String error)? onError;

  bool get isPlaying => _isPlaying || ttsService.state == TtsState.playing;
  bool get hasQueuedAudio => _playQueue.isNotEmpty;

  void init() {
    _audioPlayer.onPlayerComplete.listen((_) {
      _isPlaying = false;
      // [개선] 재생 완료 후 임시 파일 정리
      if (_playQueue.isNotEmpty) {
        playNextAudio();
      } else {
        onPlaybackComplete?.call();
      }
    });

    // [수정] 로컬 TTS 초기화
    ttsService.onStateChanged = () {
      if (ttsService.state == TtsState.idle) {
        onPlaybackComplete?.call();
      }
    };
    ttsService.onError = (msg) {
      onError?.call(msg);
    };
    ttsService.init();
  }

  // [수정] 로컬 TTS로 텍스트 음성 출력
  Future<bool> speakLocal(String text) async {
    DebugLogger.logAppEvent('[TTS] 로컬 TTS 요청: ${text.substring(0, text.length > 20 ? 20 : text.length)}...');
    return await ttsService.speak(text);
  }

  // [수정] 로컬 TTS 중지
  Future<void> stopLocalTts() async {
    await ttsService.stop();
  }

  Future<bool> hasPermission() async {
    return await _audioRecorder.hasPermission();
  }

  Future<String?> startRecording() async {
    try {
      if (!await hasPermission()) return null;

      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/turn_audio.wav';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: path,
      );
      return path;
    } catch (e) {
      onError?.call('MIC Error: $e');
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      return await _audioRecorder.stop();
    } catch (e) {
      onError?.call('MIC Stop Error: $e');
      return null;
    }
  }

  // [개선] 바이너리 오디오 데이터를 큐에 추가
  Future<void> enqueueAudioChunk(Uint8List audioData) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.mp3';

      await file_helper.writeBytes(filePath, audioData);
      _playQueue.add(filePath);
      playNextAudio();
    } catch (e) {
      onError?.call('Audio Enqueue Error: $e');
    }
  }

  Future<void> playNextAudio() async {
    if (_isPlaying || _playQueue.isEmpty) return;

    _isPlaying = true;
    final filePath = _playQueue.removeAt(0);

    try {
      await _audioPlayer.play(DeviceFileSource(filePath));
      // [개선] 재생 완료 후 임시 파일 삭제로 디스크 공간 누수 방지
      _scheduleFileCleanup(filePath);
    } catch (e) {
      onError?.call('Audio Play Error: $e');
      _isPlaying = false;
      // [개선] 실패한 파일도 삭제
      _scheduleFileCleanup(filePath);
      playNextAudio();
    }
  }

  // [개선] 재생 완료 후 임시 파일 삭제 — 장시간 사용 시 디스크 공간 보호
  void _scheduleFileCleanup(String filePath) {
    Future.delayed(const Duration(seconds: 5), () {
      file_helper.deleteFile(filePath);
    });
  }

  void dispose() {
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _playQueue.clear();
    // [수정] 로컬 TTS도 정리
    ttsService.dispose();
  }
}
