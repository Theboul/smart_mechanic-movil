import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/offline_emergency_draft.dart';

class OfflineEmergencyLocalRepository {
  static const _dbName = 'offline_emergencies.db';
  static const _table = 'offline_emergency_drafts';

  Database? _database;

  Future<Database> _getDatabase() async {
    if (_database != null) return _database!;

    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/$_dbName';

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            local_id TEXT PRIMARY KEY,
            vehicle_id TEXT NOT NULL,
            description TEXT NOT NULL,
            phone TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            location_reference TEXT,
            priority TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_sync_attempt_at TEXT,
            sync_attempts INTEGER NOT NULL DEFAULT 0,
            sync_status TEXT NOT NULL,
            backend_incident_id TEXT,
            last_error TEXT
          )
        ''');
      },
    );

    return _database!;
  }

  Future<List<OfflineEmergencyDraft>> getAllDrafts() async {
    final db = await _getDatabase();
    final rows = await db.query(_table, orderBy: 'created_at DESC');
    return rows.map(OfflineEmergencyDraft.fromMap).toList();
  }

  Future<List<OfflineEmergencyDraft>> getPendingDrafts() async {
    final db = await _getDatabase();
    final rows = await db.query(
      _table,
      where: 'sync_status IN (?, ?, ?)',
      whereArgs: ['PENDING_SYNC', 'FAILED', 'SYNCING'],
      orderBy: 'created_at ASC',
    );
    return rows.map(OfflineEmergencyDraft.fromMap).toList();
  }

  Future<void> upsertDraft(OfflineEmergencyDraft draft) async {
    final db = await _getDatabase();
    await db.insert(
      _table,
      draft.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateDraft(OfflineEmergencyDraft draft) async {
    final db = await _getDatabase();
    await db.update(
      _table,
      draft.toMap(),
      where: 'local_id = ?',
      whereArgs: [draft.localId],
    );
  }

  Future<void> deleteDraft(String localId) async {
    final db = await _getDatabase();
    await db.delete(_table, where: 'local_id = ?', whereArgs: [localId]);
  }
}
