import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/app_database.dart';
import '../../../core/constants.dart';
import '../../../core/failures.dart';
import '../../../core/ids.dart';
import '../../../core/logging.dart';
import '../../memories/data/memory_dao.dart';
import '../../memories/domain/memory.dart';
import '../../reminders/data/reconcile_service.dart';
import '../../reminders/data/reminder_dao.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/domain/reminder_scheduler.dart';
import '../../settings/data/settings_repository.dart';
import '../domain/backup_file.dart';
import '../domain/import_validator.dart';
import 'backup_file_port.dart';
import 'backup_serializer.dart';

enum ExportResultStatus { saved, cancelled, failed }

class ExportResult {
  const ExportResult(this.status, {this.fileName, this.failure});

  final ExportResultStatus status;
  final String? fileName;
  final Failure? failure;
}

class ImportOutcome {
  const ImportOutcome({
    required this.memories,
    required this.reminders,
    required this.warnings,
    required this.schedulingWarnings,
  });

  final int memories;
  final int reminders;
  final List<String> warnings;

  /// FR-IMP-03 — reported separately; import success never depends on them.
  final List<String> schedulingWarnings;
}

/// FR-EXP-01..03 and FR-IMP-01..04.
class BackupService {
  BackupService({
    required this._database,
    required this._memoryDao,
    required this._reminderDao,
    required this._scheduler,
    required this._reconcileService,
    required this._settings,
    required this._filePort,
    required this._nowUtc,
    required this._deviceTimezone,
    required this._appVersion,
    this.debugFailureHook,
  });

  final AppDatabase _database;
  final MemoryDao _memoryDao;
  final ReminderDao _reminderDao;
  final ReminderScheduler _scheduler;
  final ReconcileService _reconcileService;
  final SettingsRepository _settings;
  final BackupFilePort _filePort;
  final DateTime Function() _nowUtc;
  final String Function() _deviceTimezone;
  final String _appVersion;

  /// Test seam for AC-18 (rollback on mid-transaction failure). Never set in
  /// production code paths.
  @visibleForTesting
  final void Function(int processed)? debugFailureHook;

  final ImportValidator _validator = const ImportValidator();

  /// FR-EXP-01..03. The warning dialog is shown by the UI before calling this.
  Future<ExportResult> export({required String dialogTitle}) async {
    final memories = await _allMemories();
    final reminders = await _backupReminders();

    final now = _nowUtc();
    final content = const BackupSerializer().encode(
      memories: memories,
      reminders: reminders,
      exportedAtUtc: now,
      appVersion: _appVersion,
      deviceTimezone: _deviceTimezone(),
    );
    final fileName = BackupSerializer.fileNameFor(now.toLocal());

    try {
      final path = await _filePort.saveJson(
        fileName: fileName,
        content: content,
        dialogTitle: dialogTitle,
      );
      if (path == null) {
        logEvent(LogCodes.exportCancelled);
        return const ExportResult(ExportResultStatus.cancelled);
      }
      await _settings.setLastExportAtUtc(now);
      logEvent(LogCodes.exportOk, detail: fileName);
      return ExportResult(ExportResultStatus.saved, fileName: fileName);
    } on Object catch (error) {
      logEvent('EXP_FAILED', detail: error.runtimeType.toString());
      return ExportResult(
        ExportResultStatus.failed,
        failure: const BackupFailure('export_failed', 'export.failed'),
      );
    }
  }

  /// Picks a file, validates it fully, and returns the parsed snapshot.
  /// Nothing is written here (FR-IMP-01).
  Future<ImportValidation> prepareImport({required String dialogTitle}) async {
    String? path;
    try {
      path = await _filePort.pickJsonFile(dialogTitle: dialogTitle);
    } on Object {
      return const ImportValidation.error(
        ImportFailure('pick_failed', 'import.failed'),
      );
    }
    if (path == null) {
      return const ImportValidation.error(
        ImportFailure('cancelled', 'import.cancelled'),
      );
    }

    String text;
    try {
      text = await _filePort.readText(path, maxBytes: Limits.importMaxBytes);
    } on BackupFileTooLarge {
      logEvent(LogCodes.importRejected, detail: 'file_too_big');
      return const ImportValidation.error(
        ImportFailure('file_too_big', 'import.file_too_big'),
      );
    } on Object {
      return const ImportValidation.error(
        ImportFailure('read_failed', 'import.invalid'),
      );
    }

    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      logEvent(LogCodes.importRejected, detail: 'parse');
      return const ImportValidation.error(
        ImportFailure('parse_failed', 'import.invalid'),
      );
    }
    if (decoded is! Map) {
      logEvent(LogCodes.importRejected, detail: 'not_object');
      return const ImportValidation.error(
        ImportFailure('parse_failed', 'import.invalid'),
      );
    }

