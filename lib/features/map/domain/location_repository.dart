import 'device_coordinates.dart';

abstract interface class LocationRepository {
  Future<DeviceCoordinates> currentLocation();
}
