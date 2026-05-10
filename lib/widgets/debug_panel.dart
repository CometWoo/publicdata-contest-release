import 'package:flutter/material.dart';
import '../models/ws_status.dart';

// [개선] 디버그 패널을 독립 위젯으로 분리
class DebugPanel extends StatelessWidget {
  final WsStatus wsStatus;
  final List<String> logs;
  final VoidCallback onClose;

  const DebugPanel({
    super.key,
    required this.wsStatus,
    required this.logs,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 220,
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Color(0xEE111111),
          border: Border(top: BorderSide(color: Colors.grey, width: 4)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: wsStatus == WsStatus.disconnected
                            ? Colors.red
                            : Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Debug Console [${wsStatus.name}]',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                // [개선] 닫기 버튼에 Semantics 적용
                Semantics(
                  label: '디버그 패널 닫기',
                  button: true,
                  child: InkWell(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '닫기',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.grey),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (ctx, i) => Text(
                  logs[i],
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
