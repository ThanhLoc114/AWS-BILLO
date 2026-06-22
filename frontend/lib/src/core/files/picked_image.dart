import 'dart:typed_data';

class PickedImage {
  final String name;
  final String contentType;
  final Uint8List bytes;

  const PickedImage({
    required this.name,
    required this.contentType,
    required this.bytes,
  });
}
