import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lucide_icons/lucide_icons.dart';

// [개선] dart:io 직접 import 제거 — 웹 빌드 호환성 확보
import 'config/app_config.dart';
import 'models/ws_status.dart';
import 'services/websocket_service.dart';
import 'services/audio_service.dart';
import 'services/api_service.dart';
import 'services/file_helper_stub.dart'
    if (dart.library.io) 'services/file_helper_io.dart'
    if (dart.library.html) 'services/file_helper_web.dart' as file_helper;
import 'screens/home_tab.dart';
import 'screens/resume_tab.dart';
import 'screens/jobs_tab.dart';
import 'screens/mypage_tab.dart';
import 'widgets/debug_panel.dart';
import 'services/debug_logger.dart';

// [추가] dotenv 비동기 초기화를 위해 async main
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // [추가] .env 파일 로딩 — API 키 관리
  await dotenv.load(fileName: '.env').catchError((_) {
    DebugLogger.logAppEvent('⚠️ .env file not found — using defaults');
  });

  // [디버그 Level 1] 앱 시작 로깅
  DebugLogger.logAppEvent('✅ Silver Voice App starting...');

  // [디버그 Level 3] 글로벌 에러 핸들링
  FlutterError.onError = (details) {
    DebugLogger.logError(
      component: 'Flutter',
      function: 'onError',
      error: details.exceptionAsString(),
      stackTrace: details.stack,
    );
  };

  runApp(const SilverVoiceApp());
}

