import 'dart:convert';

import '../../../core/time.dart';
import '../../memories/domain/memory.dart';
import '../domain/backup_file.dart';

/// §7.8 encoder. `notification_id`, `schedule_attempt_at_utc`, and
/// `schedule_error_code` are deliberately absent — device-local delivery facts.
class BackupSerializer {
  const BackupSerializer();

  String encode({
    required List<Memory> memories,
    required List<BackupReminder> reminders,
    required DateTime exportedAtUtc,
    required String appVersion,
    required String deviceTimezone,
  }) {
    final payload = <String, Object?>{
      'app': kBackupAppId,
      'schema_version': kSupportedSchemaVersion,
      'exported_at': formatUtcIso(exportedAtUtc),
      'app_version': appVersion,
      'device_timezone': deviceTimezone,
      'counts': {'memories': memories.length, 'reminders': reminders.length},
      'memories': memories.map(memoryToJson).toList(growable: false),
      'reminders': reminders.map(reminderToJson).toList(growable: false),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static Map<String, Object?> memoryToJson(Memory memory) => {
    'id': memory.id,
    'title': memory.title,
    'body': memory.body,
    'category': memory.category.dbValue,
    'item_name': memory.itemName,
    'person_name': memory.personName,
    'warranty_end_date': memory.warrantyEndDate,
    'is_archived': memory.isArchived,
    'created_at_utc': formatUtcIso(memory.createdAtUtc),
    'updated_at_utc': formatUtcIso(memory.updatedAtUtc),
  };

  static Map<String, Object?> reminderToJson(BackupReminder reminder) => {
    'id': reminder.id,
    'memory_id': reminder.memoryId,
    'due_at_utc': formatUtcIso(reminder.dueAtUtc),
    'scheduled_local_datetime': reminder.scheduledLocalDatetime,
    'scheduled_timezone': reminder.scheduledTimezone,
    'precision': reminder.precision.dbValue,
    'status': reminder.status.dbValue,
    'completed_at_utc': reminder.completedAtUtc == null
        ? null
        : formatUtcIso(reminder.completedAtUtc!),
    'created_at_utc': formatUtcIso(reminder.createdAtUtc),
    'updated_at_utc': formatUtcIso(reminder.updatedAtUtc),
  };

  /// FR-EXP-01 — `nanti-ingatkan-aku-backup-YYYYMMDD-HHmmss.json`.
  static String fileNameFor(DateTime localNow) {
    String two(int value) => value.toString().padLeft(2, '0');
    return 'nanti-ingatkan-aku-backup-'
        '${localNow.year}${two(localNow.month)}${two(localNow.day)}-'
        '${two(localNow.hour)}${two(localNow.minute)}${two(localNow.second)}.json';
  }
}
