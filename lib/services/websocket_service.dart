import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/ws_status.dart';
import 'debug_logger.dart';

// [개선] WebSocket 메시지를 타입 안전하게 전달하는 콜백 타입 정의
typedef WsMessageCallback = void Function(Map<String, dynamic> message);
typedef WsBinaryCallback = void Function(Uint8List data);
typedef WsLogCallback = void Function(String message);

// [개선] WebSocket 관리를 독립 서비스로 분리 — 재연결 로직 포함
class WebSocketService {
  WebSocketChannel? _channel;
  WsStatus _status = WsStatus.disconnected;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  WsMessageCallback? onMessage;
  WsBinaryCallback? onBinaryMessage;
  WsLogCallback? onLog;
  VoidCallback? onStatusChanged;

  WsStatus get status => _status;

  set status(WsStatus value) {
    if (_status != value) {
      _status = value;
      onStatusChanged?.call();
    }
  }

  bool get isConnected => _channel != null && _status != WsStatus.disconnected;

  void connect() {
    if (_channel != null) return;

    status = WsStatus.connecting;
    _log('WS: Connecting to server...');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(AppConfig.wsUrl));
      _reconnectAttempts = 0;
      _log('WS: Connected successfully');

      _channel!.stream.listen(
        (message) {
          if (message is String) {
            _handleTextMessage(message);
          } else if (message is List<int>) {
            _log('WS: Received audio chunk');
            onBinaryMessage?.call(Uint8List.fromList(message));
          }
        },
        onDone: () {
          _log('WS: Disconnected');
          _cleanup();
          // [개선] 자동 재연결 — 지수 백오프 적용
          _scheduleReconnect();
        },
        onError: (err) {
          _log('WS: Network Error occurred - $err');
          _cleanup();
          _scheduleReconnect();
        },
      );
    } catch (e, stackTrace) {
      _log('WS Connect Error: $e');
      // [디버그 Level 3] 에러 추적
      DebugLogger.logError(
        component: 'WebSocketService',
        function: 'connect',
        error: e,
        stackTrace: stackTrace,
      );
      _cleanup();
      _scheduleReconnect();
    }
  }

  void _handleTextMessage(String rawMessage) {
    try {
      final msg = jsonDecode(rawMessage);
      // [개선] 서버 응답 타입 검증 추가
      if (msg is! Map<String, dynamic>) {
        _log('WS: Invalid message format');
        return;
      }
      if (!msg.containsKey('type')) {
        _log('WS: Message missing type field');
        return;
      }
      onMessage?.call(msg);
    } catch (e) {
      _log('WS: JSON parse error - $e');
    }
  }

  // [개선] 지수 백오프 재연결 — 네트워크 불안정한 시니어 환경 대응
  void _scheduleReconnect() {
    if (_reconnectAttempts >= AppConfig.maxReconnectAttempts) {
      _log('WS: Max reconnect attempts reached. Manual reconnect required.');
      return;
    }

    final delay = AppConfig.reconnectBaseDelay *
        pow(2, _reconnectAttempts).toInt();
    _reconnectAttempts++;
    _log('WS: Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/${AppConfig.maxReconnectAttempts})');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      _channel = null;
      connect();
    });
  }

  void send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  void sendBytes(Uint8List data) {
    if (_channel != null) {
      _channel!.sink.add(data);
    }
  }

  void resetReconnectAttempts() {
    _reconnectAttempts = 0;
  }

  void _cleanup() {
    status = WsStatus.disconnected;
    _channel = null;
  }

  void _log(String msg) {
    debugPrint(msg);
    // [디버그 Level 2] WebSocket 이벤트 로깅
    DebugLogger.logWsEvent(msg);
    onLog?.call(msg);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _cleanup();
  }

  void dispose() {
    disconnect();
  }
}
