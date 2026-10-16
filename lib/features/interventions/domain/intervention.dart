enum WorkStatus { pending, inProgress, completed }

enum WorkPriority { low, normal, high, urgent }

class Intervention {
  const Intervention(
      {required this.id,
      required this.title,
      required this.client,
      required this.address,
      required this.description,
      required this.equipment,
      required this.priority,
      required this.status,
      required this.dueAt,
      required this.latitude,
      required this.longitude,
      this.assignedTechnicianId = 'techfix-demo-1',
      this.notes = '',
      this.syncPending = false});
  final String id, title, client, address, description, equipment, notes;
  final String assignedTechnicianId;
  final WorkPriority priority;
  final WorkStatus status;
  final DateTime dueAt;
  final double latitude, longitude;
  final bool syncPending;
  Intervention copyWith(
          {WorkStatus? status, String? notes, bool? syncPending}) =>
      Intervention(
          id: id,
          title: title,
          client: client,
          address: address,
          description: description,
          equipment: equipment,
          priority: priority,
          status: status ?? this.status,
          dueAt: dueAt,
          latitude: latitude,
          longitude: longitude,
          assignedTechnicianId: assignedTechnicianId,
          notes: notes ?? this.notes,
          syncPending: syncPending ?? this.syncPending);
  static const priorities = {
    WorkPriority.urgent: 0,
    WorkPriority.high: 1,
    WorkPriority.normal: 2,
    WorkPriority.low: 3
  };
  static bool canMove(WorkStatus from, WorkStatus to) =>
      (from == WorkStatus.pending && to == WorkStatus.inProgress) ||
      (from == WorkStatus.inProgress && to == WorkStatus.completed);
}
