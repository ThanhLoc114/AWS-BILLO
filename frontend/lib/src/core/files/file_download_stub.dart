import 'dart:typed_data';

Future<void> downloadFile({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) async {
  throw UnsupportedError('Tải file hiện chỉ hỗ trợ Flutter Web');
}
