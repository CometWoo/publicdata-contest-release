import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:lucide_icons/lucide_icons.dart';

const String serverUrl = 'https://0oof8muhxkpy97-8000.proxy.runpod.net/';
const String wsUrl = 'wss://0oof8muhxkpy97-8000.proxy.runpod.net/voice/ws';

void main() {
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
        fontFamily: 'Roboto', // 필요시 한글 폰트로 변경 가능
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
  int _currentIndex = 1; // 0: Jobs, 1: Home, 2: Resume, 3: MyPage
  String wsStatus = 'disconnected'; // disconnected, connecting, ready, recording, processing, speaking
  bool debugMode = false;
  List<String> logs = [];

  // 데이터 상태
  Map<String, dynamic>? resume;
  List<String> missingKorean = [];
  List<dynamic> jobs = [];
  String transcript = '';
  String aiResponse = '';

  final String userId = 'test-user-001';
  WebSocketChannel? _channel;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<String> playQueue = [];
  bool isPlaying = false;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();

    _audioPlayer.onPlayerComplete.listen((event) {
      isPlaying = false;
      if (playQueue.isNotEmpty) {
        _playNextAudio();
      } else if (wsStatus == 'speaking') {
        setState(() => wsStatus = 'ready');
      }
    });
  }

  @override
  void dispose() {
    _channel?.sink.close();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _addLog(String msg) {
    debugPrint(msg);
    setState(() {
      logs.add('[${DateTime.now().toIso8601String().substring(11, 19)}] $msg');
      if (logs.length > 15) logs.removeAt(0);
    });
  }

  // --- WebSocket 연결 관리 ---
  void _connectWebSocket() {
    if (_channel != null) return;

    setState(() => wsStatus = 'connecting');
    _addLog('WS: Connecting to server...');

    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _addLog('WS: Connected successfully');

      _channel!.stream.listen(
        (message) async {
          if (message is String) {
            final msg = jsonDecode(message);
            switch (msg['type']) {
              case 'ready':
                _addLog('WS: Server is ready. Requesting sync_resume...');
                _channel!.sink.add(jsonEncode({'type': 'sync_resume', 'user_id': userId}));
                setState(() => wsStatus = 'ready');
                break;
              case 'resume_state':
              case 'resume_updated':
                _addLog('WS: Resume updated.');
                setState(() {
                  resume = msg['resume'];
                  missingKorean = List<String>.from(msg['missing_korean'] ?? []);
                });
                break;
              case 'transcript':
                _addLog('STT: ${msg['text']}');
                setState(() {
                  transcript = msg['text'];
                  aiResponse = '';
                  wsStatus = 'processing';
                });
                break;
              case 'llm_token':
                setState(() => aiResponse += msg['text']);
                break;
              case 'reply_done':
                _addLog('WS: AI reply finished.');
                if (!isPlaying && playQueue.isEmpty) {
                  setState(() => wsStatus = 'ready');
                }
                break;
              case 'error':
                _addLog('WS Error: ${msg['msg']}');
                setState(() => wsStatus = 'ready');
                _showDialog('서버 에러', msg['msg']);
                break;
              default:
                _addLog('WS: Unknown message type: ${msg['type']}');
            }
          } else {
            // Binary (TTS Audio chunk)
            _addLog('WS: Received audio chunk');
            
            // 임시 파일로 저장 후 재생
            final tempDir = await getTemporaryDirectory();
            final tempFile = File('${tempDir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.mp3');
            await tempFile.writeAsBytes(message as List<int>);
            
            playQueue.add(tempFile.path);
            _playNextAudio();
          }
        },
        onDone: () {
          _addLog('WS: Disconnected');
          setState(() {
            wsStatus = 'disconnected';
            _channel = null;
          });
        },
        onError: (err) {
          _addLog('WS: Network Error occurred - $err');
          setState(() {
            wsStatus = 'disconnected';
            _channel = null;
          });
        },
      );
    } catch (e) {
      _addLog('WS Connect Error: $e');
      setState(() => wsStatus = 'disconnected');
    }
  }

  // --- 오디오 재생 (TTS) ---
  Future<void> _playNextAudio() async {
    if (isPlaying || playQueue.isEmpty) return;

    isPlaying = true;
    setState(() => wsStatus = 'speaking');
    
    final filePath = playQueue.removeAt(0);
    try {
      await _audioPlayer.play(DeviceFileSource(filePath));
    } catch (e) {
      _addLog('Audio Play Error: $e');
      isPlaying = false;
      _playNextAudio();
    }
  }

  // --- 녹음 로직 (STT) ---
  Future<void> _startRecording() async {
    if (wsStatus != 'ready') {
      _addLog('Cannot record: Server is not ready.');
      return;
    }

    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/turn_audio.wav';
        
        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.wav),
          path: path,
        );

        setState(() {
          wsStatus = 'recording';
          transcript = '';
          aiResponse = '';
        });
        _addLog('MIC: Recording started...');
      } else {
        _showDialog('권한 오류', '마이크 권한을 허용해주세요.');
      }
    } catch (err) {
      _addLog('MIC Error: $err');
    }
  }

  Future<void> _stopRecording() async {
    if (wsStatus == 'recording') {
      final path = await _audioRecorder.stop();
      _addLog('MIC: Recording stopped.');

      if (path != null && _channel != null) {
        final bytes = await File(path).readAsBytes();
        _addLog('Send: type=turn & audio binary data');
        
        // 텍스트 JSON 전송 후 바이너리 전송
        _channel!.sink.add(jsonEncode({'type': 'turn', 'user_id': userId}));
        _channel!.sink.add(bytes);

        setState(() => wsStatus = 'processing');
      }
    }
  }

  // --- API 호출: 일자리 추천 ---
  Future<void> _fetchJobs() async {
    _addLog('API: Fetching recommendations...');
    setState(() => jobs = []);

    try {
      final res = await http.post(Uri.parse('$serverUrl/recommend/$userId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data['recommendations'] != null && data['recommendations'].isNotEmpty) {
          setState(() => jobs = data['recommendations']);
          _addLog('API: Loaded ${jobs.length} jobs.');
        } else if (data['message'] != null) {
          _addLog('API MSG: ${data['message']}');
          _showDialog('알림', data['message']);
        }
      } else {
        _addLog('API Error: Status ${res.statusCode}');
      }
    } catch (err) {
      _addLog('API Fetch Error: $err');
    }
  }

  // --- API 호출: 이력서 초기화 ---
  Future<void> _resetResume() async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초기화'),
        content: const Text('정말로 이력서와 대화 내용을 모두 초기화하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('확인', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    _addLog('API: Requesting resume reset...');
    try {
      final res = await http.delete(Uri.parse('$serverUrl/resume/$userId'));
      if (res.statusCode == 200) {
        _addLog('API: Resume reset successful.');
        _showDialog('알림', '이력서가 초기화되었습니다.');
        
        _channel?.sink.add(jsonEncode({'type': 'sync_resume', 'user_id': userId}));
        setState(() {
          transcript = '';
          aiResponse = '';
          _currentIndex = 1; // 홈으로 이동
        });
      }
    } catch (err) {
      _addLog('API Reset Error: $err');
    }
  }

  void _showDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))
        ],
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    if (index == 0) _fetchJobs(); // 일자리 탭
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('Silver Voice', style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.w900, fontSize: 22)),
        actions: [
          IconButton(
            icon: Icon(LucideIcons.bell, color: debugMode ? Colors.blue[600] : Colors.grey[400]),
            onPressed: () => setState(() => debugMode = !debugMode),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: _buildBody(),
              ),
            ],
          ),
          if (debugMode) _buildDebugPanel(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue[600],
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
        items: const [
          BottomNavigationBarItem(icon: Icon(LucideIcons.briefcase), label: '일자리'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.fileText), label: '이력서 관리'),
          BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: '마이페이지'),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0: return _buildJobsTab();
      case 1: return _buildHomeTab();
      case 2: return _buildResumeTab();
      case 3: return _buildMyPageTab();
      default: return _buildHomeTab();
    }
  }

  // --- Home Tab ---
  Widget _buildHomeTab() {
    Color micColor = Colors.blue[500]!;
    if (wsStatus == 'disconnected') micColor = Colors.grey[400]!;
    if (wsStatus == 'recording') micColor = Colors.red[500]!;
    if (wsStatus == 'speaking') micColor = Colors.green[500]!;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('음성만으로\n이력서를 완성하세요', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('어려운 글쓰기 없이,\n편하게 말씀만 하시면 됩니다.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 40),

          // 🔴 메인 녹음 버튼
          GestureDetector(
            onTapDown: (_) => _startRecording(),
            onTapUp: (_) => _stopRecording(),
            onTapCancel: () => _stopRecording(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: wsStatus == 'recording' ? 140 : 120,
              height: wsStatus == 'recording' ? 140 : 120,
              decoration: BoxDecoration(
                color: micColor,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: micColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)],
              ),
              child: const Icon(LucideIcons.mic, color: Colors.white, size: 48),
            ),
          ),
          const SizedBox(height: 24),

          // 상태 메시지
          if (wsStatus == 'disconnected') ...[
            const Text('서버와 연결이 끊어졌습니다.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            TextButton(onPressed: _connectWebSocket, child: const Text('재연결 시도'))
          ] else if (wsStatus == 'recording') ...[
            Text('말씀을 듣고 있습니다...', style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold))
          ] else if (wsStatus == 'processing') ...[
            const Text('AI가 생각하는 중입니다...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))
          ] else if (wsStatus == 'speaking') ...[
            const Text('AI가 답변하고 있습니다...', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))
          ] else ...[
            const Text('버튼을 누른 채로 대화를 시작하세요', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500))
          ],

          // 대화 내용
          if (transcript.isNotEmpty || aiResponse.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 32),
              padding: const EdgeInsets.all(16),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (transcript.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('나: $transcript', style: const TextStyle(fontWeight: FontWeight.bold))),
                  if (aiResponse.isNotEmpty) Text('AI: $aiResponse', style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold)),
                ],
              ),
            ),

          if (missingKorean.isNotEmpty && wsStatus == 'ready')
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text('남은 항목: ${missingKorean.join(', ')}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ),

          const Spacer(),
          // 추천 유도 카드
          GestureDetector(
            onTap: () => _onTabTapped(0),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('어르신 맞춤 일자리', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800])),
                      const SizedBox(height: 4),
                      Text('이력서를 작성하시면 딱 맞는 일자리를 추천해 드려요.', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                  Icon(LucideIcons.chevronRight, color: Colors.blue[500]),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- Resume Tab ---
  Widget _buildResumeTab() {
    final Map<String, String> labels = {
      'name': '성명', 'age': '연령', 'location': '거주지',
      'career': '최근 직장명 (경력)', 'preferred_work_type': '희망 근무 형태', 'physical_condition': '건강 상태'
    };

    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('어르신의', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[600])),
                  const Text('멋진 이력서입니다!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ],
              ),
              GestureDetector(
                onTap: _resetResume,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      Icon(LucideIcons.trash2, size: 16, color: Colors.red[500]),
                      const SizedBox(width: 4),
                      Text('초기화', style: TextStyle(color: Colors.red[500], fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
              child: ListView(
                children: [
                  ...labels.keys.map((key) {
                    final val = resume?[key]?.toString();
                    final isMissing = missingKorean.contains({
                      'name': '이름', 'age': '나이', 'location': '거주지', 'career': '경력',
                      'preferred_work_type': '희망 근무형태', 'physical_condition': '건강 상태/체력'
                    }[key]);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(labels[key]!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (!isMissing && val != null && val.isNotEmpty) ...[
                                Text(key == 'age' ? '${val}세' : val, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 18),
                              ] else ...[
                                const Text('홈에서 음성으로 입력해주세요', style: TextStyle(color: Colors.grey, fontSize: 14)),
                              ]
                            ],
                          ),
                          const Divider(height: 20, color: Color(0xFFF5F5F5)),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => _onTabTapped(1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue[600],
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: const Text('음성으로 이력서 채우러 가기', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // --- Jobs Tab ---
  Widget _buildJobsTab() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['AI 추천', '우리 동네', '경비/보안', '돌봄/요양'].map((tag) => 
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: _fetchJobs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey[200]!)),
                      child: Text(tag, style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                )
              ).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: jobs.isNotEmpty ? ListView.builder(
              itemCount: jobs.length,
              itemBuilder: (ctx, i) {
                final job = jobs[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[100]!)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                        child: Text('AI 매칭 ${job['similarity_score']}%', style: TextStyle(color: Colors.blue[700], fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      const SizedBox(height: 12),
                      Text(job['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${job['company']} · ${job['location']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(job['work_type'], style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold, fontSize: 16)),
                          ElevatedButton(
                            onPressed: () => _showDialog('지원 완료', '${job['title']} 공고에 지원을 요청했습니다.'),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[600], elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                            child: const Text('지원하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      if (job['reason'] != null)
                        Container(
                          margin: const EdgeInsets.only(top: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                          child: Text('💡 ${job['reason']}', style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.5)),
                        )
                    ],
                  ),
                );
              },
            ) : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.briefcase, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('추천된 일자리가 없습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('이력서 작성이 완료되지 않았거나,\n조건에 맞는 공고가 없습니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => _onTabTapped(1),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[100], elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                  child: Text('이력서 작성하기', style: TextStyle(color: Colors.blue[600], fontWeight: FontWeight.bold)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  // --- MyPage Tab ---
  Widget _buildMyPageTab() {
    return Container(
      color: Colors.grey[50],
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(resume?['name'] ?? '회원', style: TextStyle(color: Colors.blue[600], fontSize: 24, fontWeight: FontWeight.bold)),
                        const Text('님,', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text('오늘도 활기찬 하루 보내세요!', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: Colors.blue[50], shape: BoxShape.circle),
                  child: Icon(LucideIcons.user, size: 32, color: Colors.blue[500]),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      const Text('지원한 일자리', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('0', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[600])),
                          const Text('건', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      const Text('관심 일자리', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text('${jobs.length}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue[600])),
                          const Text('건', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                _buildListTile('내 이력서 확인하기', onTap: () => _onTabTapped(2)),
                _buildListTile('이력서 및 대화 초기화', onTap: _resetResume, isDanger: true),
                _buildListTile('일자리 추천 알림', isToggle: true, defaultOn: true),
                _buildListTile('고객센터 (디버그 켜기)', onTap: () => setState(() => debugMode = !debugMode)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildListTile(String title, {VoidCallback? onTap, bool isDanger = false, bool isToggle = false, bool defaultOn = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDanger ? Colors.red : Colors.black87)),
            if (isToggle)
              Container(
                width: 48, height: 24,
                decoration: BoxDecoration(color: defaultOn ? Colors.blue[500] : Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                alignment: defaultOn ? Alignment.centerRight : Alignment.centerLeft,
                padding: const EdgeInsets.all(2),
                child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
              )
            else
              Icon(LucideIcons.chevronRight, size: 20, color: isDanger ? Colors.red[300] : Colors.grey[400])
          ],
        ),
      ),
    );
  }

  // --- Debug Panel ---
  Widget _buildDebugPanel() {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xEE111111),
          border: Border(top: BorderSide(color: Colors.grey, width: 4))
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(width: 8, height: 8, decoration: BoxDecoration(color: wsStatus == 'disconnected' ? Colors.red : Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Text('Debug Console [$wsStatus]', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                InkWell(
                  onTap: () => setState(() => debugMode = false),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(4)), child: const Text('닫기', style: TextStyle(color: Colors.white, fontSize: 10))),
                )
              ],
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (ctx, i) => Text(logs[i], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 10)),
              ),
            )
          ],
        ),
      ),
    );
  }
}