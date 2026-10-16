import 'device_coordinates.dart';
import 'location_repository.dart';

class GetCurrentLocation {
  const GetCurrentLocation(this.repository);
  final LocationRepository repository;

  Future<DeviceCoordinates> call() async {
    final coordinates = await repository.currentLocation();
    if (!coordinates.latitude.isFinite ||
        !coordinates.longitude.isFinite ||
        coordinates.latitude < -90 ||
        coordinates.latitude > 90 ||
        coordinates.longitude < -180 ||
        coordinates.longitude > 180) {
      throw const FormatException('La position reçue est invalide.');
    }
    return coordinates;
  }
}
