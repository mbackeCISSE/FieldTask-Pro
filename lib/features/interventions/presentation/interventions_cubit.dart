import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../domain/intervention.dart';
import '../domain/intervention_use_cases.dart';
import '../domain/intervention_attachment.dart';
import '../domain/capture_intervention_photo.dart';
import '../../notifications/domain/reminder_use_cases.dart';
import '../../synchronization/domain/sync_gateway.dart';
import '../../synchronization/domain/sync_use_cases.dart';

class InterventionsState {
  const InterventionsState(
      {this.items = const [],
      this.loading = true,
      this.error,
      this.filter,
      this.query = '',
      this.pending = 0,
      this.syncSnapshot = const SyncSnapshot()});
  final List<Intervention> items;
  final bool loading;
  final String? error;
  final WorkStatus? filter;
  final String query;
  final int pending;
  final SyncSnapshot syncSnapshot;
  InterventionsState copyWith(
          {List<Intervention>? items,
          bool? loading,
          String? error,
          WorkStatus? filter,
          bool clearFilter = false,
          String? query,
          int? pending,
          SyncSnapshot? syncSnapshot,
          bool clearError = false}) =>
      InterventionsState(
          items: items ?? this.items,
          loading: loading ?? this.loading,
          error: clearError ? null : (error ?? this.error),
          filter: clearFilter ? null : (filter ?? this.filter),
          query: query ?? this.query,
          pending: pending ?? this.pending,
          syncSnapshot: syncSnapshot ?? this.syncSnapshot);
}

class InterventionsCubit extends Cubit<InterventionsState> {
  InterventionsCubit(this.useCases, this.synchronization,
      this.capturePhotoUseCase, this.refreshReminders,
      {this.technicianId = 'techfix-demo-1'})
      : super(const InterventionsState()) {
    _syncSubscription = synchronization.snapshots.listen((snapshot) {
      emit(state.copyWith(syncSnapshot: snapshot, pending: snapshot.pending));
      if (!snapshot.syncing && snapshot.serverAvailable) {
        unawaited(_refreshAfterSynchronization());
      }
    });
  }
  final InterventionUseCases useCases;
  final SynchronizationUseCases synchronization;
  final CaptureInterventionPhoto capturePhotoUseCase;
  final RefreshInterventionReminders refreshReminders;
  final String technicianId;
  late final StreamSubscription<SyncSnapshot> _syncSubscription;

  Future<List<Intervention>> _assignedInterventions() async =>
      (await useCases.getSnapshot())
          .where((item) => item.assignedTechnicianId == technicianId)
          .toList(growable: false);

  Future<void> _refreshAfterSynchronization() async {
    try {
      await refreshReminders(await _assignedInterventions());
      await refresh();
    } catch (error) {
      emit(state.copyWith(
          error: 'Mise à jour après synchronisation impossible : $error'));
    }
  }

  @override
  Future<void> close() async {
    await _syncSubscription.cancel();
    return super.close();
  }

  Future<List<int>?> capturePhoto() => capturePhotoUseCase();
  Future<List<Intervention>> allInterventions() => useCases.getSnapshot();
  Future<List<InterventionAttachment>> attachments(String id) =>
      useCases.getAttachments(id);
  Future<void> saveAttachment(String id, String kind, List<int> bytes,
          {required String extension}) =>
      useCases.saveAttachment(id, kind, bytes, extension: extension);
  Future<void> synchronize() async {
    await synchronization.synchronize();
    await refreshReminders(await _assignedInterventions());
    await refresh();
  }

  Future<void> retryFailedOperations() async {
    await synchronization.retryFailed();
    await refresh();
  }

  Future<void> acceptServerConflicts() async {
    try {
      await synchronization.acceptServerVersionForConflicts();
      await refreshReminders(await _assignedInterventions());
      await refresh();
    } catch (error) {
      emit(state.copyWith(error: 'Conflit non résolu : $error'));
    }
  }

  Future<void> refresh(
      {WorkStatus? filter, String? query, bool clearFilter = false}) async {
    emit(state.copyWith(
        loading: true,
        filter: filter,
        query: query,
        clearFilter: clearFilter,
        clearError: true));
    try {
      final items = await useCases.getInterventions(
          status: state.filter, query: state.query, technicianId: technicianId);
      final syncSnapshot = await synchronization.currentSnapshot();
      emit(state.copyWith(
          items: items,
          loading: false,
          pending: syncSnapshot.pending,
          syncSnapshot: syncSnapshot));
    } catch (e) {
      emit(state.copyWith(
          loading: false, error: 'Chargement local impossible : $e'));
    }
  }

  Future<void> changeStatus(Intervention item, WorkStatus next) async {
    try {
      await useCases.updateStatus(item.id, next);
      await refreshReminders(await _assignedInterventions());
      await refresh();
    } catch (e) {
      emit(state.copyWith(error: _userMessage(e)));
    }
  }

  Future<void> addNote(Intervention item, String note) async {
    try {
      await useCases.addNote(item.id, note);
      await refresh();
    } catch (e) {
      emit(state.copyWith(error: _userMessage(e)));
    }
  }

  String _userMessage(Object error) {
    if (error is StateError || error is ArgumentError) {
      return error.toString().replaceFirst('Bad state: ', '');
    }
    return 'Cette modification n’a pas pu être enregistrée. Réessayez.';
  }
}
