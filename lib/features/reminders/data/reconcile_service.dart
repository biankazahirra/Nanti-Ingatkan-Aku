import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../memories/data/memory_dao.dart';
import '../../memories/domain/memory.dart';
import '../../settings/data/settings_repository.dart';
import '../domain/reminder.dart';
import '../domain/reminder_scheduler.dart';
import '../platform/notification_content_policy.dart';
import 'reminder_dao.dart';

/// FR-REM-12 — repairs OS schedules against the database. Runs on launch, on
/// resume (throttled by [Limits.reconcileThrottle]), after mutations, after
/// import, and after a permission grant or zone change.
class ReconcileService {
  ReconcileService({
    required this._dao,
    required this._memoryDao,
    required this._scheduler,
    required this._settings,
    required this._contentPolicy,
    required this._nowUtc,
  });

  final ReminderDao _dao;
  final MemoryDao _memoryDao;
  final ReminderScheduler _scheduler;
  final SettingsRepository _settings;
  final NotificationContentPolicy _contentPolicy;
  final DateTime Function() _nowUtc;

  bool _running = false;

  /// Result of the last pass; surfaced in Settings and the Today banner.
  SchedulingStatus? lastUnresolvedStatus;

  Future<void> reconcile({bool force = false}) async {
    if (_running) return;
    final now = _nowUtc().toUtc();
    if (!force) {
      final last = _settings.lastReconcileAtUtc;
      if (last != null && now.difference(last) < Limits.reconcileThrottle) {
        return;
      }
    }

    _running = true;
    try {
      await _run(now);
    } finally {
      _running = false;
      await _settings.setLastReconcileAtUtc(now);
    }
  }

  Future<void> _run(DateTime now) async {
    final reminders = await _dao.all();
    if (reminders.isEmpty) {
      lastUnresolvedStatus = null;
      return;
    }

    final memories = <String, Memory>{};
    for (final archived in const [false, true]) {
      for (final memory in await _memoryDao.list(
        archived: archived,
        limit: Limits.importMaxRows,
      )) {
        memories[memory.id] = memory;
      }
    }

    Set<int>? scheduledIds;
    try {
      scheduledIds = await _scheduler.pendingNotificationIds();
    } on Object {
      scheduledIds = null; // Platform cannot enumerate; skip staleness checks.
    }

    // Step 2 — cancel for completed reminders and rows whose memory is gone.
    for (final reminder in reminders) {
      final orphan = !memories.containsKey(reminder.memoryId);
      if (reminder.isCompleted || orphan) {
        if (scheduledIds == null ||
            scheduledIds.contains(reminder.notificationId)) {
          await _scheduler.cancel(reminder.notificationId);
        }
        if (orphan) {
          await _dao.deleteForMemory(reminder.memoryId);
        }
      }
    }

    // Steps 3-4 — pending, still in the future, nearest first.
    final futurePending =
        reminders.where((r) => r.isPending && r.dueAtUtc.isAfter(now)).toList()
          ..sort((a, b) => a.dueAtUtc.compareTo(b.dueAtUtc));

    final selected = futurePending.take(Limits.scheduleCap).toList();
    final deferred = futurePending.skip(Limits.scheduleCap).toList();

    PermissionState? permission;
    if (selected.isNotEmpty) {
      permission = await _scheduler.ensurePermission();
    }

    final attempted = <Reminder>[];
    for (final reminder in selected) {
      if (permission != PermissionState.granted) {
        attempted.add(
          _withStatus(reminder, SchedulingStatus.permissionNeeded, now),
        );
        continue;
      }

      final missing =
          scheduledIds == null ||
          !scheduledIds.contains(reminder.notificationId);
      final needsRetry =
          reminder.schedulingStatus != SchedulingStatus.scheduled;
      if (!missing && !needsRetry) continue;

      final memory = memories[reminder.memoryId];
      if (memory == null) continue;
      final text = await _contentPolicy.resolve(memory);

      final outcome = await _scheduler.schedule(
        notificationId: reminder.notificationId,
        dueAtUtc: reminder.dueAtUtc,
        title: text.title,
        body: text.body,
        payload: reminder.payload,
      );
      attempted.add(switch (outcome.status) {
        ScheduleOutcomeStatus.scheduled => reminder.copyWith(
          schedulingStatus: SchedulingStatus.scheduled,
          precision: outcome.precisionExact
              ? ReminderPrecision.exact
              : ReminderPrecision.inexact,
          scheduleAttemptAtUtc: now,
          updatedAtUtc: now,
          clearScheduleError: true,
        ),
        ScheduleOutcomeStatus.permissionNeeded => _withStatus(
          reminder,
          SchedulingStatus.permissionNeeded,
          now,
        ),
        ScheduleOutcomeStatus.failed => reminder.copyWith(
          schedulingStatus: SchedulingStatus.schedulingFailed,
          scheduleErrorCode: outcome.errorCode,
          scheduleAttemptAtUtc: now,
          updatedAtUtc: now,
        ),
      });
    }

    // Step 5 — everything beyond the cap waits for the next pass.
    for (final reminder in deferred) {
      if (reminder.schedulingStatus == SchedulingStatus.deferred) continue;
      attempted.add(
        _withStatus(reminder, SchedulingStatus.deferred, now, clearError: true),
      );
    }

    for (final reminder in attempted) {
      await _dao.upsert(reminder);
    }

    // Step 6/7 — persist outcome and surface unresolved failures.
    lastUnresolvedStatus = _worstStatus(attempted);
    logEvent(
      LogCodes.reconcileDone,
      detail: 'repaired=${attempted.length} deferred=${deferred.length}',
    );
  }

  Reminder _withStatus(
    Reminder reminder,
    SchedulingStatus status,
    DateTime now, {
    bool clearError = false,
  }) {
    return reminder.copyWith(
      schedulingStatus: status,
      scheduleAttemptAtUtc: now,
      updatedAtUtc: now,
      clearScheduleError: clearError,
    );
  }

  SchedulingStatus? _worstStatus(List<Reminder> reminders) {
    if (reminders.any(
      (r) => r.schedulingStatus == SchedulingStatus.schedulingFailed,
    )) {
      return SchedulingStatus.schedulingFailed;
    }
    if (reminders.any(
      (r) => r.schedulingStatus == SchedulingStatus.permissionNeeded,
    )) {
      return SchedulingStatus.permissionNeeded;
    }
    return null;
  }
}
