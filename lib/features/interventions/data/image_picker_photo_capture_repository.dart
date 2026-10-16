import 'package:image_picker/image_picker.dart';

import '../domain/photo_capture_repository.dart';

class ImagePickerPhotoCaptureRepository implements PhotoCaptureRepository {
  ImagePickerPhotoCaptureRepository({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<List<int>?> capturePhoto() async {
    final photo =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 82);
    return photo?.readAsBytes();
  }
}
