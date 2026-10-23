import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/core/failures.dart';
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

  Future<String> newMemory({String title = 'Ambil paket'}) async {
    final memory = await env.memories.create(MemoryDraft(title: title));
    return memory.id;
  }

  Future<void> restart({
    PermissionState permission = PermissionState.granted,
    bool exactAvailable = true,
  }) async {
    await env.dispose();
    env = await createTestEnv(
      permission: permission,
      exactAvailable: exactAvailable,
    );
  }

  ReminderRequest request(
    String memoryId, {
    DateTime? dueAtUtc,
    String local = '2026-10-24T09:00',
  }) => ReminderRequest(
    memoryId: memoryId,
    dueAtUtc: dueAtUtc ?? DateTime.utc(2026, 10, 24, 2),
    scheduledLocalDatetime: local,
    scheduledTimezone: 'Asia/Jakarta',
  );

  test('FR-REM-04: the row is written before the OS is asked', () async {
    final id = await newMemory();
    final reminder = await env.reminders.save(request(id));

    expect(reminder.schedulingStatus, SchedulingStatus.scheduled);
    expect(reminder.precision, ReminderPrecision.exact);
    expect(env.scheduler.scheduled, hasLength(1));
    expect(env.scheduler.scheduled.single.payload, 'memory:$id');
    expect(env.scheduler.scheduled.single.title, 'Ambil paket');
    expect(await env.reminders.findByMemory(id), isNotNull);
  });

  test('FR-REM-01: one memory keeps one reminder across re-saves', () async {
    final id = await newMemory();
    final first = await env.reminders.save(request(id));
    final second = await env.reminders.save(
      request(id, dueAtUtc: DateTime.utc(2026, 10, 25, 2)),
    );

    expect(second.id, first.id);
    expect(second.notificationId, first.notificationId);
    expect(second.createdAtUtc, first.createdAtUtc);
    expect(await env.reminders.count(), 1);
  });

  test('FR-REM-05: notification ids are unique across memories', () async {
    final a = await newMemory(title: 'A');
    final b = await newMemory(title: 'B');
    final first = await env.reminders.save(request(a));
    final second = await env.reminders.save(request(b));

    expect(first.notificationId, isNot(second.notificationId));
    expect(await env.reminders.usedNotificationIds(), hasLength(2));
  });

  test(
    'FR-REM-06: a denied permission keeps the note and flags the reminder',
    () async {
      await restart(permission: PermissionState.denied);
      final id = await newMemory();
      final reminder = await env.reminders.save(request(id));

      expect(reminder.status, ReminderStatus.pending);
      expect(reminder.schedulingStatus, SchedulingStatus.permissionNeeded);
      expect(await env.reminders.findByMemory(id), isNotNull);
      expect(env.scheduler.scheduled, isEmpty);
    },
  );

  test(
    'a delivery failure is recorded and never deletes the reminder',
    () async {
      env.scheduler.failWithCode = 'platform:exact_alarm_not_permitted';
      final id = await newMemory();

      final reminder = await env.reminders.save(request(id));

      expect(reminder.schedulingStatus, SchedulingStatus.schedulingFailed);
      expect(reminder.scheduleErrorCode, 'platform:exact_alarm_not_permitted');
      expect(await env.reminders.findByMemory(id), isNotNull);
    },
  );

  test('FR-REM-07: an inexact grant is stored as inexact precision', () async {
    await restart(exactAvailable: false);
    final id = await newMemory();

    final reminder = await env.reminders.save(request(id));

    expect(reminder.precision, ReminderPrecision.inexact);
    expect(reminder.schedulingStatus, SchedulingStatus.scheduled);
  });

  test(
    'FR-SET-03: hidden content replaces the title and body sent to the OS',
    () async {
      await env.settings.setHideNotificationContent(true);
      final id = await newMemory(title: 'PIN ATM 1234');

      await env.reminders.save(request(id));

      final call = env.scheduler.scheduled.single;
      expect(call.title, isNot(contains('1234')));
      expect(call.body, isNot(contains('1234')));
    },
  );

  test(
    'FR-REM-03: completing cancels the notification and keeps the row',
    () async {
      final id = await newMemory();
      final saved = await env.reminders.save(request(id));

      final completed = await env.reminders.complete(id);

      expect(completed.status, ReminderStatus.completed);
      expect(completed.completedAtUtc, env.clock.nowUtc());
      expect(completed.dueAtUtc, saved.dueAtUtc);
      expect(env.scheduler.cancelled, contains(saved.notificationId));
      expect(await env.reminders.pendingCount(), 0);
    },
  );

  test('completing a reminder that does not exist fails loudly', () async {
    final id = await newMemory();
    await expectLater(
      env.reminders.complete(id),
      throwsA(isA<StorageFailure>()),
    );
  });

  test('FR-REM-08: reopen is the only path back to pending', () async {
    final id = await newMemory();
    await env.reminders.save(request(id));
    await env.reminders.complete(id);

    final reopened = await env.reminders.reopen(
      id,
      request(id, dueAtUtc: DateTime.utc(2026, 11, 1, 2)),
    );

    expect(reopened.status, ReminderStatus.pending);
    expect(reopened.completedAtUtc, isNull);
    expect(reopened.schedulingStatus, SchedulingStatus.scheduled);
    expect(reopened.dueAtUtc, DateTime.utc(2026, 11, 1, 2));
    expect(await env.reminders.pendingCount(), 1);
  });

  test('reopen on a memory without a reminder creates one', () async {
    final id = await newMemory();
    final reminder = await env.reminders.reopen(id, request(id));
    expect(reminder.status, ReminderStatus.pending);
    expect(await env.reminders.count(), 1);
  });

  test('FR-MEM-05: deleting a memory removes its reminder row too', () async {
    final id = await newMemory();
    final saved = await env.reminders.save(request(id));

    await env.memories.delete(id);

    expect(await env.reminders.findByMemory(id), isNull);
    expect(await env.reminders.count(), 0);
    expect(env.scheduler.cancelled, contains(saved.notificationId));
  });

  test(
    'saving a reminder for a missing memory fails without writing a row',
    () async {
      await expectLater(
        env.reminders.save(request('does-not-exist')),
        throwsA(isA<StorageFailure>()),
      );
      expect(await env.reminders.count(), 0);
    },
  );

  test('byMemoryIds only returns the requested memories', () async {
    final a = await newMemory(title: 'A');
    final b = await newMemory(title: 'B');
    await env.reminders.save(request(a));
    await env.reminders.save(request(b));

    final map = await env.reminders.byMemoryIds([b]);

    expect(map.keys, [b]);
    expect(await env.reminders.byMemoryIds(const []), isEmpty);
  });
}
