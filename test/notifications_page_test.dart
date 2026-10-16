import 'package:fieldtask_pro/features/interventions/domain/intervention.dart';
import 'package:fieldtask_pro/features/notifications/domain/reminder_use_cases.dart';
import 'package:fieldtask_pro/features/notifications/presentation/notifications_cubit.dart';
import 'package:fieldtask_pro/features/notifications/presentation/notifications_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScheduledReminders extends Fake implements GetScheduledReminders {
  @override
  Future<List<(Intervention, DateTime)>> call(String technicianId) async => [];
}

void main() {
  testWidgets('la page Notifications fournit son Cubit à son contenu',
      (tester) async {
    await tester.pumpWidget(
      BlocProvider<NotificationsCubit>(
        create: (_) => NotificationsCubit(
          _ScheduledReminders(),
          technicianId: 'techfix-demo-1',
        )..load(),
        child: const MaterialApp(home: NotificationsPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('Aucun rappel à venir'), findsOneWidget);
  });
}
