import 'package:geolocator/geolocator.dart';

import '../domain/device_coordinates.dart';
import '../domain/location_repository.dart';

class GeolocatorLocationRepository implements LocationRepository {
  @override
  Future<DeviceCoordinates> currentLocation() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Activez le service de localisation.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Permission de localisation refusée.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    return DeviceCoordinates(position.latitude, position.longitude);
  }
}
