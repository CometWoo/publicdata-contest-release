// [개선] 조건부 import의 스텁 파일 — 컴파일 시 플랫폼에 맞는 구현으로 대체됨
import 'dart:typed_data';

Future<void> writeBytes(String path, Uint8List data) {
  throw UnsupportedError('Platform not supported');
}

Future<void> deleteFile(String path) {
  throw UnsupportedError('Platform not supported');
}

Future<Uint8List> readBytes(String path) {
  throw UnsupportedError('Platform not supported');
}
