import '../../interventions/domain/intervention.dart';

import 'dart:async';

abstract interface class ReminderGateway {
  Stream<String> get notificationTaps;
  Future<void> initialize();
  Future<void> refresh(List<Intervention> interventions);
  Future<Set<String>> scheduledInterventionIds();
}
