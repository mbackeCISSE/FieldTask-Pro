import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/field_task_navigation_bar.dart';
import 'auth_cubit.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
              tooltip: 'Retour à l’accueil',
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.arrow_back)),
          title: const Text('Profil technicien'),
        ),
        body: BlocBuilder<AuthCubit, AuthState>(builder: (context, state) {
          final technician = state.technician;
          return ListView(padding: const EdgeInsets.all(20), children: [
            const CircleAvatar(radius: 34, child: Icon(Icons.person, size: 36)),
            const SizedBox(height: 12),
            Center(
                child: Text(technician?.name ?? 'Technicien',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold))),
            Center(
                child: Text(
                    '${technician?.role ?? 'Technicien'} · ${technician?.company ?? 'TechFix'}')),
            const SizedBox(height: 24),
            ListTile(
              leading: Icon(state.isLocalDemo
                  ? Icons.cloud_off
                  : Icons.cloud_done_outlined),
              title:
                  Text(state.isLocalDemo ? 'Mode démo local' : 'Session API'),
              subtitle: Text(state.isLocalDemo
                  ? 'Données fictives, synchronisation serveur désactivée.'
                  : 'Session sécurisée enregistrée sur cet appareil.'),
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(state.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            FilledButton.icon(
              onPressed: state.loading
                  ? null
                  : () async {
                      final signedOut =
                          await context.read<AuthCubit>().signOut();
                      if (signedOut && context.mounted) {
                        context.go('/login');
                      }
                    },
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion'),
            ),
          ]);
        }),
        bottomNavigationBar: buildNavigationBar(context, 2),
      );
}
