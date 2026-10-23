import 'package:sqflite/sqflite.dart';

import '../../../core/time.dart';
import '../../memories/data/memory_dao.dart';
import '../domain/due_state.dart';
import '../domain/reminder.dart';

class ReminderDao {
  const ReminderDao(this._db);

  final Database _db;

  static const String table = 'reminders';

  static const String createTableSql = '''
CREATE TABLE reminders (
  id                       TEXT PRIMARY KEY NOT NULL,
  memory_id                TEXT NOT NULL UNIQUE
                             REFERENCES memories(id) ON DELETE CASCADE,
  notification_id          INTEGER NOT NULL UNIQUE,
  due_at_utc               TEXT NOT NULL,
  scheduled_local_datetime TEXT NOT NULL,
  scheduled_timezone       TEXT NOT NULL,
  precision                TEXT NOT NULL DEFAULT 'inexact'
                             CHECK (precision IN ('exact','inexact')),
  status                   TEXT NOT NULL DEFAULT 'pending'
                             CHECK (status IN ('pending','completed')),
  scheduling_status        TEXT NOT NULL DEFAULT 'deferred'
                             CHECK (scheduling_status IN
                               ('scheduled','deferred','permission_needed','scheduling_failed')),
  schedule_attempt_at_utc  TEXT,
  schedule_error_code      TEXT,
  completed_at_utc         TEXT,
  created_at_utc           TEXT NOT NULL,
  updated_at_utc           TEXT NOT NULL,
  CHECK (status <> 'completed' OR completed_at_utc IS NOT NULL),
  CHECK (due_at_utc GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z')
)''';

  static const List<String> createIndexSql = [
    'CREATE INDEX idx_reminders_due ON reminders (status, due_at_utc)',
  ];

  Future<void> upsert(Reminder reminder, {DatabaseExecutor? executor}) {
    return (executor ?? _db).insert(
      table,
      toRow(reminder),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteForMemory(String memoryId, {DatabaseExecutor? executor}) {
    return (executor ?? _db).delete(
      table,
      where: 'memory_id = ?',
      whereArgs: [memoryId],
    );
  }

  Future<void> deleteAll({DatabaseExecutor? executor}) {
    return (executor ?? _db).delete(table);
  }

  Future<Reminder?> findByMemory(String memoryId) async {
    final rows = await _db.query(
      table,
      where: 'memory_id = ?',
      whereArgs: [memoryId],
      limit: 1,
    );
    return rows.isEmpty ? null : fromRow(rows.first);
  }

  Future<List<Reminder>> all() async {
    final rows = await _db.query(table, orderBy: 'due_at_utc ASC');
    return rows.map(fromRow).toList(growable: false);
  }

  Future<Set<int>> notificationIds() async {
    final rows = await _db.query(table, columns: ['notification_id']);
    return rows.map((row) => row['notification_id']! as int).toSet();
  }

  Future<int> count() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM $table');
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> countPending() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE status = ?',
      [ReminderStatus.pending.dbValue],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  Future<int> countBySchedulingStatus(SchedulingStatus status) async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) AS c FROM $table WHERE status = ? AND scheduling_status = ?',
      [ReminderStatus.pending.dbValue, status.dbValue],
    );
    return (rows.first['c'] as int?) ?? 0;
  }

  /// FR-TODAY-02 — pending reminders joined with their memory, plus pending
  /// reminders of archived memories (FR-TODAY-03).
  Future<List<TodayEntry>> pendingEntries() async {
    final rows = await _db.rawQuery(
      '''
SELECT r.*,
       m.id                AS m_id,
       m.title             AS m_title,
       m.body              AS m_body,
       m.category          AS m_category,
       m.item_name         AS m_item_name,
       m.person_name       AS m_person_name,
       m.warranty_end_date AS m_warranty_end_date,
       m.is_archived       AS m_is_archived,
       m.created_at_utc    AS m_created_at_utc,
       m.updated_at_utc    AS m_updated_at_utc
FROM $table r
JOIN ${MemoryDao.table} m ON m.id = r.memory_id
WHERE r.status = ?
ORDER BY r.due_at_utc ASC
''',
      [ReminderStatus.pending.dbValue],
    );

    return rows
        .map((row) {
          return TodayEntry(
            reminder: fromRow(row),
            memory: MemoryDao.fromRow({
              'id': row['m_id'],
              'title': row['m_title'],
              'body': row['m_body'],
              'category': row['m_category'],
              'item_name': row['m_item_name'],
              'person_name': row['m_person_name'],
              'warranty_end_date': row['m_warranty_end_date'],
              'is_archived': row['m_is_archived'],
              'created_at_utc': row['m_created_at_utc'],
              'updated_at_utc': row['m_updated_at_utc'],
            }),
          );
        })
        .toList(growable: false);
  }

  static Map<String, Object?> toRow(Reminder reminder) => {
    'id': reminder.id,
    'memory_id': reminder.memoryId,
    'notification_id': reminder.notificationId,
    'due_at_utc': formatUtcIso(reminder.dueAtUtc),
    'scheduled_local_datetime': reminder.scheduledLocalDatetime,
    'scheduled_timezone': reminder.scheduledTimezone,
    'precision': reminder.precision.dbValue,
    'status': reminder.status.dbValue,
    'scheduling_status': reminder.schedulingStatus.dbValue,
    'schedule_attempt_at_utc': reminder.scheduleAttemptAtUtc == null
        ? null
        : formatUtcIso(reminder.scheduleAttemptAtUtc!),
    'schedule_error_code': reminder.scheduleErrorCode,
    'completed_at_utc': reminder.completedAtUtc == null
        ? null
        : formatUtcIso(reminder.completedAtUtc!),
    'created_at_utc': formatUtcIso(reminder.createdAtUtc),
    'updated_at_utc': formatUtcIso(reminder.updatedAtUtc),
  };

  static Reminder fromRow(Map<String, Object?> row) {
    return Reminder(
      id: row['id']! as String,
      memoryId: row['memory_id']! as String,
      notificationId: row['notification_id']! as int,
      dueAtUtc: parseUtcIso(row['due_at_utc']) ?? DateTime.utc(1970),
      scheduledLocalDatetime:
          (row['scheduled_local_datetime'] as String?) ?? '',
      scheduledTimezone: (row['scheduled_timezone'] as String?) ?? 'UTC',
      precision:
          ReminderPrecision.tryParse(row['precision'] as String?) ??
          ReminderPrecision.inexact,
      status:
          ReminderStatus.tryParse(row['status'] as String?) ??
          ReminderStatus.pending,
      schedulingStatus:
          SchedulingStatus.tryParse(row['scheduling_status'] as String?) ??
          SchedulingStatus.deferred,
      completedAtUtc: parseUtcIso(row['completed_at_utc']),
      scheduleAttemptAtUtc: parseUtcIso(row['schedule_attempt_at_utc']),
      scheduleErrorCode: row['schedule_error_code'] as String?,
      createdAtUtc: parseUtcIso(row['created_at_utc']) ?? DateTime.utc(1970),
      updatedAtUtc: parseUtcIso(row['updated_at_utc']) ?? DateTime.utc(1970),
    );
  }
}
