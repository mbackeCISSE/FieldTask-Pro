import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:signature/signature.dart';

import '../../domain/intervention.dart';
import '../../domain/intervention_attachment.dart';
import '../interventions_cubit.dart';

class DetailPage extends StatefulWidget {
  const DetailPage({super.key, required this.id});
  final String id;
  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late Future<List<InterventionAttachment>> attachments;

  @override
  void initState() {
    super.initState();
    attachments = context.read<InterventionsCubit>().attachments(widget.id);
  }

  void reloadAttachments() => setState(() =>
      attachments = context.read<InterventionsCubit>().attachments(widget.id));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Retour',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          title: Text(widget.id),
        ),
        body: BlocBuilder<InterventionsCubit, InterventionsState>(
          builder: (context, state) {
            final matches = state.items.where((item) => item.id == widget.id);
            if (matches.isEmpty) {
              if (state.loading) {
                return const Center(child: CircularProgressIndicator());
              }
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.error ?? 'Intervention introuvable.'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () =>
                            context.read<InterventionsCubit>().refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final item = matches.first;
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(item.title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _info('Statut', _statusLabel(item.status)),
                _info('Priorité', _priorityLabel(item.priority)),
                _info('Client', item.client),
                _info('Adresse', item.address),
                _info('Équipement', item.equipment),
                _info('Description', item.description),
                _info('Rendez-vous',
                    '${item.dueAt.day.toString().padLeft(2, '0')}/${item.dueAt.month.toString().padLeft(2, '0')} à ${item.dueAt.hour.toString().padLeft(2, '0')}h'),
                _info('Notes', item.notes.isEmpty ? 'Aucune note' : item.notes),
                const SizedBox(height: 14),
                if (item.status == WorkStatus.pending)
                  FilledButton(
                      onPressed: () => context
                          .read<InterventionsCubit>()
                          .changeStatus(item, WorkStatus.inProgress),
                      child: const Text('Démarrer intervention')),
                if (item.status == WorkStatus.inProgress)
                  FilledButton(
                      onPressed: () => context
                          .read<InterventionsCubit>()
                          .changeStatus(item, WorkStatus.completed),
                      child: const Text('Terminer intervention')),
                OutlinedButton.icon(
                    onPressed: () => addNote(context, item),
                    icon: const Icon(Icons.note_add_outlined),
                    label: const Text('Ajouter une note')),
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: () => capturePhoto(context, item),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Ajouter une photo')),
                  OutlinedButton.icon(
                      onPressed: () => captureSignature(context, item),
                      icon: const Icon(Icons.draw_outlined),
                      label: const Text('Signature client')),
                ]),
                const Text('Pièces jointes · conservées hors ligne',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                FutureBuilder<List<InterventionAttachment>>(
                  future: attachments,
                  builder: (context, snapshot) {
                    final files = snapshot.data ?? [];
                    if (files.isEmpty)
                      return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Aucune photo ni signature.'));
                    return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: files.map((row) {
                          final path = row.path;
                          final kind = row.kind;
                          return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.file(File(path),
                                    width: 120,
                                    height: 96,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox(
                                            width: 120,
                                            height: 96,
                                            child: Center(
                                                child: Text(
                                                    'Fichier indisponible')))),
                                Text(kind == 'photo' ? 'Photo' : 'Signature',
                                    style: const TextStyle(fontSize: 12)),
                                Text(_attachmentSyncLabel(row.syncState),
                                    style: const TextStyle(fontSize: 10)),
                              ]);
                        }).toList());
                  },
                ),
                Text(
                    item.syncPending
                        ? 'Modification locale · synchronisation en attente'
                        : 'Données synchronisées',
                    style: const TextStyle(color: Colors.black54)),
              ],
            );
          },
        ),
      );

  Widget _info(String label, String value) => Card(
          child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value),
        ]),
      ));

  Future<void> addNote(BuildContext context, Intervention item) async {
    final controller = TextEditingController();
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (dialogContext, setDialogState) => AlertDialog(
                title: const Text('Nouvelle note'),
                content: TextField(
                    controller: controller,
                    maxLines: 4,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: const InputDecoration(
                        hintText: 'Observations du technicien')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: controller.text.trim().isNotEmpty
                          ? () => Navigator.pop(dialogContext, true)
                          : null,
                      child: const Text('Enregistrer'))
                ],
              ),
            ));
    if (saved == true && context.mounted)
      await context.read<InterventionsCubit>().addNote(item, controller.text);
    controller.dispose();
  }

  Future<void> capturePhoto(BuildContext context, Intervention item) async {
    try {
      final bytes = await context.read<InterventionsCubit>().capturePhoto();
      if (bytes == null) return;
      await context
          .read<InterventionsCubit>()
          .saveAttachment(item.id, 'photo', bytes, extension: 'jpg');
      if (mounted) reloadAttachments();
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Photo impossible : $error')));
    }
  }

  Future<void> captureSignature(BuildContext context, Intervention item) async {
    final controller = SignatureController(
        penStrokeWidth: 3,
        penColor: const Color(0xFF123A52),
        exportBackgroundColor: Colors.white);
    final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
              builder: (dialogContext, setDialogState) {
                controller.onDrawEnd = () => setDialogState(() {});
                return AlertDialog(
                  title: const Text('Signature du client'),
                  content: SizedBox(
                      height: 220,
                      width: 320,
                      child: Signature(
                          controller: controller,
                          backgroundColor: Colors.white)),
                  actions: [
                    TextButton(
                        onPressed: () {
                          controller.clear();
                          setDialogState(() {});
                        },
                        child: const Text('Effacer')),
                    TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Annuler')),
                    FilledButton(
                        onPressed: controller.isNotEmpty
                            ? () => Navigator.pop(dialogContext, true)
                            : null,
                        child: const Text('Confirmer'))
                  ],
                );
              },
            ));
    if (saved == true) {
      try {
        final bytes = await controller.toPngBytes();
        if (bytes != null) {
          await context
              .read<InterventionsCubit>()
              .saveAttachment(item.id, 'signature', bytes, extension: 'png');
          if (mounted) reloadAttachments();
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Signature impossible : $error')));
        }
      }
    }
    controller.dispose();
  }
}

String _statusLabel(WorkStatus status) => switch (status) {
      WorkStatus.pending => 'En attente',
      WorkStatus.inProgress => 'En cours',
      WorkStatus.completed => 'Terminée',
    };

String _priorityLabel(WorkPriority priority) => switch (priority) {
      WorkPriority.low => 'Faible',
      WorkPriority.normal => 'Normale',
      WorkPriority.high => 'Élevée',
      WorkPriority.urgent => 'Urgente',
    };

String _attachmentSyncLabel(String syncState) => switch (syncState) {
      'pending' => 'En attente d’envoi',
      'retry' => 'Nouvel essai prévu',
      'sending' => 'Envoi en cours',
      'synced' => 'Synchronisée',
      'failed' => 'Échec · à réessayer',
      _ => 'État inconnu',
    };
