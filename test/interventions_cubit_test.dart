import 'package:flutter_test/flutter_test.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention_attachment.dart';
import 'package:fieldtask_pro/features/interventions/presentation/interventions_cubit.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention_repository.dart';
import 'package:fieldtask_pro/features/interventions/domain/intervention_use_cases.dart';
import 'package:fieldtask_pro/features/interventions/domain/photo_capture_repository.dart';
import 'package:fieldtask_pro/features/interventions/domain/capture_intervention_photo.dart';
import 'package:fieldtask_pro/features/notifications/domain/reminder_gateway.dart';
import 'package:fieldtask_pro/features/notifications/domain/reminder_use_cases.dart';
import 'package:fieldtask_pro/features/synchronization/domain/sync_gateway.dart';
import 'package:fieldtask_pro/features/synchronization/domain/sync_use_cases.dart';

class _Repository implements InterventionRepository {
  final items = <Intervention>[
    Intervention(
        id: 'TF-1',
        title: 'Panne routeur',
        client: 'TechFix',
        address: 'Dakar',
        description: '',
        equipment: '',
        priority: WorkPriority.urgent,
        status: WorkStatus.pending,
        dueAt: DateTime(2026, 10, 14),
        latitude: 14,
        longitude: -17),
    Intervention(
        id: 'TF-2',
        title: 'Contrôle pompe',
        client: 'Client B',
        address: 'Thiès',
        description: '',
        equipment: '',
        priority: WorkPriority.low,
        status: WorkStatus.completed,
        dueAt: DateTime(2026, 10, 15),
        latitude: 14,
        longitude: -16),
  ];
  @override
  Future<List<Intervention>> watchSnapshot() async => List.of(items);
  @override
  Future<void> updateStatus(String id, WorkStatus status) async {
    final index = items.indexWhere((item) => item.id == id);
    final item = items[index];
    if (!Intervention.canMove(item.status, status))
      throw StateError('Transition invalide');
    items[index] = item.copyWith(status: status, syncPending: true);
  }

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

class _SyncGateway implements SyncGateway {
  @override
  Stream<SyncSnapshot> get snapshots => const Stream.empty();
  @override
  Future<SyncSnapshot> currentSnapshot() async =>
      const SyncSnapshot(pending: 2, serverAvailable: true);
  @override
  Future<void> syncNow() async {}
  @override
  Future<void> retryFailed() async {}
  @override
  Future<void> acceptServerVersionForConflicts() async {}
}

class _PhotoCapture implements PhotoCaptureRepository {
  @override
  Future<List<int>?> capturePhoto() async => null;
}

class _Reminders implements ReminderGateway {
  List<Intervention>? lastSchedule;
  @override
  Stream<String> get notificationTaps => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh(List<Intervention> interventions) async {
    lastSchedule = interventions;
  }
  @override
  Future<Set<String>> scheduledInterventionIds() async => {};
}

void main() {
  test('Cubit applique la recherche et expose l’état de synchronisation',
      () async {
    final repo = _Repository();
    final cubit = InterventionsCubit(
        InterventionUseCases(repo),
        SynchronizationUseCases(_SyncGateway()),
        CaptureInterventionPhoto(_PhotoCapture()),
        RefreshInterventionReminders(_Reminders()));
    await cubit.refresh(query: 'routeur');
    expect(cubit.state.items.map((item) => item.id), ['TF-1']);
    expect(cubit.state.pending, 2);
    expect(cubit.state.syncSnapshot.serverAvailable, isTrue);
    await cubit.close();
  });

  test('changement de statut reprogramme les rappels', () async {
    final repo = _Repository();
    final reminders = _Reminders();
    final cubit = InterventionsCubit(
        InterventionUseCases(repo),
        SynchronizationUseCases(_SyncGateway()),
        CaptureInterventionPhoto(_PhotoCapture()),
        RefreshInterventionReminders(reminders));
    await cubit.refresh();
    await cubit.changeStatus(repo.items.first, WorkStatus.inProgress);
    expect(repo.items.first.status, WorkStatus.inProgress);
    expect(reminders.lastSchedule!.first.status, WorkStatus.inProgress);
    await cubit.close();
  });

  test('la synchronisation limite les rappels au technicien connecté',
      () async {
    final repo = _Repository()
      ..items.add(Intervention(
        id: 'TF-OTHER',
        title: 'Autre technicien',
        client: 'Client C',
        address: 'Dakar',
        description: '',
        equipment: '',
        priority: WorkPriority.high,
        status: WorkStatus.pending,
        dueAt: DateTime(2026, 10, 16),
        latitude: 14,
        longitude: -17,
        assignedTechnicianId: 'another-technician',
      ));
    final reminders = _Reminders();
    final cubit = InterventionsCubit(
      InterventionUseCases(repo),
      SynchronizationUseCases(_SyncGateway()),
      CaptureInterventionPhoto(_PhotoCapture()),
      RefreshInterventionReminders(reminders),
      technicianId: 'techfix-demo-1',
    );

    await cubit.synchronize();

    expect(reminders.lastSchedule!.map((item) => item.id), ['TF-1', 'TF-2']);
    await cubit.close();
  });
}
