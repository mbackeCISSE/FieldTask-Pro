import 'package:flutter_test/flutter_test.dart';
import 'package:fieldtask_pro/features/interventions/domain/get_interventions.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention_repository.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention_attachment.dart';
import 'package:fieldtask_pro/features/synchronization/domain/sync_retry_policy.dart';
import 'package:fieldtask_pro/features/map/domain/device_coordinates.dart';
import 'package:fieldtask_pro/features/map/domain/get_current_location.dart';
import 'package:fieldtask_pro/features/map/domain/location_repository.dart';

class _Location implements LocationRepository {
  _Location(this.coordinates);
  final DeviceCoordinates coordinates;
  @override
  Future<DeviceCoordinates> currentLocation() async => coordinates;
}

class FakeRepository implements InterventionRepository {
  @override
  Future<List<Intervention>> watchSnapshot() async => [
        Intervention(
            id: 'low',
            title: 'Maintenance',
            client: 'Client B',
            address: 'Thiès',
            description: '',
            equipment: '',
            priority: WorkPriority.low,
            status: WorkStatus.pending,
            dueAt: DateTime(2026),
            latitude: 14,
            longitude: -16,
            assignedTechnicianId: 'technicien-2'),
        Intervention(
            id: 'urgent',
            title: 'Panne routeur',
            client: 'Client A',
            address: 'Dakar',
            description: '',
            equipment: '',
            priority: WorkPriority.urgent,
            status: WorkStatus.pending,
            dueAt: DateTime(2026),
            latitude: 14,
            longitude: -17),
      ];
  @override
  Future<void> updateStatus(String id, WorkStatus status) async {}
  @override
  Future<void> addNote(String id, String note) async {}
  @override
  Future<void> saveAttachment(String id, String kind, List<int> bytes,
      {required String extension}) async {}
  @override
  Future<List<InterventionAttachment>> attachments(String id) async => [];
  @override
  Future<int> pendingOperations() async => 0;
}

void main() {
  test('priorité urgente classée avant faible et recherche dynamique',
      () async {
    final useCase = GetInterventions(FakeRepository());
    expect((await useCase()).map((x) => x.id), ['urgent', 'low']);
    expect((await useCase(query: 'THIÈS')).map((x) => x.id), ['low']);
  });
  test('les interventions sont limitées au technicien demandé', () async {
    final useCase = GetInterventions(FakeRepository());
    expect(
        (await useCase(technicianId: 'techfix-demo-1')).map((item) => item.id),
        ['urgent']);
    expect((await useCase(technicianId: 'technicien-2')).map((item) => item.id),
        ['low']);
    expect((await useCase(technicianId: 'technician-inconnu')), isEmpty);
  });
  test('transitions de statut autorisées et interdites', () {
    expect(Intervention.canMove(WorkStatus.pending, WorkStatus.inProgress),
        isTrue);
    expect(Intervention.canMove(WorkStatus.pending, WorkStatus.completed),
        isFalse);
    expect(Intervention.canMove(WorkStatus.completed, WorkStatus.pending),
        isFalse);
  });

  test('la stratégie de reprise applique des délais progressifs et s’arrête',
      () {
    const policy = SyncRetryPolicy();
    expect(policy.delayAfter(1), const Duration(seconds: 1));
    expect(policy.delayAfter(2), const Duration(seconds: 2));
    expect(policy.delayAfter(4), const Duration(seconds: 8));
    expect(policy.shouldRetry(attempt: 4), isTrue);
    expect(policy.shouldRetry(attempt: 5), isFalse);
    expect(policy.shouldRetry(attempt: 1, statusCode: 409), isFalse);
    expect(policy.shouldRetry(attempt: 1, statusCode: 401), isFalse);
    expect(policy.shouldRetry(attempt: 1, statusCode: 503), isTrue);
    expect(policy.shouldRetry(attempt: 1, statusCode: 429), isTrue);
  });

  test('la position accepte les coordonnées valides aux limites', () async {
    final useCase =
        GetCurrentLocation(_Location(const DeviceCoordinates(90, -180)));
    final result = await useCase();
    expect(result.latitude, 90);
    expect(result.longitude, -180);
  });

  test('la position rejette les coordonnées hors limites et non finies',
      () async {
    for (final coordinates in [
      const DeviceCoordinates(90.01, 0),
      const DeviceCoordinates(0, -180.01),
      const DeviceCoordinates(double.nan, 0),
    ]) {
      final useCase = GetCurrentLocation(_Location(coordinates));
      await expectLater(useCase(), throwsFormatException);
    }
  });
}
