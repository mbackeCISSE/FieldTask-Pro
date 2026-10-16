import '../../interventions/domain/intervention.dart';

/// Pure scheduling policy for intervention due-date reminders.
class ReminderSchedule {
  const ReminderSchedule._();

  static DateTime? scheduledAt(Intervention intervention, DateTime now) {
    if (intervention.status == WorkStatus.completed) return null;

    final oneHourBefore = intervention.dueAt.subtract(const Duration(hours: 1));
    final candidate =
        oneHourBefore.isAfter(now) ? oneHourBefore : intervention.dueAt;
    return candidate.isAfter(now) ? candidate : null;
  }
}
