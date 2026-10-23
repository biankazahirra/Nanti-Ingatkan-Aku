import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/core/app_database.dart';
import 'package:nanti_ingatkan_aku/core/failures.dart';
import 'package:nanti_ingatkan_aku/features/memories/data/memory_dao.dart';
import 'package:nanti_ingatkan_aku/features/reminders/data/reminder_dao.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  Future<AppDatabase> openMemoryDb() => AppDatabase.open(
    path: inMemoryDatabasePath,
    factory: databaseFactoryFfi,
    enablePreMigrationBackup: false,
  );

  test('a fresh database opens at the current schema version', () async {
    final database = await openMemoryDb();
    addTearDown(database.close);

    final version = await database.db.rawQuery('PRAGMA user_version');
    expect(version.first.values.first, AppDatabase.schemaVersion);
  });

  test(
    'both tables and their indexes exist after the first migration',
    () async {
      final database = await openMemoryDb();
      addTearDown(database.close);

      final objects = await database.db.rawQuery(
        "SELECT type, name FROM sqlite_master WHERE name NOT LIKE 'sqlite_%'",
      );
      final names = objects.map((row) => row['name'] as String).toSet();

      expect(names, contains(MemoryDao.table));
      expect(names, contains(ReminderDao.table));
      expect(names, contains('idx_memories_list'));
      expect(names, contains('idx_memories_cat'));
      expect(names, contains('idx_reminders_due'));
    },
  );

  test('foreign key enforcement is on for every connection', () async {
    final database = await openMemoryDb();
    addTearDown(database.close);

    final pragma = await database.db.rawQuery('PRAGMA foreign_keys');
    expect(pragma.first.values.first, 1);

    // A reminder without a memory is rejected outright (§7.3).
    await expectLater(
      database.db.insert(ReminderDao.table, {
        'id': 'r1',
        'memory_id': 'no-such-memory',
        'notification_id': 1,
        'due_at_utc': '2026-10-24T02:00:00.000Z',
        'scheduled_local_datetime': '2026-10-24T09:00',
        'scheduled_timezone': 'Asia/Jakarta',
        'precision': 'exact',
        'status': 'pending',
        'scheduling_status': 'deferred',
        'created_at_utc': '2026-10-23T02:00:00.000Z',
        'updated_at_utc': '2026-10-23T02:00:00.000Z',
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('the DDL pins the reminder instant to the ISO shape (§7.3)', () async {
    final database = await openMemoryDb();
    addTearDown(database.close);

    await database.db.insert(MemoryDao.table, {
      'id': 'm1',
      'title': 'Judul',
      'body': '',
      'category': 'general',
      'title_norm': 'judul',
      'body_norm': '',
      'is_archived': 0,
      'created_at_utc': '2026-10-23T02:00:00.000Z',
      'updated_at_utc': '2026-10-23T02:00:00.000Z',
    });

    Map<String, Object?> reminderRow(String dueAtUtc) => {
      'id': 'r1',
      'memory_id': 'm1',
      'notification_id': 1,
      'due_at_utc': dueAtUtc,
      'scheduled_local_datetime': '2026-10-24T09:00',
      'scheduled_timezone': 'Asia/Jakarta',
      'precision': 'exact',
      'status': 'pending',
      'scheduling_status': 'deferred',
      'created_at_utc': '2026-10-23T02:00:00.000Z',
      'updated_at_utc': '2026-10-23T02:00:00.000Z',
    };

    await expectLater(
      database.db.insert(ReminderDao.table, reminderRow('kemarin')),
      throwsA(isA<DatabaseException>()),
    );
    await database.db.insert(
      ReminderDao.table,
      reminderRow('2026-10-24T02:00:00.000Z'),
    );
    expect(await database.db.query(ReminderDao.table), hasLength(1));
  });

  test('the DDL pins the enums, the ISO shape and the body cap', () async {
    final database = await openMemoryDb();
    addTearDown(database.close);

    Map<String, Object?> memoryRow({
      String id = 'm1',
      String category = 'general',
      String? warranty,
      int archived = 0,
      String body = '',
    }) => {
      'id': id,
      'title': 'Judul',
      'body': body,
      'category': category,
      'warranty_end_date': warranty,
      'title_norm': 'judul',
      'body_norm': body.toLowerCase(),
      'is_archived': archived,
      'created_at_utc': '2026-10-23T02:00:00.000Z',
      'updated_at_utc': '2026-10-23T02:00:00.000Z',
    };

    await expectLater(
      database.db.insert(MemoryDao.table, memoryRow(category: 'misc')),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      database.db.insert(MemoryDao.table, memoryRow(warranty: '12-12-2027')),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      database.db.insert(MemoryDao.table, memoryRow(archived: 2)),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      database.db.insert(
        MemoryDao.table,
        memoryRow(id: 'm2', body: 'a' * 10001),
      ),
      throwsA(isA<DatabaseException>()),
    );
    // `created_at_utc` carries no CHECK: §7.3 pins the ISO shape on the values
    // the app itself derives (warranty dates, reminder instants), so an
    // arbitrary string is accepted here by design.
    await database.db.insert(MemoryDao.table, memoryRow(id: 'm3', body: 'x'));

    // A well-formed row still inserts.
    await database.db.insert(MemoryDao.table, memoryRow(id: 'm4'));
    expect((await database.db.query(MemoryDao.table)).length, 2);
  });

  test('reopening an existing file database keeps its rows', () async {
    final directory = Directory.systemTemp.createTempSync('nia_db_');
    addTearDown(() => directory.deleteSync(recursive: true));
    final path = '${directory.path}${Platform.pathSeparator}app.db';

    final first = await AppDatabase.open(
      path: path,
      factory: databaseFactoryFfi,
      enablePreMigrationBackup: false,
    );
    await first.db.insert(MemoryDao.table, {
      'id': 'kept',
      'title': 'Tetap ada',
      'body': '',
      'category': 'general',
      'title_norm': 'tetap ada',
      'body_norm': '',
      'is_archived': 0,
      'created_at_utc': '2026-10-23T02:00:00.000Z',
      'updated_at_utc': '2026-10-23T02:00:00.000Z',
    });
    await first.close();

    final second = await AppDatabase.open(
      path: path,
      factory: databaseFactoryFfi,
      enablePreMigrationBackup: false,
    );
    addTearDown(second.close);

    final rows = await second.db.query(MemoryDao.table);
    expect(rows.single['id'], 'kept');
    final version = await second.db.rawQuery('PRAGMA user_version');
    expect(version.first.values.first, AppDatabase.schemaVersion);
  });

  test(
    'a database written by a newer build is refused, never downgraded',
    () async {
      final directory = Directory.systemTemp.createTempSync('nia_db_new_');
      addTearDown(() => directory.deleteSync(recursive: true));
      final path = '${directory.path}${Platform.pathSeparator}future.db';

      final future = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(version: AppDatabase.schemaVersion + 1),
      );
      await future.close();

      await expectLater(
        AppDatabase.open(
          path: path,
          factory: databaseFactoryFfi,
          enablePreMigrationBackup: false,
        ),
        throwsA(isA<DbVersionTooNewFailure>()),
      );
    },
  );

  test(
    'the failure for a newer database carries a user-facing message key',
    () async {
      const failure = DbVersionTooNewFailure();
      expect(failure.messageKey, 'error.db_newer');
      expect(failure.code, 'db_version_too_new');
    },
  );

  test(
    'the migration list is ordered and matches the declared version',
    () async {
      expect(kMigrations, isNotEmpty);
      final versions = kMigrations.map((m) => m.version).toList();
      expect(versions, List<int>.from(versions)..sort());
      expect(versions.toSet(), hasLength(versions.length));
      expect(versions.last, AppDatabase.schemaVersion);
      expect(kMigrations.first.steps, isNotEmpty);
    },
  );
}
