import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/core/constants.dart';
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

  ReminderRequest request(String memoryId, {int dayOffset = 1}) =>
      ReminderRequest(
        memoryId: memoryId,
        dueAtUtc: env.clock.nowUtc().add(Duration(days: dayOffset)),
        scheduledLocalDatetime: '2026-10-24T09:00',
        scheduledTimezone: 'Asia/Jakarta',
      );

  Future<String> newMemory({String title = 'Catatan'}) async {
    final memory = await env.memories.create(MemoryDraft(title: title));
    return memory.id;
  }

  test('an empty database leaves no unresolved status', () async {
    await env.reconcile.reconcile(force: true);
    expect(env.reconcile.lastUnresolvedStatus, isNull);
    expect(env.scheduler.scheduled, isEmpty);
  });

  test(
    'FR-REM-12: a lost OS schedule is repaired, and the throttle holds',
    () async {
      final id = await newMemory();
      await env.reminders.save(request(id));
      expect(env.scheduler.pending, hasLength(1));

      await env.reconcile.reconcile(force: true);
      env.scheduler.scheduled.clear();

      // The OS lost the request; a throttled pass must not hammer the platform.
      env.scheduler.pending.clear();
      await env.reconcile.reconcile();
      expect(env.scheduler.scheduled, isEmpty);

      // Past the throttle window the identical pass repairs it.
      env.clock.advance(Limits.reconcileThrottle + const Duration(seconds: 1));
      await env.reconcile.reconcile();
      expect(env.scheduler.scheduled, hasLength(1));
      expect(env.scheduler.scheduled.single.payload, 'memory:$id');
    },
  );

  test('concurrent passes are single-flight', () async {
    final id = await newMemory();
    await env.reminders.save(request(id));
    // The OS lost it: both the recorded call and the live queue must be empty
    // for the pass to have anything to repair.
    env.scheduler.scheduled.clear();
    env.scheduler.pending.clear();

    await Future.wait([
      env.reconcile.reconcile(force: true),
      env.reconcile.reconcile(force: true),
    ]);

    expect(env.scheduler.scheduled, hasLength(1));
  });

  test('completed reminders are cancelled during a pass', () async {
    final id = await newMemory();
    final saved = await env.reminders.save(request(id));
    await env.reminderDao.upsert(
      saved.copyWith(
        status: ReminderStatus.completed,
        completedAtUtc: env.clock.nowUtc(),
      ),
    );

    await env.reconcile.reconcile(force: true);

    expect(env.scheduler.cancelled, contains(saved.notificationId));
  });

  test('a reminder whose memory vanished is cancelled and removed', () async {
    final id = await newMemory();
    final saved = await env.reminders.save(request(id));

    // Simulates a database restored from an external tool that ignored the FK.
    await env.database.db.execute('PRAGMA foreign_keys = OFF');
    await env.memoryDao.delete(id);
    await env.database.db.execute('PRAGMA foreign_keys = ON');
    expect(await env.reminderDao.count(), 1);

    await env.reconcile.reconcile(force: true);

    expect(await env.reminderDao.count(), 0);
    expect(env.scheduler.cancelled, contains(saved.notificationId));
  });

  test('a reminder already due is never handed to the OS', () async {
    final id = await newMemory();
    await env.reminders.save(
      ReminderRequest(
        memoryId: id,
        dueAtUtc: env.clock.nowUtc().subtract(const Duration(hours: 2)),
        scheduledLocalDatetime: '2026-10-23T07:00',
        scheduledTimezone: 'Asia/Jakarta',
      ),
    );
    env.scheduler.scheduled.clear();

    await env.reconcile.reconcile(force: true);

    expect(env.scheduler.scheduled, isEmpty);
    // It stays pending, so Today can still show it as overdue.
    expect(await env.reminders.pendingCount(), 1);
  });

  test(
    'only the nearest reminders are scheduled; the rest are deferred',
    () async {
      for (var i = 0; i < Limits.scheduleCap + 2; i++) {
        final id = await env.memories.create(MemoryDraft(title: 'Catatan $i'));
        await env.reminders.save(request(id.id, dayOffset: 1 + i));
      }

      await env.reconcile.reconcile(force: true);

      expect(
        await env.reminderDao.countBySchedulingStatus(
          SchedulingStatus.deferred,
        ),
        2,
      );
      expect(
        await env.reminderDao.countBySchedulingStatus(
          SchedulingStatus.scheduled,
        ),
        Limits.scheduleCap,
      );
    },
  );

  test('a denied permission is reported as the worst status', () async {
    await env.dispose();
    env = await createTestEnv(permission: PermissionState.denied);
    final id = await newMemory();
    final saved = await env.reminders.save(request(id));

    await env.reconcile.reconcile(force: true);

    expect(
      env.reconcile.lastUnresolvedStatus,
      SchedulingStatus.permissionNeeded,
    );
    expect(
      (await env.reminderDao.findByMemory(id))!.schedulingStatus,
      SchedulingStatus.permissionNeeded,
    );
    expect(saved.schedulingStatus, SchedulingStatus.permissionNeeded);
  });

  test(
    'a platform failure is retried and stored with its error code',
    () async {
      final id = await newMemory();
      await env.reminders.save(request(id));
      // The OS lost the schedule, so the pass retries it and hits the failure.
      env.scheduler.scheduled.clear();
      env.scheduler.pending.clear();
      env.scheduler.failWithCode = 'platform:exact_alarm_not_permitted';

      await env.reconcile.reconcile(force: true);

      expect(
        env.reconcile.lastUnresolvedStatus,
        SchedulingStatus.schedulingFailed,
      );
      final row = (await env.reminderDao.findByMemory(id))!;
      expect(row.schedulingStatus, SchedulingStatus.schedulingFailed);
      expect(row.scheduleErrorCode, 'platform:exact_alarm_not_permitted');
    },
  );

  test('a platform that cannot enumerate its queue still schedules', () async {
    final id = await newMemory();

    await env.reconcile.reconcile(force: true);
    await env.reminders.save(request(id));
    env.scheduler.scheduled.clear();
    // `pendingNotificationIds` throwing means "unknown", never "cancel".
    env.scheduler.failEnumeration = true;

    await env.reconcile.reconcile(force: true);

    expect(env.scheduler.cancelled, isEmpty);
  });
}
