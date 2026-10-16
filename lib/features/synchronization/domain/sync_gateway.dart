import 'dart:async';

class SyncSnapshot {
  const SyncSnapshot({
    this.serverAvailable = false,
    this.syncing = false,
    this.pending = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.lastSuccess,
    this.lastError,
  });

  final bool serverAvailable;
  final bool syncing;
  final int pending;
  final int failed;
  final int conflicts;
  final DateTime? lastSuccess;
  final String? lastError;
}

abstract interface class SyncGateway {
  Future<void> syncNow();
  Future<void> retryFailed();
  Future<void> acceptServerVersionForConflicts();
  Future<SyncSnapshot> currentSnapshot();
  Stream<SyncSnapshot> get snapshots;
}
