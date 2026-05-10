// [개선] 네이티브(Android/iOS/Desktop) 플랫폼용 파일 I/O 구현
import 'dart:io';
import 'dart:typed_data';

Future<void> writeBytes(String path, Uint8List data) async {
  final file = File(path);
  await file.writeAsBytes(data);
}

Future<void> deleteFile(String path) async {
  try {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // 파일 삭제 실패는 무시 — OS가 temp 정리
  }
}

Future<Uint8List> readBytes(String path) async {
  final file = File(path);
  return await file.readAsBytes();
}
