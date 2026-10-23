import '../../../core/failures.dart';
import '../../../core/ids.dart';
import '../../../core/logging.dart';
import '../../memories/data/memory_dao.dart';
import '../../memories/domain/memory.dart';
import '../domain/due_state.dart';
import '../domain/reminder.dart';
import '../domain/reminder_repository.dart';
import '../domain/reminder_scheduler.dart';
import '../platform/notification_content_policy.dart';
import 'reminder_dao.dart';

/// FR-REM-04 — every mutation writes SQLite first, then reconciles the OS
/// schedule. A delivery failure never rolls back or deletes a reminder.
class ReminderRepositoryImpl implements ReminderRepository {
  ReminderRepositoryImpl({
    required this._dao,
    required this._memoryDao,
    required this._scheduler,
    required this._idGenerator,
    required this._contentPolicy,
    required this._nowUtc,
  });

  final ReminderDao _dao;
  final MemoryDao _memoryDao;
  final ReminderScheduler _scheduler;
  final IdGenerator _idGenerator;
  final NotificationContentPolicy _contentPolicy;
  final DateTime Function() _nowUtc;

  @override
  Future<Reminder> save(ReminderRequest request) async {
    final memory = await _memoryDao.findById(request.memoryId);
    if (memory == null) {
      throw const StorageFailure('memory_not_found');
    }

    final now = _nowUtc().toUtc();
    final existing = await _dao.findByMemory(request.memoryId);
    final reminderId = existing?.id ?? _idGenerator.newId();
    final notificationId =
        existing?.notificationId ??
        allocateNotificationId(reminderId, await _dao.notificationIds());

    var reminder = Reminder(
      id: reminderId,
      memoryId: request.memoryId,
      notificationId: notificationId,
      dueAtUtc: request.dueAtUtc.toUtc(),
      scheduledLocalDatetime: request.scheduledLocalDatetime,
      scheduledTimezone: request.scheduledTimezone,
      status: ReminderStatus.pending,
      schedulingStatus: SchedulingStatus.deferred,
      createdAtUtc: existing?.createdAtUtc ?? now,
      updatedAtUtc: now,
    );

    // Persist first (FR-REM-04).
    await _dao.upsert(reminder);
    reminder = await _deliver(reminder, memory);
    return reminder;
  }

  @override
  Future<Reminder> reopen(String memoryId, ReminderRequest request) async {
    final existing = await _dao.findByMemory(memoryId);
    if (existing == null) {
      return save(request);
    }
    final now = _nowUtc().toUtc();
    var reminder = existing.copyWith(
      dueAtUtc: request.dueAtUtc.toUtc(),
      scheduledLocalDatetime: request.scheduledLocalDatetime,
      scheduledTimezone: request.scheduledTimezone,
      status: ReminderStatus.pending,
      schedulingStatus: SchedulingStatus.deferred,
      updatedAtUtc: now,
      clearCompletedAt: true,
      clearScheduleError: true,
    );
    await _dao.upsert(reminder);

    final memory = await _memoryDao.findById(memoryId);
    if (memory == null) {
      throw const StorageFailure('memory_not_found');
    }
    reminder = await _deliver(reminder, memory);
    return reminder;
  }

  @override
  Future<Reminder> complete(String memoryId) async {
    final existing = await _dao.findByMemory(memoryId);
    if (existing == null) {
      throw const StorageFailure('reminder_not_found');
    }
    final now = _nowUtc().toUtc();
    final completed = existing.copyWith(
      status: ReminderStatus.completed,
      completedAtUtc: now,
      updatedAtUtc: now,
    );
    await _dao.upsert(completed);
    await _scheduler.cancel(completed.notificationId);
    return completed;
  }

  @override
  Future<void> deleteForMemory(String memoryId) async {
    final existing = await _dao.findByMemory(memoryId);
    await _dao.deleteForMemory(memoryId);
    if (existing != null) {
      await _scheduler.cancel(existing.notificationId);
    }
  }

  @override
  Future<void> cancelNotification(int notificationId) =>
      _scheduler.cancel(notificationId);

  @override
  Future<Reminder?> findByMemory(String memoryId) =>
      _dao.findByMemory(memoryId);

  @override
  Future<Map<String, Reminder>> byMemoryIds(Iterable<String> memoryIds) async {
    final wanted = memoryIds.toSet();
    if (wanted.isEmpty) return const {};
    final all = await _dao.all();
    return {
      for (final reminder in all)
        if (wanted.contains(reminder.memoryId)) reminder.memoryId: reminder,
    };
  }

  @override
  Future<List<TodayEntry>> pendingEntries() => _dao.pendingEntries();

  @override
  Future<List<Reminder>> all() => _dao.all();

  @override
  Future<Set<int>> usedNotificationIds() => _dao.notificationIds();

  @override
  Future<int> count() => _dao.count();

  @override
  Future<int> pendingCount() => _dao.countPending();

  Future<Reminder> _deliver(Reminder reminder, Memory memory) async {
    final permission = await _scheduler.ensurePermission();
    if (permission != PermissionState.granted) {
      logEvent(LogCodes.permissionNeeded);
      final updated = reminder.copyWith(
        status: ReminderStatus.pending,
        schedulingStatus: SchedulingStatus.permissionNeeded,
        scheduleAttemptAtUtc: _nowUtc().toUtc(),
        updatedAtUtc: _nowUtc().toUtc(),
      );
      await _dao.upsert(updated);
      return updated;
    }

    final text = await _contentPolicy.resolve(memory);
    final outcome = await _scheduler.schedule(
      notificationId: reminder.notificationId,
      dueAtUtc: reminder.dueAtUtc,
      title: text.title,
      body: text.body,
      payload: reminder.payload,
    );

    final now = _nowUtc().toUtc();
    final updated = switch (outcome.status) {
      ScheduleOutcomeStatus.scheduled => reminder.copyWith(
        schedulingStatus: SchedulingStatus.scheduled,
        precision: outcome.precisionExact
            ? ReminderPrecision.exact
            : ReminderPrecision.inexact,
        scheduleAttemptAtUtc: now,
        updatedAtUtc: now,
        clearScheduleError: true,
      ),
      ScheduleOutcomeStatus.permissionNeeded => reminder.copyWith(
        schedulingStatus: SchedulingStatus.permissionNeeded,
        scheduleAttemptAtUtc: now,
        updatedAtUtc: now,
      ),
      ScheduleOutcomeStatus.failed => reminder.copyWith(
        schedulingStatus: SchedulingStatus.schedulingFailed,
        scheduleErrorCode: outcome.errorCode,
        scheduleAttemptAtUtc: now,
        updatedAtUtc: now,
      ),
    };
    await _dao.upsert(updated);
    if (updated.schedulingStatus == SchedulingStatus.schedulingFailed) {
      logEvent(LogCodes.scheduleFailed, detail: outcome.errorCode);
    }
    return updated;
  }
}
