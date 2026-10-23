import '../../memories/domain/memory.dart';
import '../../reminders/domain/reminder.dart';

/// §7.8 — the JSON shape, independent of the DB schema version.
class BackupFile {
  const BackupFile({
    required this.schemaVersion,
    required this.memories,
    required this.reminders,
    required this.warnings,
    this.exportedAt,
    this.appVersion,
    this.deviceTimezone,
  });

  final int schemaVersion;
  final List<Memory> memories;
  final List<BackupReminder> reminders;

  /// Non-fatal findings (for example an unresolvable export timezone).
  final List<String> warnings;

  final DateTime? exportedAt;
  final String? appVersion;
  final String? deviceTimezone;
}

/// A reminder as stored in a backup. Delivery facts (`notification_id`,
/// `scheduling_status`, error codes) are device-local and never exported
/// (FR-IMP-04).
class BackupReminder {
  const BackupReminder({
    required this.id,
    required this.memoryId,
    required this.dueAtUtc,
    required this.scheduledLocalDatetime,
    required this.scheduledTimezone,
    required this.precision,
    required this.status,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.completedAtUtc,
  });

  final String id;
  final String memoryId;
  final DateTime dueAtUtc;
  final String scheduledLocalDatetime;
  final String scheduledTimezone;
  final ReminderPrecision precision;
  final ReminderStatus status;
  final DateTime? completedAtUtc;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
}

const int kSupportedSchemaVersion = 1;

const String kBackupAppId = 'nanti-ingatkan-aku';
