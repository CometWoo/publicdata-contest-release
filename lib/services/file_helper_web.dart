// [개선] 웹 플랫폼용 파일 I/O 구현 — dart:io 없이 동작
import 'dart:typed_data';

final Map<String, Uint8List> _memoryStore = {};

Future<void> writeBytes(String path, Uint8List data) async {
  _memoryStore[path] = data;
}

Future<void> deleteFile(String path) async {
  _memoryStore.remove(path);
}

Future<Uint8List> readBytes(String path) async {
  final data = _memoryStore[path];
  if (data == null) throw Exception('File not found: $path');
  return data;
}
