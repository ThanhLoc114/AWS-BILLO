import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/src/core/files/picked_image.dart';
import 'package:frontend/src/core/files/qr_image_decoder.dart';
import 'package:image/image.dart' as image_library;
import 'package:zxing2/qrcode.dart';

void main() {
  test('decodes a payment payload from PNG QR image', () {
    const payload = 'walletapp://pay?sessionId=ps_test_001';
    final qrCode = Encoder.encode(payload, ErrorCorrectionLevel.h);
    final matrix = qrCode.matrix!;
    const scale = 12;
    const quietZone = 4;
    final imageSize = (matrix.width + quietZone * 2) * scale;
    final image = image_library.Image(
      width: imageSize,
      height: imageSize,
      numChannels: 4,
    );
    image_library.fill(
      image,
      color: image_library.ColorRgba8(255, 255, 255, 255),
    );
    for (var x = 0; x < matrix.width; x++) {
      for (var y = 0; y < matrix.height; y++) {
        if (matrix.get(x, y) != 1) continue;
        image_library.fillRect(
          image,
          x1: (x + quietZone) * scale,
          y1: (y + quietZone) * scale,
          x2: (x + quietZone + 1) * scale - 1,
          y2: (y + quietZone + 1) * scale - 1,
          color: image_library.ColorRgba8(0, 0, 0, 255),
        );
      }
    }

    final decoded = QrImageDecoder.decode(
      PickedImage(
        name: 'payment.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList(image_library.encodePng(image)),
      ),
    );

    expect(decoded, payload);
  });

  test('decodes transparent QR image without a quiet zone', () {
    const payload = 'walletapp://pay?sessionId=ps_transparent_001';
    final qrCode = Encoder.encode(payload, ErrorCorrectionLevel.h);
    final matrix = qrCode.matrix!;
    const scale = 12;
    final image = image_library.Image(
      width: matrix.width * scale,
      height: matrix.height * scale,
      numChannels: 4,
    );
    for (var x = 0; x < matrix.width; x++) {
      for (var y = 0; y < matrix.height; y++) {
        if (matrix.get(x, y) != 1) continue;
        image_library.fillRect(
          image,
          x1: x * scale,
          y1: y * scale,
          x2: (x + 1) * scale - 1,
          y2: (y + 1) * scale - 1,
          color: image_library.ColorRgba8(0, 0, 0, 255),
        );
      }
    }

    final decoded = QrImageDecoder.decode(
      PickedImage(
        name: 'transparent-payment.png',
        contentType: 'image/png',
        bytes: Uint8List.fromList(image_library.encodePng(image)),
      ),
    );

    expect(decoded, payload);
  });
}
