import 'photo_capture_repository.dart';

class CaptureInterventionPhoto {
  const CaptureInterventionPhoto(this.repository);
  final PhotoCaptureRepository repository;

  Future<List<int>?> call() => repository.capturePhoto();
}
