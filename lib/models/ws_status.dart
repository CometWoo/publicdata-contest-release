// [개선] 문자열 리터럴 상태 관리를 enum으로 변경하여 타입 안전성 확보
enum WsStatus {
  disconnected,
  connecting,
  ready,
  recording,
  processing,
  speaking;

  // [개선] 상태별 한글 라벨을 enum에 캡슐화
  String get label {
    switch (this) {
      case WsStatus.disconnected:
        return '서버와 연결이 끊어졌습니다.';
      case WsStatus.connecting:
        return '서버에 연결하는 중입니다...';
      case WsStatus.ready:
        return '버튼을 누른 채로 대화를 시작하세요';
      case WsStatus.recording:
        return '말씀을 듣고 있습니다...';
      case WsStatus.processing:
        return 'AI가 생각하는 중입니다...';
      case WsStatus.speaking:
        return 'AI가 답변하고 있습니다...';
    }
  }

  bool get isInteractive => this == WsStatus.ready;
}
