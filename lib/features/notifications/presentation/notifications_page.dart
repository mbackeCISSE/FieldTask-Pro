import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'notifications_cubit.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          leading: IconButton(
            tooltip: 'Retour',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            icon: const Icon(Icons.arrow_back),
          ),
        ),
        body: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            if (state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null) {
              return Center(child: Text(state.error!));
            }
            final reminders = state.items;
            if (reminders.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none, size: 48),
                      SizedBox(height: 12),
                      Text('Aucun rappel à venir',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text(
                        'Les rappels programmés pour vos prochaines interventions apparaîtront ici.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: reminders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final (item, scheduledAt) = reminders[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                        child: Icon(Icons.notifications_active_outlined)),
                    title: Text(item.title),
                    subtitle: Text(
                        '${item.client} · Rappel ${_formatDateTime(scheduledAt)}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/intervention/${item.id}'),
                  ),
                );
              },
            );
          },
        ),
      );

  String _formatDateTime(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} à ${value.hour.toString().padLeft(2, '0')}h${value.minute.toString().padLeft(2, '0')}';
}
