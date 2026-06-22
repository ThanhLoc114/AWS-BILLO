import 'picked_image.dart';
import 'image_picker_stub.dart'
    if (dart.library.html) 'image_picker_web.dart'
    as implementation;

Future<PickedImage?> pickImage() => implementation.pickImage();
