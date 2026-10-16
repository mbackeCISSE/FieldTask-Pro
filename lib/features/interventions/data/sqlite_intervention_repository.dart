import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../domain/intervention.dart';
import '../domain/intervention_attachment.dart';
import '../domain/intervention_repository.dart';

class SqliteInterventionRepository implements InterventionRepository {
  SqliteInterventionRepository(this.db);
  final Database db;
  static final List<Intervention> seed = [
    Intervention(
        id: 'TF-2601',
        title: 'Panne routeur cœur',
        client: 'Sunu Telecom',
        address: 'Plateau, Dakar',
        description:
            'Perte intermittente de connectivité sur le réseau principal.',
        equipment: 'Routeur Cisco ASR',
        priority: WorkPriority.urgent,
        status: WorkStatus.pending,
        dueAt: DateTime(2026, 10, 13, 9),
        latitude: 14.6697,
        longitude: -17.4358),
    Intervention(
        id: 'TF-2602',
        title: 'Maintenance groupe électrogène',
        client: 'Hôpital Fann',
        address: 'Fann Résidence, Dakar',
        description:
            'Révision périodique et contrôle du démarrage automatique.',
        equipment: 'Groupe SDMO 80 kVA',
        priority: WorkPriority.high,
        status: WorkStatus.inProgress,
        dueAt: DateTime(2026, 10, 13, 14),
        latitude: 14.6873,
        longitude: -17.4660),
    Intervention(
        id: 'TF-2603',
        title: 'Remplacement onduleur',
        client: 'Teranga Data Center',
        address: 'Diamniadio, Dakar',
        description:
            'Batteries en fin de vie détectées lors du dernier contrôle.',
        equipment: 'Onduleur APC 6 kVA',
        priority: WorkPriority.normal,
        status: WorkStatus.pending,
        dueAt: DateTime(2026, 10, 14, 10),
        latitude: 14.7172,
        longitude: -17.1770),
    Intervention(
        id: 'TF-2604',
        title: 'Inspection antenne relais',
        client: 'Sunu Telecom',
        address: 'Thiès, Sénégal',
        description:
            'Vérifier les fixations et la qualité de la liaison radio.',
        equipment: 'Antenne 4G',
        priority: WorkPriority.low,
        status: WorkStatus.completed,
        dueAt: DateTime(2026, 10, 11, 11),
        latitude: 14.7910,
        longitude: -16.9359),
  ];
  static Future<void> createSchema(Database db) async {
    await db.execute(
        "CREATE TABLE interventions (id TEXT PRIMARY KEY,title TEXT NOT NULL,client TEXT NOT NULL,address TEXT NOT NULL,description TEXT NOT NULL,equipment TEXT NOT NULL,priority TEXT NOT NULL,status TEXT NOT NULL,due_at TEXT NOT NULL,latitude REAL NOT NULL,longitude REAL NOT NULL,assigned_technician_id TEXT NOT NULL DEFAULT 'techfix-demo-1',notes TEXT NOT NULL DEFAULT '',sync_pending INTEGER NOT NULL DEFAULT 0,updated_at TEXT NOT NULL)");
    await db.execute(
        "CREATE TABLE outbox (operation_id TEXT PRIMARY KEY,intervention_id TEXT NOT NULL,operation_type TEXT NOT NULL,payload TEXT NOT NULL,created_at TEXT NOT NULL,attempts INTEGER NOT NULL DEFAULT 0,state TEXT NOT NULL DEFAULT 'pending',last_error TEXT)");
    await db.execute(
        'CREATE TABLE attachments(id TEXT PRIMARY KEY,intervention_id TEXT NOT NULL,kind TEXT NOT NULL,path TEXT NOT NULL,sync_state TEXT NOT NULL,created_at TEXT NOT NULL)');
    await db.execute(
        'CREATE TABLE sync_metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
  }

  static Future<void> upgradeSchema(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          "ALTER TABLE interventions ADD COLUMN updated_at TEXT NOT NULL DEFAULT ''");
      await db.execute(
          "UPDATE interventions SET updated_at=datetime('now') WHERE updated_at=''");
      await db.execute(
          'CREATE TABLE IF NOT EXISTS sync_metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL)');
    }
    if (oldVersion < 3) {
      await db.execute(
          "ALTER TABLE interventions ADD COLUMN assigned_technician_id TEXT NOT NULL DEFAULT 'techfix-demo-1'");
    }
  }

  Future<void> seedIfEmpty() async {
    if ((Sqflite.firstIntValue(
                await db.rawQuery('SELECT COUNT(*) FROM interventions')) ??
            0) >
        0) return;
    final batch = db.batch();
    for (final x in seed) {
      batch.insert('interventions', _toMap(x));
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<Intervention>> watchSnapshot() async =>
      (await db.query('interventions')).map(_fromMap).toList();
  @override
  Future<int> pendingOperations() async =>
      Sqflite.firstIntValue(await db.rawQuery(
          "SELECT COUNT(*) FROM outbox WHERE state IN ('pending','retry')")) ??
      0;
  @override
  Future<void> updateStatus(String id, WorkStatus status) async =>
      db.transaction((tx) async {
        final rows = await tx.query('interventions',
            where: 'id=?', whereArgs: [id], limit: 1);
        if (rows.isEmpty) throw StateError('Intervention introuvable.');
        final x = _fromMap(rows.first);
        if (!Intervention.canMove(x.status, status))
          throw StateError('Transition de statut invalide.');
        await tx.update('interventions',
            _toMap(x.copyWith(status: status, syncPending: true)),
            where: 'id=?', whereArgs: [id]);
        await _enqueue(tx, id, 'status', {'status': status.name});
      });
  @override
  Future<void> addNote(String id, String note) async {
    final clean = note.trim();
    if (clean.isEmpty) throw ArgumentError('La note ne peut pas être vide.');
    await db.transaction((tx) async {
      final rows = await tx.query('interventions',
          where: 'id=?', whereArgs: [id], limit: 1);
      if (rows.isEmpty) throw StateError('Intervention introuvable.');
      final x = _fromMap(rows.first);
      final merged = x.notes.isEmpty ? clean : '${x.notes}\n$clean';
      await tx.update(
          'interventions', _toMap(x.copyWith(notes: merged, syncPending: true)),
          where: 'id=?', whereArgs: [id]);
      await _enqueue(tx, id, 'note', {'note': clean});
    });
  }

  @override
  Future<void> saveAttachment(String id, String kind, List<int> bytes,
      {required String extension}) async {
    if (!{'photo', 'signature'}.contains(kind))
      throw ArgumentError.value(kind, 'kind');
    if (bytes.isEmpty) throw ArgumentError('La pièce jointe est vide.');
    if (!RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)) {
      throw ArgumentError.value(extension, 'extension');
    }
    final exists = await db.query('interventions',
        columns: ['id'], where: 'id=?', whereArgs: [id], limit: 1);
    if (exists.isEmpty) throw StateError('Intervention introuvable.');
    final root = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(root.path, 'fieldtask_attachments'));
    await folder.create(recursive: true);
    final path = p.join(folder.path, '${const Uuid().v4()}.$extension');
    await File(path).writeAsBytes(bytes, flush: true);
    try {
      await db.transaction((tx) async {
        final operationId = const Uuid().v4();
        await tx.insert('attachments', {
          'id': operationId,
          'intervention_id': id,
          'kind': kind,
          'path': path,
          'sync_state': 'pending',
          'created_at': DateTime.now().toUtc().toIso8601String()
        });
        await tx.insert('outbox', {
          'operation_id': operationId,
          'intervention_id': id,
          'operation_type': 'attachment',
          'payload': jsonEncode({'kind': kind, 'path': path}),
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'attempts': 0,
          'state': 'pending'
        });
        await tx.update('interventions', {'sync_pending': 1},
            where: 'id=?', whereArgs: [id]);
      });
    } catch (_) {
      try {
        await File(path).delete();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<List<InterventionAttachment>> attachments(String id) async =>
      (await db.query('attachments',
              where: 'intervention_id=?',
              whereArgs: [id],
              orderBy: 'created_at'))
          .map((row) => InterventionAttachment(
                id: row['id']! as String,
                interventionId: row['intervention_id']! as String,
                kind: row['kind']! as String,
                path: row['path']! as String,
                syncState: row['sync_state']! as String,
              ))
          .toList();
  Future<void> _enqueue(Transaction tx, String id, String type,
      Map<String, Object> payload) async {
    await tx.insert('outbox', {
      'operation_id': const Uuid().v4(),
      'intervention_id': id,
      'operation_type': type,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'attempts': 0,
      'state': 'pending'
    });
  }

  static Map<String, Object?> _toMap(Intervention x) => {
        'id': x.id,
        'title': x.title,
        'client': x.client,
        'address': x.address,
        'description': x.description,
        'equipment': x.equipment,
        'priority': x.priority.name,
        'status': x.status.name,
        'due_at': x.dueAt.toIso8601String(),
        'latitude': x.latitude,
        'longitude': x.longitude,
        'assigned_technician_id': x.assignedTechnicianId,
        'notes': x.notes,
        'sync_pending': x.syncPending ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String()
      };
  static Intervention _fromMap(Map<String, Object?> x) => Intervention(
      id: x['id']! as String,
      title: x['title']! as String,
      client: x['client']! as String,
      address: x['address']! as String,
      description: x['description']! as String,
      equipment: x['equipment']! as String,
      priority: WorkPriority.values.byName(x['priority']! as String),
      status: WorkStatus.values.byName(x['status']! as String),
      dueAt: DateTime.parse(x['due_at']! as String),
      latitude: (x['latitude']! as num).toDouble(),
      longitude: (x['longitude']! as num).toDouble(),
      assignedTechnicianId:
          x['assigned_technician_id'] as String? ?? 'techfix-demo-1',
      notes: x['notes'] as String? ?? '',
      syncPending: (x['sync_pending']! as int) == 1);
}
