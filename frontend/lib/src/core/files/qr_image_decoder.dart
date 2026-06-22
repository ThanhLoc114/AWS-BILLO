import 'dart:typed_data';

import 'package:image/image.dart' as image_library;
import 'package:zxing2/qrcode.dart';

import 'picked_image.dart';

class QrImageDecoder {
  static String decode(PickedImage pickedImage) {
    final decoded = image_library.decodeImage(pickedImage.bytes);
    if (decoded == null) {
      throw const FormatException('Không đọc được định dạng ảnh QR');
    }

    // QR images exported by a canvas often have a transparent background and
    // no quiet zone. Composite transparency onto white and add a border before
    // decoding so those files remain readable.
    final padding =
        (decoded.width < decoded.height ? decoded.width : decoded.height) ~/ 16;
    final image = image_library.copyExpandCanvas(
      decoded.convert(numChannels: 4),
      padding: padding.clamp(12, 96),
      backgroundColor: image_library.ColorRgba8(255, 255, 255, 255),
    );

    final pixels = Int32List(image.width * image.height);
    var offset = 0;
    for (final pixel in image) {
      final alpha = pixel.a.toInt();
      final red = ((pixel.r * alpha + 255 * (255 - alpha)) / 255).round();
      final green = ((pixel.g * alpha + 255 * (255 - alpha)) / 255).round();
      final blue = ((pixel.b * alpha + 255 * (255 - alpha)) / 255).round();
      pixels[offset++] = (red << 16) | (green << 8) | blue;
    }

    final source = RGBLuminanceSource(image.width, image.height, pixels);
    final hints = DecodeHints()..put(DecodeHintType.tryHarder);
    final sources = <LuminanceSource>[source, InvertedLuminanceSource(source)];
    for (final candidate in sources) {
      for (final binarizer in <Binarizer Function(LuminanceSource)>[
        HybridBinarizer.new,
        GlobalHistogramBinarizer.new,
      ]) {
        try {
          return QRCodeReader()
              .decode(BinaryBitmap(binarizer(candidate)), hints: hints)
              .text;
        } catch (_) {
          // Try the next binarization strategy.
        }
      }
    }
    throw const FormatException('Không tìm thấy mã QR hợp lệ trong ảnh');
  }
}