class SilverVoiceApp extends StatelessWidget {
  const SilverVoiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Silver Voice',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue[600],
        scaffoldBackgroundColor: Colors.grey[100],
        // [개선] 한글 최적화 폰트 지정 — 시니어 가독성 향상
        fontFamily: 'NotoSansKR',
        // [개선] 기본 텍스트 크기를 시니어 친화적으로 상향
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: AppConfig.fontSizeBody),
          bodyMedium: TextStyle(fontSize: AppConfig.fontSizeCaption),
          labelLarge: TextStyle(fontSize: AppConfig.fontSizeCaption),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 1;
  bool _debugMode = false;
  bool _notificationEnabled = true;
  final List<String> _logs = [];

  // [개선] 데이터 상태
  Map<String, dynamic>? _resume;
  List<String> _missingKorean = [];
  List<dynamic> _jobs = [];
  String _transcript = '';
  String _aiResponse = '';

  // [개선] 서비스 분리 — WebSocket, Audio, API를 독립 서비스로 관리
  late final WebSocketService _wsService;
  late final AudioService _audioService;
  late final ApiService _apiService;

  // [개선] AI 응답 스트리밍 시 setState throttle용 타이머
  Timer? _aiResponseThrottle;

  // [개선] userId를 환경변수에서 주입 — 하드코딩 제거
  final String _userId = const String.fromEnvironment(
    'USER_ID',
    defaultValue: 'test-user-001',
  );

  @override
  void initState() {
    super.initState();
    // [디버그 Level 1] 메인 화면 초기화 로깅
    DebugLogger.logAppEvent('✅ MainScreen initialized — userId: $_userId');
    _initServices();
  }

  void _initServices() {
    // [개선] API 서비스 초기화 — userId 주입
    _apiService = ApiService(userId: _userId);

    // [개선] WebSocket 서비스 초기화 — 콜백 기반 이벤트 처리
    _wsService = WebSocketService();
    _wsService.onMessage = _handleWsMessage;
    _wsService.onBinaryMessage = _handleWsBinary;
    _wsService.onLog = _addLog;
    _wsService.onStatusChanged = () {
      if (mounted) setState(() {});
    };
    _wsService.connect();

    // [개선] 오디오 서비스 초기화
    _audioService = AudioService();
    _audioService.onPlaybackComplete = () {
      if (_wsService.status == WsStatus.speaking) {
        _wsService.status = WsStatus.ready;
      }
    };
    _audioService.onError = _addLog;
    _audioService.init();
  }

  @override
  void dispose() {
    _aiResponseThrottle?.cancel();
    _wsService.dispose();
    _audioService.dispose();
    super.dispose();
  }

  // [개선] 디버그 모드가 꺼져 있으면 setState 호출 생략하여 불필요한 리빌드 방지
  void _addLog(String msg) {
    debugPrint(msg);
    if (_debugMode && mounted) {
      setState(() {
        _logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $msg');
        if (_logs.length > 15) _logs.removeAt(0);
      });
    } else {
      _logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $msg');
      if (_logs.length > 15) _logs.removeAt(0);
    }
  }

  // [개선] WebSocket 메시지 핸들링 — 타입 검증 강화
  void _handleWsMessage(Map<String, dynamic> msg) {
    final type = msg['type']?.toString();
    if (type == null) return;

    switch (type) {
      case 'ready':
        _addLog('WS: Server is ready. Requesting sync_resume...');
        _wsService.send({'type': 'sync_resume', 'user_id': _userId});
        _wsService.status = WsStatus.ready;
        break;

      case 'resume_state':
      case 'resume_updated':
        _addLog('WS: Resume updated.');
        setState(() {
          _resume = msg['resume'] as Map<String, dynamic>?;
          _missingKorean = List<String>.from(msg['missing_korean'] ?? []);
        });
        break;

      case 'transcript':
        _addLog('STT: ${msg['text']}');
        setState(() {
          _transcript = msg['text']?.toString() ?? '';
          _aiResponse = '';
          _wsService.status = WsStatus.processing;
        });
        break;

      case 'llm_token':
        // [개선] LLM 토큰 수신 시 throttle 적용 — 매 토큰마다 리빌드 방지
        _aiResponse += msg['text']?.toString() ?? '';
        _aiResponseThrottle?.cancel();
        _aiResponseThrottle = Timer(const Duration(milliseconds: 50), () {
          if (mounted) setState(() {});
        });
        break;

      case 'reply_done':
        _addLog('WS: AI reply finished.');
        // [개선] throttle 취소 후 최종 상태 반영
        _aiResponseThrottle?.cancel();
        // [수정] 서버에서 오디오가 오지 않았으면 로컬 TTS로 폴백
        if (!_audioService.isPlaying && !_audioService.hasQueuedAudio) {
          if (_aiResponse.isNotEmpty) {
            _addLog('[TTS] 서버 오디오 없음 — 로컬 TTS로 폴백');
            _wsService.status = WsStatus.speaking;
            _audioService.speakLocal(_aiResponse);
          } else {
            _wsService.status = WsStatus.ready;
          }
        }
        if (mounted) setState(() {});
        break;

      case 'error':
        final errorMsg = msg['msg']?.toString() ?? 'Unknown error';
        _addLog('WS Error: $errorMsg');
        _wsService.status = WsStatus.ready;
        _showDialog('서버 에러', errorMsg);
        break;

      default:
        _addLog('WS: Unknown message type: $type');
    }
  }

  void _handleWsBinary(Uint8List data) {
    _addLog('WS: Received audio chunk');
    _wsService.status = WsStatus.speaking;
    _audioService.enqueueAudioChunk(data);
  }

  // --- 녹음 로직 ---
  Future<void> _startRecording() async {
    if (_wsService.status != WsStatus.ready) {
      _addLog('Cannot record: Server is not ready.');
      return;
    }

    final hasPermission = await _audioService.hasPermission();
    if (!hasPermission) {
      _showDialog('권한 오류', '마이크 권한을 허용해주세요.');
      return;
    }

    final path = await _audioService.startRecording();
    if (path != null) {
      setState(() {
        _wsService.status = WsStatus.recording;
        _transcript = '';
        _aiResponse = '';
      });
      _addLog('MIC: Recording started...');
    }
  }

  Future<void> _stopRecording() async {
    if (_wsService.status == WsStatus.recording) {
      final path = await _audioService.stopRecording();
      _addLog('MIC: Recording stopped.');

      if (path != null) {
        // [개선] 파일 읽기를 플랫폼 추상화 레이어로 처리
        final bytes = await file_helper.readBytes(path);
        _addLog('Send: type=turn & audio binary data');

        _wsService.send({'type': 'turn', 'user_id': _userId});
        _wsService.sendBytes(bytes);

        setState(() {
          _wsService.status = WsStatus.processing;
        });
      }
    }
  }

  // --- API 호출 ---
  // [개선] jobs 캐싱 — 일정 시간 내 탭 재전환 시 재호출 방지
  DateTime? _lastJobsFetch;
  static const _jobsCacheDuration = Duration(minutes: 2);

  Future<void> _fetchJobs({bool forceRefresh = false}) async {
    // [개선] 2분 이내 재요청 방지
    if (!forceRefresh &&
        _lastJobsFetch != null &&
        DateTime.now().difference(_lastJobsFetch!) < _jobsCacheDuration &&
        _jobs.isNotEmpty) {
      return;
    }

    _addLog('API: Fetching recommendations...');
    setState(() => _jobs = []);

    final result = await _apiService.fetchJobs();
    if (result.isSuccess) {
      setState(() => _jobs = result.data ?? []);
      _lastJobsFetch = DateTime.now();
      _addLog('API: Loaded ${_jobs.length} jobs.');
      // [수정] 서버 안내 메시지 (이력서 미완성 등) 표시
      if (result.message != null && _jobs.isEmpty) {
        _showDialog('알림', result.message!);
      }
    } else {
      _addLog('API Error: ${result.errorMessage}');
      if (result.errorMessage != null &&
          !result.errorMessage!.startsWith('HTTP') &&
          !result.errorMessage!.startsWith('Network')) {
        _showDialog('알림', result.errorMessage!);
      }
    }
  }

  Future<void> _resetResume() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          '초기화',
          style: TextStyle(fontSize: AppConfig.fontSizeBody),
        ),
        content: const Text(
          '정말로 이력서와 대화 내용을 모두 초기화하시겠습니까?',
          style: TextStyle(fontSize: AppConfig.fontSizeCaption),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              '취소',
              style: TextStyle(fontSize: AppConfig.fontSizeCaption),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              '확인',
              style: TextStyle(
                color: Colors.red,
                fontSize: AppConfig.fontSizeCaption,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    _addLog('API: Requesting resume reset...');
    final result = await _apiService.resetResume();

    if (result.isSuccess) {
      _addLog('API: Resume reset successful.');
      _showDialog('알림', '이력서가 초기화되었습니다.');
      _wsService.send({'type': 'sync_resume', 'user_id': _userId});
      setState(() {
        _transcript = '';
        _aiResponse = '';
        _currentIndex = 1;
      });
    } else {
      _addLog('API Reset Error: ${result.errorMessage}');
    }
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontSize: AppConfig.fontSizeBody),
        ),
        content: Text(
          content,
          style: const TextStyle(fontSize: AppConfig.fontSizeCaption),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            // [개선] 다이얼로그 버튼 크기 상향
            child: const Text(
              '확인',
              style: TextStyle(fontSize: AppConfig.fontSizeCaption),
            ),
          ),
        ],
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _fetchJobs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Silver Voice',
          style: TextStyle(
            color: Colors.blue[600],
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
        actions: [
          // [개선] 디버그 토글 버튼에 Semantics 적용
          Semantics(
            label: '디버그 모드 ${_debugMode ? "끄기" : "켜기"}',
            button: true,
            child: IconButton(
              icon: Icon(
                LucideIcons.bell,
                color: _debugMode ? Colors.blue[600] : Colors.grey[400],
              ),
              onPressed: () => setState(() => _debugMode = !_debugMode),
            ),
          ),
        ],
      ),
      // [수정] StackFit.expand로 변경하여 자식이 화면 전체 폭을 차지하도록 수정
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBody(),
          if (_debugMode)
            DebugPanel(
              wsStatus: _wsService.status,
              logs: _logs,
              onClose: () => setState(() => _debugMode = false),
            ),
        ],
      ),
      // [개선] 네비게이션 바 아이템에 시니어 폰트 크기 적용
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[600],
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          // [개선] 네비게이션 라벨 크기 상향 (10 → 12)
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.briefcase), label: '일자리'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.fileText), label: '이력서 관리'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: '마이페이지'),
        ],
      ),
    );
  }

  // [개선] 각 탭을 독립 위젯으로 분리하여 호출
  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return JobsTab(
          jobs: _jobs,
          onFetchJobs: () => _fetchJobs(forceRefresh: true),
          onNavigateToHome: () => _onTabTapped(1),
          onApply: (title) => _showDialog('지원 완료', '$title 공고에 지원을 요청했습니다.'),
        );
      case 1:
        return HomeTab(
          wsStatus: _wsService.status,
          transcript: _transcript,
          aiResponse: _aiResponse,
          missingKorean: _missingKorean,
          onStartRecording: _startRecording,
          onStopRecording: _stopRecording,
          onReconnect: () {
            _wsService.resetReconnectAttempts();
            _wsService.disconnect();
            _wsService.connect();
          },
          onNavigateToJobs: () => _onTabTapped(0),
        );
      case 2:
        return ResumeTab(
          resume: _resume,
          missingKorean: _missingKorean,
          onReset: _resetResume,
          onNavigateToHome: () => _onTabTapped(1),
          // [수정] 이력서 필드 직접 편집 콜백
          onFieldChanged: (key, value) {
            setState(() {
              _resume ??= {};
              _resume![key] = key == 'age' ? (int.tryParse(value) ?? 0) : value;
            });
          },
          onSave: () {
            _addLog('Resume: 수동 저장 요청');
            _wsService.send({
              'type': 'update_resume',
              'user_id': _userId,
              'resume': _resume,
            });
            _wsService.send({'type': 'sync_resume', 'user_id': _userId});
          },
        );
      case 3:
        return MyPageTab(
          resume: _resume,
          jobCount: _jobs.length,
          onNavigateToResume: () => _onTabTapped(2),
          onResetResume: _resetResume,
          onToggleDebug: () => setState(() => _debugMode = !_debugMode),
          notificationEnabled: _notificationEnabled,
          onNotificationToggle: (val) => setState(() => _notificationEnabled = val),
        );
      default:
        return HomeTab(
          wsStatus: _wsService.status,
          transcript: _transcript,
          aiResponse: _aiResponse,
          missingKorean: _missingKorean,
          onStartRecording: _startRecording,
          onStopRecording: _stopRecording,
          onReconnect: () {
            _wsService.resetReconnectAttempts();
            _wsService.disconnect();
            _wsService.connect();
          },
          onNavigateToJobs: () => _onTabTapped(0),
        );
    }
  }
}
