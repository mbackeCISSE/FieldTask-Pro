import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/widgets/field_task_navigation_bar.dart';
import '../../../auth/presentation/auth_cubit.dart';
import '../../domain/intervention.dart';
import '../interventions_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: BlocBuilder<AuthCubit, AuthState>(
            builder: (context, auth) => Text(
              'Bonjour, ${auth.technician?.name.split(' ').first ?? 'Technicien'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Synchroniser maintenant',
              onPressed: () => context.read<InterventionsCubit>().synchronize(),
              icon: const Icon(Icons.sync),
            ),
            IconButton(
              tooltip: 'Notifications',
              onPressed: () => context.push('/notifications'),
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
        ),
        body: BlocBuilder<InterventionsCubit, InterventionsState>(
          builder: (context, state) => RefreshIndicator(
            onRefresh: () => context.read<InterventionsCubit>().refresh(),
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF123A52),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TECHFIX · ÉQUIPE TERRAIN',
                          style: TextStyle(
                              color: Color(0xFFB5D8D4), fontSize: 11)),
                      const SizedBox(height: 8),
                      Text('${state.items.length} interventions',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                          state.syncSnapshot.syncing
                              ? 'Synchronisation en cours…'
                              : '${state.pending} action(s) en attente',
                          style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                Card(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          BlocBuilder<AuthCubit, AuthState>(
                              builder: (context, auth) => Row(children: [
                                    Icon(
                                        state.syncSnapshot.serverAvailable
                                            ? Icons.cloud_done
                                            : Icons.cloud_off,
                                        color:
                                            state.syncSnapshot.serverAvailable
                                                ? Colors.green
                                                : Colors.orange),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(auth.isLocalDemo
                                            ? 'Démo hors ligne · serveur non utilisé'
                                            : state.syncSnapshot.serverAvailable
                                                ? 'Serveur accessible'
                                                : 'Serveur hors ligne')),
                                    if (state.syncSnapshot.syncing)
                                      const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2)),
                                  ])),
                          if (state.syncSnapshot.lastSuccess != null)
                            Text(
                                'Dernière synchronisation : ${_dateTime(state.syncSnapshot.lastSuccess!)}',
                                style: Theme.of(context).textTheme.bodySmall),
                          if (state.syncSnapshot.lastError != null)
                            Text('Erreur : ${state.syncSnapshot.lastError}',
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 12)),
                          if (state.syncSnapshot.failed > 0)
                            Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: state.syncSnapshot.syncing
                                      ? null
                                      : () => context
                                          .read<InterventionsCubit>()
                                          .retryFailedOperations(),
                                  icon: const Icon(Icons.refresh),
                                  label: Text(
                                      'Réessayer ${state.syncSnapshot.failed} opération(s) échouée(s)'),
                                )),
                          if (state.syncSnapshot.conflicts > 0)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: state.syncSnapshot.syncing
                                    ? null
                                    : () => _acceptServerConflicts(context),
                                icon: const Icon(Icons.cloud_download_outlined),
                                label: Text(
                                    'Conflit : accepter la version serveur (${state.syncSnapshot.conflicts})'),
                              ),
                            ),
                        ]),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    hintText: 'Rechercher une intervention',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    filled: true,
                  ),
                  onChanged: (value) =>
                      context.read<InterventionsCubit>().refresh(query: value),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _filter(context, state, 'Toutes', null),
                    _filter(context, state, 'En attente', WorkStatus.pending),
                    _filter(context, state, 'En cours', WorkStatus.inProgress),
                    _filter(context, state, 'Terminée', WorkStatus.completed),
                  ]),
                ),
                const SizedBox(height: 12),
                if (state.loading && state.items.isEmpty)
                  const Center(child: CircularProgressIndicator())
                else if (state.error != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(state.error!,
                              style: const TextStyle(color: Colors.red)),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: state.loading
                                ? null
                                : () => context
                                    .read<InterventionsCubit>()
                                    .refresh(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer le chargement'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (state.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(30),
                    child: Text('Aucune intervention correspondante.',
                        textAlign: TextAlign.center),
                  )
                else
                  ...state.items.map((item) => InterventionCard(
                        item: item,
                        onTap: () => context.push('/intervention/${item.id}'),
                      )),
              ],
            ),
          ),
        ),
        bottomNavigationBar: buildNavigationBar(context, 0),
      );

  Widget _filter(BuildContext context, InterventionsState state, String label,
          WorkStatus? value) =>
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: state.filter == value,
          onSelected: (_) => context.read<InterventionsCubit>().refresh(
                filter: value,
                clearFilter: value == null,
              ),
        ),
      );

  Future<void> _acceptServerConflicts(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Résoudre les conflits'),
        content: const Text(
            'Les modifications locales en conflit seront abandonnées et remplacées par la version du serveur. Cette action ne peut pas être annulée.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Garder mes modifications')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Utiliser la version serveur')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<InterventionsCubit>().acceptServerConflicts();
    }
  }
}

class InterventionCard extends StatelessWidget {
  const InterventionCard({super.key, required this.item, required this.onTap});
  final Intervention item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = item.priority == WorkPriority.urgent
        ? Colors.red
        : item.priority == WorkPriority.high
            ? Colors.deepOrange
            : const Color(0xFF0D9488);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Text(item.id,
                      style: const TextStyle(fontWeight: FontWeight.bold))),
              Text(item.syncPending ? 'À synchroniser' : 'À jour',
                  style: TextStyle(
                      fontSize: 11,
                      color: item.syncPending
                          ? Colors.orange.shade800
                          : Colors.green.shade700)),
            ]),
            const SizedBox(height: 8),
            Text(item.title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 5),
            Text('${item.client} · ${item.address}',
                style: const TextStyle(color: Colors.black54)),
            Text(
                'Échéance : ${item.dueAt.day.toString().padLeft(2, '0')}/${item.dueAt.month.toString().padLeft(2, '0')} à ${item.dueAt.hour.toString().padLeft(2, '0')}h'),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(30)),
                child: Text(_priorityLabel(item.priority),
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 11)),
              ),
              const Spacer(),
              Text(_status(item.status),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}

String _status(WorkStatus value) => switch (value) {
      WorkStatus.pending => 'En attente',
      WorkStatus.inProgress => 'En cours',
      WorkStatus.completed => 'Terminée',
    };

String _priorityLabel(WorkPriority value) => switch (value) {
      WorkPriority.low => 'Faible',
      WorkPriority.normal => 'Normale',
      WorkPriority.high => 'Élevée',
      WorkPriority.urgent => 'Urgente',
    };

String _dateTime(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
