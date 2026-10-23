import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/core/constants.dart';
import 'package:nanti_ingatkan_aku/features/backup/data/backup_serializer.dart';
import 'package:nanti_ingatkan_aku/features/backup/data/backup_service.dart';
import 'package:nanti_ingatkan_aku/features/backup/domain/backup_file.dart';
import 'package:nanti_ingatkan_aku/features/backup/domain/import_validator.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory_validation.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder_repository.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder_scheduler.dart';

import '../support/test_env.dart';

void main() {
  late TestEnv env;

  setUp(() async {
    env = await createTestEnv();
  });

  tearDown(() async {
    await env.dispose();
  });

  ReminderRequest request(String memoryId) => ReminderRequest(
    memoryId: memoryId,
    dueAtUtc: env.clock.nowUtc().add(const Duration(days: 3)),
    scheduledLocalDatetime: '2026-10-26T16:12',
    scheduledTimezone: 'Asia/Jakarta',
  );

  Future<Memory> seed({String title = 'Garansi laptop', MemoryDraft? draft}) =>
      env.memories.create(draft ?? MemoryDraft(title: title, body: 'isi'));

  BackupFile parseExported(String text) {
    final result = const ImportValidator().validate(
      jsonDecode(text) as Map<String, Object?>,
    );
    expect(result.isValid, isTrue, reason: result.failure?.code);
    return result.file!;
  }

  group('export (FR-EXP-01..03)', () {
    test('writes a valid snapshot and records the timestamp', () async {
      final memory = await seed();
      await env.reminders.save(request(memory.id));

      final result = await env.backup.export(dialogTitle: 'Ekspor');

      expect(result.status, ExportResultStatus.saved);
      expect(result.fileName, startsWith('nanti-ingatkan-aku-backup-'));
      expect(env.filePort.writtenFileName, result.fileName);
      final file = parseExported(env.filePort.written!);
      expect(file.memories, hasLength(1));
      expect(file.reminders, hasLength(1));
      expect(file.appVersion, '1.0.0+1');
      expect(file.deviceTimezone, 'Asia/Jakarta');
      expect(env.settings.lastExportAtUtc, env.clock.nowUtc());
    });

    test('delivery facts never leave the device (FR-IMP-04)', () async {
      final memory = await seed();
      await env.reminders.save(request(memory.id));

      await env.backup.export(dialogTitle: 'Ekspor');

      final text = env.filePort.written!;
      expect(text, isNot(contains('notification_id')));
      expect(text, isNot(contains('scheduling_status')));
      expect(text, isNot(contains('schedule_attempt_at_utc')));
      expect(text, isNot(contains('schedule_error_code')));
    });

    test('archived memories and completed reminders are included', () async {
      final memory = await seed();
      await env.reminders.save(request(memory.id));
      await env.reminders.complete(memory.id);
      await env.memories.setArchived(memory.id, true);

      await env.backup.export(dialogTitle: 'Ekspor');

      final file = parseExported(env.filePort.written!);
      expect(file.memories.single.isArchived, isTrue);
      expect(file.reminders.single.status, ReminderStatus.completed);
      expect(file.reminders.single.completedAtUtc, isNotNull);
    });

    test(
      'a cancelled picker writes nothing and reports cancellation',
      () async {
        env.filePort.exportTarget = null;

        final result = await env.backup.export(dialogTitle: 'Ekspor');

        expect(result.status, ExportResultStatus.cancelled);
        expect(env.filePort.written, isNull);
        expect(env.settings.lastExportAtUtc, isNull);
      },
    );

    test('a write failure is a typed failure, not a crash', () async {
      env.filePort.failWrite = true;

      final result = await env.backup.export(dialogTitle: 'Ekspor');

      expect(result.status, ExportResultStatus.failed);
      expect(result.failure!.code, 'export_failed');
      expect(result.failure!.messageKey, 'export.failed');
    });

    test('the file name carries the local date and time', () {
      expect(
        BackupSerializer.fileNameFor(DateTime(2026, 1, 2, 3, 4, 5)),
        'nanti-ingatkan-aku-backup-20260102-030405.json',
      );
      expect(
        BackupSerializer.fileNameFor(DateTime(2026, 12, 31, 23, 59, 59)),
        'nanti-ingatkan-aku-backup-20261231-235959.json',
      );
    });
  });

  group('prepareImport (FR-IMP-01)', () {
    test('a cancelled picker is reported as cancelled', () async {
      final result = await env.backup.prepareImport(dialogTitle: 'Impor');
      expect(result.isValid, isFalse);
      expect(result.failure!.code, 'cancelled');
    });

    test('broken JSON is rejected before any write', () async {
      env.filePort
        ..importSource = 'C:/backup.json'
        ..written = '{"app": ';
      final result = await env.backup.prepareImport(dialogTitle: 'Impor');
      expect(result.failure!.code, 'parse_failed');
      expect(await env.memories.count(), 0);
    });

    test('a JSON array is not a backup document', () async {
      env.filePort
        ..importSource = 'C:/backup.json'
        ..written = '[]';
      final result = await env.backup.prepareImport(dialogTitle: 'Impor');
      expect(result.failure!.code, 'parse_failed');
    });

    test('a file over the byte cap is rejected', () async {
      env.filePort
        ..importSource = 'C:/backup.json'
        ..written = 'x' * (Limits.importMaxBytes + 1);
      final result = await env.backup.prepareImport(dialogTitle: 'Impor');
      expect(result.failure!.code, 'file_too_big');
      expect(result.failure!.messageKey, 'import.file_too_big');
    });

    test('a foreign app id is rejected', () async {
      env.filePort
        ..importSource = 'C:/backup.json'
        ..written = jsonEncode({'app': 'someone-else', 'schema_version': 1});
      final result = await env.backup.prepareImport(dialogTitle: 'Impor');
      expect(result.failure!.code, 'wrong_app');
    });
  });

  group('applyImport (FR-IMP-02..04)', () {
    test('replaces existing data and reports the restored counts', () async {
      final existing = await seed(title: 'Catatan lama');
      await env.reminders.save(request(existing.id));
      await env.backup.export(dialogTitle: 'Ekspor');
      final file = parseExported(env.filePort.written!);

      // A second, unrelated dataset that must be destroyed by the import.
      await env.memories.create(MemoryDraft(title: 'Catatan sementara'));
      expect(await env.memories.count(), 2);

      final outcome = await env.backup.applyImport(file);

      expect(outcome.memories, 1);
      expect(outcome.reminders, 1);
      expect(await env.memories.count(), 1);
      expect((await env.memories.findById(existing.id))!.title, 'Catatan lama');
      expect(
        await env.reminderDao.countBySchedulingStatus(
          SchedulingStatus.scheduled,
        ),
        1,
      );
    });

    test(
      'restores titles, categories and due instants across a fresh install',
      () async {
        final source = await seed(
          draft: const MemoryDraft(
            title: 'Garansi kulkas',
            body: 'Tiga tahun.',
            category: MemoryCategory.warranty,
            itemName: 'Kulkas',
            warrantyEndDate: '2029-01-31',
          ),
        );
        await env.reminders.save(request(source.id));
        await env.backup.export(dialogTitle: 'Ekspor');
        final text = env.filePort.written!;
        final file = parseExported(text);
        final dueAt = file.reminders.single.dueAtUtc;

        await env.dispose();
        env = await createTestEnv();
        env.filePort
          ..importSource = 'C:/backup.json'
          ..written = text;

        final prepared = await env.backup.prepareImport(dialogTitle: 'Impor');
        expect(prepared.isValid, isTrue);
        final outcome = await env.backup.applyImport(prepared.file!);

        expect(outcome.memories, 1);
        final restored = (await env.memories.list()).items.single;
        expect(restored.title, 'Garansi kulkas');
        expect(restored.category, MemoryCategory.warranty);
        expect(restored.itemName, 'Kulkas');
        expect(restored.warrantyEndDate, '2029-01-31');
        expect(await env.memories.count(), 1);
        final reminder = await env.reminders.findByMemory(restored.id);
        expect(reminder!.dueAtUtc, dueAt);
        expect(reminder.status, ReminderStatus.pending);
      },
    );

    test(
      'notification ids are re-derived locally, never taken from the file',
      () async {
        final memory = await seed();
        await env.reminders.save(request(memory.id));
        await env.backup.export(dialogTitle: 'Ekspor');
        final file = parseExported(env.filePort.written!);

        final outcome = await env.backup.applyImport(file);
        final reminder = (await env.reminders.findByMemory(memory.id))!;

        expect(outcome.reminders, 1);
        expect(env.scheduler.cancelAllCalls, 1);
        expect(await env.reminderDao.notificationIds(), {
          reminder.notificationId,
        });
        // Same reminder id, same derived slot: an import is idempotent per device.
        expect(reminder.notificationId, greaterThan(0));
      },
    );

    test(
      'AC-18: a mid-transaction failure rolls back and keeps old data',
      () async {
        final keep = await seed(title: 'Jangan hilang');
        await env.reminders.save(request(keep.id));

        await env.backup.export(dialogTitle: 'Ekspor');
        final file = parseExported(env.filePort.written!);

        await env.dispose();
        env = await createTestEnv(
          failureHook: (processed) {
            if (processed == 1) throw StateError('injected failure');
          },
        );
        final original = await seed(title: 'Data asli');
        await env.reminders.save(request(original.id));

        await expectLater(
          env.backup.applyImport(file),
          throwsA(isA<StateError>()),
        );

        expect(await env.memories.count(), 1);
        final survivor = await env.memories.findById(original.id);
        expect(survivor, isNotNull);
        expect(survivor!.title, 'Data asli');
        expect(await env.reminderDao.count(), 1);
      },
    );

    test(
      'FR-IMP-03: a denied permission warns but the import still succeeds',
      () async {
        final memory = await seed();
        await env.reminders.save(request(memory.id));
        await env.backup.export(dialogTitle: 'Ekspor');
        final file = parseExported(env.filePort.written!);

        await env.dispose();
        env = await createTestEnv(permission: PermissionState.denied);

        final outcome = await env.backup.applyImport(file);

        expect(outcome.memories, 1);
        expect(
          outcome.schedulingWarnings,
          contains('reminder.permission_needed'),
        );
        expect(await env.memories.count(), 1);
      },
    );

    test(
      'a scheduling failure during import never rolls back the data',
      () async {
        final memory = await seed();
        await env.reminders.save(request(memory.id));
        await env.backup.export(dialogTitle: 'Ekspor');
        final file = parseExported(env.filePort.written!);

        await env.dispose();
        env = await createTestEnv();
        env.scheduler.failWithCode = 'platform:exact_alarm_not_permitted';

        final outcome = await env.backup.applyImport(file);

        expect(outcome.schedulingWarnings, contains('reminder.failed'));
        expect(await env.memories.count(), 1);
      },
    );

    test('completed reminders stay completed and are not scheduled', () async {
      final memory = await seed();
      await env.reminders.save(request(memory.id));
      await env.reminders.complete(memory.id);
      await env.backup.export(dialogTitle: 'Ekspor');
      final file = parseExported(env.filePort.written!);
      env.scheduler.scheduled.clear();

      await env.backup.applyImport(file);

      final restored = (await env.reminders.all()).single;
      expect(restored.status, ReminderStatus.completed);
      expect(restored.completedAtUtc, isNotNull);
      expect(env.scheduler.scheduled, isEmpty);
    });
  });

  group('deleteAllData (FR-SET-04)', () {
    test(
      'wipes rows, cancels every notification and clears settings',
      () async {
        final memory = await seed();
        await env.reminders.save(request(memory.id));
        await env.settings.setOnboardingComplete(true);
        await env.settings.setLastKnownTimezone('Asia/Jakarta');

        await env.backup.deleteAllData();

        expect(await env.memories.count(), 0);
        expect(await env.reminderDao.count(), 0);
        expect(env.scheduler.cancelAllCalls, 1);
        expect(env.settings.onboardingComplete, isFalse);
        expect(env.settings.lastKnownTimezone, isNull);
        expect(env.settings.lastReconcileAtUtc, isNull);
      },
    );

    test('the reported memory count never exposes content', () async {
      await seed(title: 'Rahasia');
      expect(await env.backup.memoryCount(), 1);
    });
  });
}
