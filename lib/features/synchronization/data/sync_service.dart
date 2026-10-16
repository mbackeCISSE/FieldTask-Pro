import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';
import '../domain/sync_gateway.dart';
import '../domain/sync_retry_policy.dart';

/// Consomme l'outbox sans supprimer une opération avant accusé du serveur.
class SyncService with WidgetsBindingObserver implements SyncGateway {
  SyncService(this.db,
      {String apiUrl = 'http://10.0.2.2:8080/api/',
      FlutterSecureStorage? secureStorage})
      : dio = Dio(BaseOptions(
            baseUrl: apiUrl,
            connectTimeout: const Duration(seconds: 5),
            receiveTimeout: const Duration(seconds: 8))),
        _secureStorage = secureStorage ?? const FlutterSecureStorage() {
    dio.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      final token = await _secureStorage.read(key: 'fieldtask.access_token');
      if (token != null && token != 'local-demo-session') {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    }));
  }
  final Database db;
  final Dio dio;
  final FlutterSecureStorage _secureStorage;
  static const _retryPolicy = SyncRetryPolicy();
  final _snapshotController = StreamController<SyncSnapshot>.broadcast();
  SyncSnapshot _snapshot = const SyncSnapshot();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _running = false;
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    await syncNow();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((x) => x != ConnectivityResult.none)) syncNow();
    });
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _snapshotController.close();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(syncNow());
  }

  @override
  Stream<SyncSnapshot> get snapshots => _snapshotController.stream;

  @override
  Future<SyncSnapshot> currentSnapshot() async {
    final pending = Sqflite.firstIntValue(await db.rawQuery(
            "SELECT COUNT(*) FROM outbox WHERE state IN ('pending','retry','sending')")) ??
        0;
    final failed = Sqflite.firstIntValue(await db
            .rawQuery("SELECT COUNT(*) FROM outbox WHERE state='failed'")) ??
        0;
    final conflicts = Sqflite.firstIntValue(await db
            .rawQuery("SELECT COUNT(*) FROM outbox WHERE state='conflict'")) ??
        0;
    final saved = await db.query('sync_metadata',
        columns: ['key', 'value'],
        where:
            "key IN ('last_success_at','last_sync_error','server_available')");
    final metadata = {
      for (final row in saved) row['key'] as String: row['value'] as String
    };
    final persistedSuccess = _snapshot.lastSuccess ??
        DateTime.tryParse(metadata['last_success_at'] ?? '');
    final serverAvailable = metadata.containsKey('server_available')
        ? metadata['server_available'] == 'true'
        : _snapshot.serverAvailable;
    return SyncSnapshot(
        serverAvailable: serverAvailable,
        syncing: _snapshot.syncing,
        pending: pending,
        failed: failed,
        conflicts: conflicts,
        lastSuccess: persistedSuccess,
        lastError: _snapshot.lastError ?? metadata['last_sync_error']);
  }

  Future<void> _publish(
      {bool? serverAvailable,
      bool? syncing,
      DateTime? lastSuccess,
      String? lastError,
      bool clearError = false}) async {
    if (lastSuccess != null) {
      await db.insert(
          'sync_metadata',
          {
            'key': 'last_success_at',
            'value': lastSuccess.toUtc().toIso8601String()
          },
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    if (serverAvailable != null) {
      await db.insert('sync_metadata',
          {'key': 'server_available', 'value': serverAvailable.toString()},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    if (clearError) {
      await db.delete('sync_metadata',
          where: 'key=?', whereArgs: ['last_sync_error']);
    } else if (lastError != null) {
      await db.insert(
          'sync_metadata', {'key': 'last_sync_error', 'value': lastError},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final counts = await currentSnapshot();
    _snapshot = SyncSnapshot(
      serverAvailable: serverAvailable ?? _snapshot.serverAvailable,
      syncing: syncing ?? _snapshot.syncing,
      pending: counts.pending,
      failed: counts.failed,
      conflicts: counts.conflicts,
      lastSuccess: lastSuccess ?? counts.lastSuccess,
      lastError: clearError ? null : (lastError ?? _snapshot.lastError),
    );
    if (!_snapshotController.isClosed) _snapshotController.add(_snapshot);
  }

  @override
  Future<void> retryFailed() async {
    await db.update(
        'outbox', {'state': 'retry', 'attempts': 0, 'last_error': null},
        where: "state='failed'");
    await db.update('attachments', {'sync_state': 'pending'},
        where: "sync_state='failed'");
    await syncNow();
  }

  @override
  Future<void> acceptServerVersionForConflicts() async {
    await _pullRemoteChanges(acceptConflicts: true, fullSnapshot: true);
    await syncNow();
  }

  @override
  Future<void> syncNow() async {
    if (_running) return;
    _running = true;
    try {
      final sessionToken =
          await _secureStorage.read(key: 'fieldtask.access_token');
      if (sessionToken == null || sessionToken == 'local-demo-session') {
        await _publish(serverAvailable: false, clearError: true);
        return;
      }
      await _publish(syncing: true, clearError: true);
      await dio.get(
          'health'); // Le réseau déclaré ne suffit pas : le backend doit répondre.
      await _publish(serverAvailable: true);
      final queue = await db.query('outbox',
          where: "state IN ('pending','retry','sending') AND attempts < 5",
          orderBy: 'created_at');
      for (final row in queue) {
        await _pushOperation(row);
      }
      await _pullRemoteChanges();
      final remaining = await currentSnapshot();
      final fullySynced = remaining.pending == 0 &&
          remaining.failed == 0 &&
          remaining.conflicts == 0;
      await _publish(
          lastSuccess: fullySynced ? DateTime.now() : null,
          clearError: fullySynced);
    } on DioException catch (error) {
      await _publish(serverAvailable: false, lastError: _safeError(error));
    } catch (error) {
      await _publish(
          lastError: 'Synchronisation impossible (${error.runtimeType}).');
    } finally {
      _running = false;
      await _publish(syncing: false);
    }
  }

  Future<void> _pushOperation(Map<String, Object?> row) async {
    final operationId = row['operation_id']! as String;
    var attempts = row['attempts']! as int;
    final isAttachment = row['operation_type'] == 'attachment';
    while (attempts < _retryPolicy.maxAttempts) {
      attempts++;
      await db.update('outbox', {'state': 'sending', 'attempts': attempts},
          where: 'operation_id=?', whereArgs: [operationId]);
      try {
        final payload =
            jsonDecode(row['payload']! as String) as Map<String, dynamic>;
        if (isAttachment) {
          final form = FormData.fromMap({
            'interventionId': row['intervention_id'],
            'kind': payload['kind'],
            'file': await MultipartFile.fromFile(payload['path'] as String)
          });
          await dio.post('sync/$operationId/attachment', data: form);
        } else {
          await dio.post('sync/$operationId', data: {
            'interventionId': row['intervention_id'],
            'type': row['operation_type'],
            ...payload
          });
        }
        await db.transaction((tx) async {
          await tx.delete('outbox',
              where: 'operation_id=?', whereArgs: [operationId]);
          if (isAttachment) {
            await tx.update('attachments', {'sync_state': 'synced'},
                where: 'id=?', whereArgs: [operationId]);
          }
          final remaining = Sqflite.firstIntValue(await tx.rawQuery(
                  'SELECT COUNT(*) FROM outbox WHERE intervention_id=?',
                  [row['intervention_id']])) ??
              0;
          if (remaining == 0) {
            await tx.update('interventions', {'sync_pending': 0},
                where: 'id=?', whereArgs: [row['intervention_id']]);
          }
        });
        return;
      } catch (error) {
        final statusCode =
            error is DioException ? error.response?.statusCode : null;
        final conflict =
            statusCode == 409 && row['operation_type'] != 'attachment';
        final willRetry = !conflict &&
            _retryPolicy.shouldRetry(attempt: attempts, statusCode: statusCode);
        final message = _safeError(error);
        await db.update(
            'outbox',
            {
              'state': conflict ? 'conflict' : (willRetry ? 'retry' : 'failed'),
              'last_error': message
            },
            where: 'operation_id=?',
            whereArgs: [operationId]);
        if (isAttachment && !willRetry) {
          await db.update('attachments', {'sync_state': 'failed'},
              where: 'id=?', whereArgs: [operationId]);
        }
        await _publish(lastError: message);
        if (!willRetry) {
          return;
        }
        await Future<void>.delayed(_retryPolicy.delayAfter(attempts));
      }
    }
  }

  String _safeError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      if (status != null) return 'Réponse du serveur : HTTP $status.';
      return 'Serveur indisponible (réseau ou délai dépassé).';
    }
    return 'Opération impossible (${error.runtimeType}).';
  }

  Future<void> _pullRemoteChanges(
      {bool acceptConflicts = false, bool fullSnapshot = false}) async {
    final metadata = await db.query('sync_metadata',
        columns: ['value'],
        where: 'key=?',
        whereArgs: ['last_pulled_at'],
        limit: 1);
    final since = metadata.isEmpty ? null : metadata.first['value'] as String;
    final response = await dio.get<Map<String, dynamic>>('sync/changes',
        queryParameters: {if (!fullSnapshot && since != null) 'since': since});
    final body = response.data;
    if (body == null || body['changes'] is! List || body['cursor'] is! String) {
      throw const FormatException(
          'Réponse de synchronisation distante invalide.');
    }
    final changes = body['changes'] as List<dynamic>;
    await db.transaction((tx) async {
      for (final raw in changes) {
        if (raw is! Map<String, dynamic>) continue;
        final id = raw['id'] as String?;
        if (id == null) continue;
        final pendingStates = acceptConflicts
            ? "state IN ('pending','retry','sending','failed')"
            : "state IN ('pending','retry','sending','failed','conflict')";
        final pending = Sqflite.firstIntValue(await tx.rawQuery(
              'SELECT COUNT(*) FROM outbox WHERE intervention_id=? AND $pendingStates',
              [id],
            )) ??
            0;
        // Local pending work wins until it is accepted; remote data never erases an unsent edit.
        if (pending > 0) continue;
        final dueAt =
            DateTime.parse(raw['dueAt'] as String).toUtc().toIso8601String();
        final updatedAt = DateTime.parse(raw['updatedAt'] as String)
            .toUtc()
            .toIso8601String();
        await tx.insert(
            'interventions',
            {
              'id': id,
              'title': raw['title'] as String? ?? '',
              'client': raw['client'] as String? ?? '',
              'address': raw['address'] as String? ?? '',
              'description': raw['description'] as String? ?? '',
              'equipment': raw['equipment'] as String? ?? '',
              'priority': raw['priority'] as String? ?? 'normal',
              'status': raw['status'] as String? ?? 'pending',
              'due_at': dueAt,
              'latitude': (raw['latitude'] as num?)?.toDouble() ?? 0,
              'longitude': (raw['longitude'] as num?)?.toDouble() ?? 0,
              'assigned_technician_id':
                  raw['technicianId'] as String? ?? 'techfix-demo-1',
              'notes': raw['notes'] as String? ?? '',
              'sync_pending': 0,
              'updated_at': updatedAt,
            },
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      if (acceptConflicts) {
        final conflicts = await tx.query('outbox',
            columns: ['intervention_id'], where: "state='conflict'");
        await tx.delete('outbox', where: "state='conflict'");
        for (final row in conflicts) {
          final id = row['intervention_id'] as String;
          final remaining = Sqflite.firstIntValue(await tx.rawQuery(
                  'SELECT COUNT(*) FROM outbox WHERE intervention_id=?',
                  [id])) ??
              0;
          if (remaining == 0)
            await tx.update('interventions', {'sync_pending': 0},
                where: 'id=?', whereArgs: [id]);
        }
      }
      await tx.insert('sync_metadata',
          {'key': 'last_pulled_at', 'value': body['cursor'] as String},
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }
}
