import 'package:timezone/timezone.dart' as tz;

import '../../../core/constants.dart';
import '../../../core/failures.dart';
import '../../../core/time.dart';
import '../../../core/timezone_service.dart';
import '../../memories/domain/memory.dart';
import '../../memories/domain/memory_validation.dart';
import '../../reminders/domain/reminder.dart';
import 'backup_file.dart';

class ImportValidation {
  const ImportValidation.ok(this.file) : failure = null;

  const ImportValidation.error(this.failure) : file = null;

  final BackupFile? file;
  final Failure? failure;

  bool get isValid => file != null;
}

/// FR-IMP-01 / NFR-SEC-03 — a hard gate. A malicious or corrupt file must fail
/// before a single row is touched.
class ImportValidator {
  const ImportValidator();

  ImportValidation validate(Map<String, Object?> json) {
    try {
      return ImportValidation.ok(_validate(json));
    } on _InvalidBackup catch (error) {
      return ImportValidation.error(
        ImportFailure(error.code, error.messageKey),
      );
    }
  }

  BackupFile _validate(Map<String, Object?> json) {
    final app = json['app'];
    if (app != kBackupAppId) {
      throw const _InvalidBackup('wrong_app', 'import.not_this_app');
    }

    final schemaVersion = json['schema_version'];
    if (schemaVersion is! int) {
      throw const _InvalidBackup('bad_envelope', 'import.not_this_app');
    }
    if (schemaVersion != kSupportedSchemaVersion) {
      throw const _InvalidBackup(
        'version_unsupported',
        'import.version_unsupported',
      );
    }

    final rawMemories = _asList(json['memories'], 'memories');
    final rawReminders = _asList(json['reminders'], 'reminders');
    if (rawMemories.length > Limits.importMaxRows ||
        rawReminders.length > Limits.importMaxRows) {
      throw const _InvalidBackup('too_many_rows', 'import.inconsistent');
    }

    final counts = json['counts'];
    if (counts is Map) {
      final memoryCount = counts['memories'];
      final reminderCount = counts['reminders'];
      if (memoryCount != rawMemories.length ||
          reminderCount != rawReminders.length) {
        throw const _InvalidBackup('counts_mismatch', 'import.inconsistent');
      }
    }

    final warnings = <String>[];
    final memories = <Memory>[];
    final memoryIds = <String>{};
    for (final raw in rawMemories) {
      final memory = _memory(_asMap(raw, 'memory'));
      if (!memoryIds.add(memory.id)) {
        throw const _InvalidBackup('duplicate_memory_id', 'import.duplicate');
      }
      memories.add(memory);
    }

    final reminders = <BackupReminder>[];
    final reminderIds = <String>{};
    final reminderMemoryIds = <String>{};
    for (final raw in rawReminders) {
      final reminder = _reminder(_asMap(raw, 'reminder'), warnings: warnings);
      if (!reminderIds.add(reminder.id)) {
        throw const _InvalidBackup('duplicate_reminder_id', 'import.duplicate');
      }
      if (!reminderMemoryIds.add(reminder.memoryId)) {
        throw const _InvalidBackup(
          'duplicate_reminder_memory',
          'import.duplicate',
        );
      }
      if (!memoryIds.contains(reminder.memoryId)) {
        throw const _InvalidBackup('orphan_reminder', 'import.bad_reference');
      }
      reminders.add(reminder);
    }

    return BackupFile(
      schemaVersion: schemaVersion,
      memories: memories,
      reminders: reminders,
      warnings: warnings,
      exportedAt: parseUtcIso(json['exported_at']),
      appVersion: json['app_version'] is String
          ? json['app_version'] as String
          : null,
      deviceTimezone: json['device_timezone'] is String
          ? json['device_timezone'] as String
          : null,
    );
  }

  Memory _memory(Map<String, Object?> raw) {
    final id = _id(raw['id'], 'memory.id');
    final title = _string(raw['title'], 'memory.title');
    if (isBlank(title) || graphemeLength(title.trim()) > Limits.titleMax) {
      throw const _InvalidBackup('bad_title', 'import.bad_memory');
    }
    final body = _string(raw['body'] ?? '', 'memory.body');
    if (graphemeLength(body) > Limits.bodyMax) {
      throw const _InvalidBackup('bad_body', 'import.bad_memory');
    }

    final categoryValue = _string(raw['category'], 'memory.category');
    final category = MemoryCategory.tryParse(categoryValue);
    if (category == null) {
      throw const _InvalidBackup('bad_category', 'import.bad_memory');
    }

    final personName = _optionalString(
      raw['person_name'],
      'memory.person_name',
    );
    if (personName != null && !category.supportsPersonName) {
      throw const _InvalidBackup('bad_person_name', 'import.bad_memory');
    }
    final itemName = _optionalString(raw['item_name'], 'memory.item_name');
    if (itemName != null && !category.supportsItemName) {
      throw const _InvalidBackup('bad_item_name', 'import.bad_memory');
    }
    final warrantyEnd = _optionalString(
      raw['warranty_end_date'],
      'memory.warranty_end_date',
    );
    if (warrantyEnd != null) {
      if (!category.supportsWarrantyEnd) {
        throw const _InvalidBackup(
          'bad_warranty_category',
          'import.bad_memory',
        );
      }
      if (!isRealCalendarDate(warrantyEnd)) {
        throw const _InvalidBackup('bad_warranty_date', 'import.bad_date');
      }
    }

    final isArchived = raw['is_archived'];
    if (isArchived is! bool) {
      throw const _InvalidBackup('bad_archived', 'import.bad_memory');
    }

    final createdAt = parseUtcIso(raw['created_at_utc']);
    final updatedAt = parseUtcIso(raw['updated_at_utc']);
    if (createdAt == null || updatedAt == null) {
      throw const _InvalidBackup('bad_memory_timestamp', 'import.bad_memory');
    }

    return Memory(
      id: id,
      title: title.trim(),
      body: body,
      category: category,
      itemName: itemName,
      personName: personName,
      warrantyEndDate: warrantyEnd,
      isArchived: isArchived,
      createdAtUtc: createdAt,
      updatedAtUtc: updatedAt,
    );
  }

