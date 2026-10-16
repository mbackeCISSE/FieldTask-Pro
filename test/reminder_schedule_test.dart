import 'package:fieldtask_pro/features/interventions/domain/intervention.dart';
import 'package:fieldtask_pro/features/notifications/domain/reminder_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 13, 10);

  Intervention intervention({
    DateTime? dueAt,
    WorkStatus status = WorkStatus.pending,
  }) =>
      Intervention(
        id: 'TF-1',
        title: 'Maintenance',
        client: 'TechFix',
        address: 'Dakar',
        description: 'Intervention de contrôle',
        equipment: 'Équipement',
        priority: WorkPriority.normal,
        status: status,
        dueAt: dueAt ?? now.add(const Duration(hours: 3)),
        latitude: 14.7,
        longitude: -17.4,
      );

  test('programme le rappel une heure avant le rendez-vous', () {
    expect(
      ReminderSchedule.scheduledAt(intervention(), now),
      now.add(const Duration(hours: 2)),
    );
  });

  test('si le rappel anticipé est passé, programme à l’heure du rendez-vous',
      () {
    expect(
      ReminderSchedule.scheduledAt(
        intervention(dueAt: now.add(const Duration(minutes: 20))),
        now,
      ),
      now.add(const Duration(minutes: 20)),
    );
  });

  test('ignore les interventions terminées ou dont l’échéance est passée', () {
    expect(
      ReminderSchedule.scheduledAt(
        intervention(status: WorkStatus.completed),
        now,
      ),
      isNull,
    );
    expect(
      ReminderSchedule.scheduledAt(
        intervention(dueAt: now.subtract(const Duration(seconds: 1))),
        now,
      ),
      isNull,
    );
  });
}
