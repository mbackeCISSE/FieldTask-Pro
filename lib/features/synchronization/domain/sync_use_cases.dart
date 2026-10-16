import 'sync_gateway.dart';

class SynchronizationUseCases {
  const SynchronizationUseCases(this.gateway);
  final SyncGateway gateway;

  Stream<SyncSnapshot> get snapshots => gateway.snapshots;
  Future<SyncSnapshot> currentSnapshot() => gateway.currentSnapshot();
  Future<void> synchronize() => gateway.syncNow();
  Future<void> retryFailed() => gateway.retryFailed();
  Future<void> acceptServerVersionForConflicts() =>
      gateway.acceptServerVersionForConflicts();
}
