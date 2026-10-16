import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/reminder_use_cases.dart';
import '../../interventions/domain/intervention.dart';

class NotificationsState {
  const NotificationsState({
    this.items = const [],
    this.loading = true,
    this.error,
  });

  final List<(Intervention, DateTime)> items;
  final bool loading;
  final String? error;
}

class NotificationsCubit extends Cubit<NotificationsState> {
  NotificationsCubit(this.getScheduledReminders, {required this.technicianId})
      : super(const NotificationsState());

  final GetScheduledReminders getScheduledReminders;
  final String technicianId;

  Future<void> load() async {
    emit(const NotificationsState());
    try {
      final items = await getScheduledReminders(technicianId);
      emit(NotificationsState(items: items, loading: false));
    } catch (_) {
      emit(const NotificationsState(
        loading: false,
        error: 'Impossible de charger les notifications.',
      ));
    }
  }
}
