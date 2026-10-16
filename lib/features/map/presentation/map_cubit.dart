import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/device_coordinates.dart';
import '../../interventions/domain/get_interventions.dart';
import '../../interventions/domain/intervention.dart';
import '../domain/get_current_location.dart';

class MapState {
  const MapState({this.location, this.loading = false, this.error});
  final DeviceCoordinates? location;
  final bool loading;
  final String? error;
}

class MapCubit extends Cubit<MapState> {
  MapCubit(this.getInterventions, this.getCurrentLocation,
      {this.technicianId = 'techfix-demo-1'})
      : super(const MapState());
  final GetInterventions getInterventions;
  final GetCurrentLocation getCurrentLocation;
  final String technicianId;

  Future<List<Intervention>> loadInterventions() =>
      getInterventions(technicianId: technicianId);

  Future<void> locate() async {
    emit(MapState(location: state.location, loading: true));
    try {
      emit(MapState(location: await getCurrentLocation()));
    } catch (error) {
      final message = error is StateError || error is FormatException
          ? error.toString().replaceFirst('Bad state: ', '')
          : 'Impossible de récupérer votre position. Réessayez.';
      emit(MapState(location: state.location, error: message));
    }
  }
}
