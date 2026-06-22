import 'dart:typed_data';

import 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart'
    as implementation;

Future<void> downloadFile({
  required Uint8List bytes,
  required String fileName,
  required String contentType,
}) => implementation.downloadFile(
  bytes: bytes,
  fileName: fileName,
  contentType: contentType,
);