  BackupReminder _reminder(
    Map<String, Object?> raw, {
    required List<String> warnings,
  }) {
    final id = _id(raw['id'], 'reminder.id');
    final memoryId = _id(raw['memory_id'], 'reminder.memory_id');

    final dueAt = parseUtcIso(raw['due_at_utc']);
    if (dueAt == null) {
      throw const _InvalidBackup('bad_due_at', 'import.bad_reminder');
    }

    final scheduledLocal = _string(
      raw['scheduled_local_datetime'] ?? '',
      'reminder.scheduled_local',
    );
    if (scheduledLocal.isNotEmpty &&
        !RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$').hasMatch(scheduledLocal)) {
      warnings.add('import.warn_local_datetime');
    }

    final zoneId = _string(
      raw['scheduled_timezone'] ?? 'UTC',
      'reminder.timezone',
    );
    // Unknown zones are a warning, never fatal (§7.8).
    final zone = resolveLocationId(zoneId);
    if (zone.unknown) warnings.add('import.warn_timezone');

    final precision = ReminderPrecision.tryParse(
      _string(raw['precision'], 'reminder.precision'),
    );
    if (precision == null) {
      throw const _InvalidBackup('bad_precision', 'import.bad_reminder');
    }

    final status = ReminderStatus.tryParse(
      _string(raw['status'], 'reminder.status'),
    );
    if (status == null) {
      throw const _InvalidBackup('bad_status', 'import.bad_reminder');
    }

    // §7.8 lists `scheduling_status` as an enum check. Our own exports omit it
    // (delivery facts are device-local), so only a present, invalid value fails.
    final rawSchedulingStatus = raw['scheduling_status'];
    if (rawSchedulingStatus != null &&
        SchedulingStatus.tryParse(
              _string(rawSchedulingStatus, 'reminder.scheduling_status'),
            ) ==
            null) {
      throw const _InvalidBackup(
        'bad_scheduling_status',
        'import.bad_reminder',
      );
    }

    final completedAt = parseUtcIso(raw['completed_at_utc']);
    if (status == ReminderStatus.completed && completedAt == null) {
      throw const _InvalidBackup('missing_completed_at', 'import.bad_reminder');
    }

    final createdAt = parseUtcIso(raw['created_at_utc']);
    final updatedAt = parseUtcIso(raw['updated_at_utc']);
    if (createdAt == null || updatedAt == null) {
      throw const _InvalidBackup(
        'bad_reminder_timestamp',
        'import.bad_reminder',
      );
    }

    return BackupReminder(
      id: id,
      memoryId: memoryId,
      dueAtUtc: dueAt,
      scheduledLocalDatetime: scheduledLocal,
      scheduledTimezone: zoneId,
      precision: precision,
      status: status,
      completedAtUtc: completedAt,
      createdAtUtc: createdAt,
      updatedAtUtc: updatedAt,
    );
  }

  static Map<String, Object?> _asMap(Object? value, String field) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    throw _InvalidBackup('bad_$field', 'import.invalid');
  }

  static List<Object?> _asList(Object? value, String field) {
    if (value is List) return value;
    throw _InvalidBackup('bad_$field', 'import.invalid');
  }

  static String _string(Object? value, String field) {
    if (value is String) return value;
    throw _InvalidBackup('bad_$field', 'import.invalid');
  }

  static String? _optionalString(Object? value, String field) {
    if (value == null) return null;
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    throw _InvalidBackup('bad_$field', 'import.invalid');
  }

  static String _id(Object? value, String field) {
    final id = _string(value, field);
    if (id.isEmpty || id.length > 64) {
      throw _InvalidBackup('bad_$field', 'import.invalid');
    }
    return id;
  }
}

/// Internal control-flow exception; never leaves the validator.
class _InvalidBackup implements Exception {
  const _InvalidBackup(this.code, this.messageKey);

  final String code;
  final String messageKey;
}

/// Kept for callers that only need the zone check.
bool isResolvableZone(String id) {
  try {
    tz.getLocation(id);
    return true;
  } on tz.LocationNotFoundException {
    return false;
  }
}