    final validation = _validator.validate(decoded.cast<String, Object?>());
    if (!validation.isValid) {
      logEvent(LogCodes.importRejected, detail: validation.failure?.code);
    }
    return validation;
  }

  /// FR-IMP-02 — replace-only, atomic. Any error rolls back and leaves the
  /// previous data logically unchanged.
  Future<ImportOutcome> applyImport(BackupFile file) async {
    final notificationIds = <int>{};
    final reminders = file.reminders
        .map((reminder) {
          final notificationId = allocateNotificationId(
            reminder.id,
            notificationIds,
          );
          notificationIds.add(notificationId);
          return Reminder(
            id: reminder.id,
            memoryId: reminder.memoryId,
            notificationId: notificationId,
            dueAtUtc: reminder.dueAtUtc,
            scheduledLocalDatetime: reminder.scheduledLocalDatetime,
            scheduledTimezone: reminder.scheduledTimezone,
            precision: reminder.precision,
            status: reminder.status,
            // FR-IMP-04 — delivery facts are regenerated for this device.
            schedulingStatus: SchedulingStatus.deferred,
            completedAtUtc: reminder.completedAtUtc,
            createdAtUtc: reminder.createdAtUtc,
            updatedAtUtc: reminder.updatedAtUtc,
          );
        })
        .toList(growable: false);

    // Fresh ids must be unique across the imported batch.
    final uniqueCheck = <int>{};
    for (final reminder in reminders) {
      if (!uniqueCheck.add(reminder.notificationId)) {
        throw const ImportFailure(
          'duplicate_notification_id',
          'import.duplicate',
        );
      }
    }
    var processed = 0;
    await _database.db.transaction((txn) async {
      await _reminderDao.deleteAll(executor: txn);
      await _memoryDao.deleteAll(executor: txn);
      for (final memory in file.memories) {
        await _memoryDao.upsert(memory, executor: txn);
        processed++;
        debugFailureHook?.call(processed);
      }
      for (final reminder in reminders) {
        await _reminderDao.upsert(reminder, executor: txn);
        processed++;
        debugFailureHook?.call(processed);
      }
    });

    // FR-IMP-03 — recompute delivery after the data is committed.
    final schedulingWarnings = <String>[];
    try {
      await _scheduler.cancelAll();
      await _reconcileService.reconcile(force: true);
      final status = _reconcileService.lastUnresolvedStatus;
      if (status == SchedulingStatus.permissionNeeded) {
        schedulingWarnings.add('reminder.permission_needed');
      } else if (status == SchedulingStatus.schedulingFailed) {
        schedulingWarnings.add('reminder.failed');
      }
    } on Object catch (error) {
      schedulingWarnings.add('reminder.failed');
      logEvent(LogCodes.scheduleFailed, detail: error.runtimeType.toString());
    }

    logEvent(
      LogCodes.importOk,
      detail: 'memories=${file.memories.length} reminders=${reminders.length}',
    );

    return ImportOutcome(
      memories: file.memories.length,
      reminders: reminders.length,
      warnings: file.warnings,
      schedulingWarnings: schedulingWarnings,
    );
  }

  /// FR-SET-04 — wipe rows, cancel every notification, clear settings.
  Future<void> deleteAllData() async {
    await _database.db.transaction((txn) async {
      await _reminderDao.deleteAll(executor: txn);
      await _memoryDao.deleteAll(executor: txn);
    });
    await _scheduler.cancelAll();
    await _settings.clear();
  }

  Future<List<Memory>> _allMemories() async {
    final result = <Memory>[];
    for (final archived in const [false, true]) {
      var page = 0;
      while (true) {
        final batch = await _memoryDao.list(
          archived: archived,
          limit: Limits.pageSize,
          offset: page * Limits.pageSize,
        );
        result.addAll(batch);
        if (batch.length < Limits.pageSize) break;
        page++;
      }
    }
    return result;
  }

  Future<List<BackupReminder>> _backupReminders() async {
    final rows = await _reminderDao.all();
    return rows
        .map(
          (reminder) => BackupReminder(
            id: reminder.id,
            memoryId: reminder.memoryId,
            dueAtUtc: reminder.dueAtUtc,
            scheduledLocalDatetime: reminder.scheduledLocalDatetime,
            scheduledTimezone: reminder.scheduledTimezone,
            precision: reminder.precision,
            status: reminder.status,
            completedAtUtc: reminder.completedAtUtc,
            createdAtUtc: reminder.createdAtUtc,
            updatedAtUtc: reminder.updatedAtUtc,
          ),
        )
        .toList(growable: false);
  }

  /// FR-SET-05 — no PII, only codes and counts.
  Future<int> memoryCount() => _memoryDao.count();
}
