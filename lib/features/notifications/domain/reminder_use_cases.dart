import '../../interventions/domain/intervention.dart';
import '../../interventions/domain/intervention_repository.dart';
import 'reminder_gateway.dart';
import 'reminder_schedule.dart';

class RefreshInterventionReminders {
  const RefreshInterventionReminders(this.gateway);
  final ReminderGateway gateway;

  Future<void> call(List<Intervention> interventions) =>
      gateway.refresh(interventions);
}

class GetScheduledReminders {
  const GetScheduledReminders(this.repository, this.gateway);

  final InterventionRepository repository;
  final ReminderGateway gateway;

  Future<List<(Intervention, DateTime)>> call(String technicianId) async {
    await gateway.initialize();
    final scheduledIds = await gateway.scheduledInterventionIds();
    final interventions = await repository.watchSnapshot();
    final now = DateTime.now();
    final reminders = <(Intervention, DateTime)>[];
    for (final item in interventions) {
      if (item.assignedTechnicianId != technicianId ||
          !scheduledIds.contains(item.id)) {
        continue;
      }
      final scheduledAt = ReminderSchedule.scheduledAt(item, now);
      if (scheduledAt != null) reminders.add((item, scheduledAt));
    }
    reminders.sort((a, b) => a.$2.compareTo(b.$2));
    return reminders;
  }
}
