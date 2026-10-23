import 'dart:io';

import 'package:sqflite/sqflite.dart';

import 'failures.dart';
import 'logging.dart';
import '../features/memories/data/memory_dao.dart';
import '../features/reminders/data/reminder_dao.dart';

/// One ordered migration. `user_version` is the schema version (§7.4).
class Migration {
  const Migration(this.version, this.name, this.steps);

  final int version;
  final String name;
  final List<String> steps;

  /// Data fix-ups that cannot be expressed in SQL.
  List<Future<void>> Function(Database db)? get fixups => null;
}

const List<Migration> kMigrations = [
  Migration(1, 'initial_schema', [
    MemoryDao.createTableSql,
    ...MemoryDao.createIndexSql,
    ReminderDao.createTableSql,
    ...ReminderDao.createIndexSql,
  ]),
];

/// Owns the SQLite handle, pragmas, and the upgrade path.
class AppDatabase {
  AppDatabase._(this.db, this.path);

  final Database db;
  final String path;

  /// Bumped only together with a new entry in [kMigrations].
  static const int schemaVersion = 1;

  static Future<AppDatabase> open({
    required String path,
    DatabaseFactory? factory,
    bool enablePreMigrationBackup = true,
  }) async {
    final resolvedFactory = factory ?? databaseFactory;
    final database = await resolvedFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) async {
          await _runMigrations(db, from: 0, to: version);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (newVersion > schemaVersion) {
            throw const DbVersionTooNewFailure();
          }
          if (enablePreMigrationBackup) {
            await _backupBeforeMigration(path, oldVersion, newVersion);
          }
          await _runMigrations(db, from: oldVersion, to: newVersion);
          final check = await db.rawQuery('PRAGMA integrity_check');
          final result = check.isEmpty ? '' : '${check.first.values.first}';
          if (result != 'ok') {
            throw const StorageFailure('integrity_check_failed');
          }
          await _deletePreMigrationBackup(path);
        },
        onDowngrade: (db, oldVersion, newVersion) async {
          // Never downgrade destructively (§7.4).
          throw const DbVersionTooNewFailure();
        },
        onOpen: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA foreign_keys = ON');
        },
      ),
    );
    return AppDatabase._(database, path);
  }

  Future<void> close() => db.close();

  static Future<void> _runMigrations(
    Database db, {
    required int from,
    required int to,
  }) async {
    for (final migration in kMigrations) {
      if (migration.version <= from || migration.version > to) continue;
      for (final step in migration.steps) {
        await db.execute(step);
      }
    }
    await db.execute('PRAGMA user_version = $to');
  }

  /// §7.4 — copy the DB file before a migration that rewrites data.
  static Future<void> _backupBeforeMigration(
    String path,
    int oldVersion,
    int newVersion,
  ) async {
    if (path == inMemoryDatabasePath || oldVersion == 0) return;
    try {
      final file = File(path);
      if (!await file.exists()) return;
      await file.copy(_preMigrationPath(path));
      logEvent('DB_PRE_MIGRATION_BACKUP', detail: '$oldVersion->$newVersion');
    } on Object {
      // A failed copy must not block a read-only migration; it is reported in
      // diagnostics instead of silently ignored.
      logEvent(
        'DB_PRE_MIGRATION_BACKUP_FAILED',
        detail: '$oldVersion->$newVersion',
      );
    }
  }

  static Future<void> _deletePreMigrationBackup(String path) async {
    if (path == inMemoryDatabasePath) return;
    final file = File(_preMigrationPath(path));
    if (await file.exists()) {
      await file.delete();
    }
  }

  static String _preMigrationPath(String path) =>
      '${path}_nanti.pre-migration.db';
}
