// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:typed_data';

import 'picked_image.dart';

Future<PickedImage?> pickImage() async {
  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..style.display = 'none';
  html.document.body?.append(input);
  try {
    input.click();
    await input.onChange.first;
    if (input.files == null || input.files!.isEmpty) return null;
    final file = input.files!.first;
    if (file.size > 10 * 1024 * 1024) {
      throw const FormatException('Ảnh phải nhỏ hơn 10 MB');
    }
    final extension = file.name.toLowerCase().split('.').last;
    final contentType = switch (file.type.toLowerCase()) {
      'image/png' => 'image/png',
      'image/webp' => 'image/webp',
      'image/jpeg' || 'image/jpg' => 'image/jpeg',
      _ when extension == 'png' => 'image/png',
      _ when extension == 'webp' => 'image/webp',
      _ when extension == 'jpg' || extension == 'jpeg' => 'image/jpeg',
      _ => throw const FormatException('Chỉ hỗ trợ ảnh JPG, PNG hoặc WebP'),
    };
    final reader = html.FileReader()..readAsArrayBuffer(file);
    await reader.onLoad.first;
    final result = reader.result;
    final bytes = switch (result) {
      Uint8List value => value,
      ByteBuffer value => Uint8List.view(value),
      _ => throw const FormatException('Không đọc được dữ liệu ảnh'),
    };
    return PickedImage(name: file.name, contentType: contentType, bytes: bytes);
  } finally {
    input.remove();
  }
}
