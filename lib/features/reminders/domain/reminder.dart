/// FR-REM-03 — lifecycle state. Delivery facts live in [SchedulingStatus] and
/// never change a memory.
enum ReminderStatus {
  pending('pending'),
  completed('completed');

  const ReminderStatus(this.dbValue);

  final String dbValue;

  static ReminderStatus? tryParse(String? value) {
    for (final status in ReminderStatus.values) {
      if (status.dbValue == value) return status;
    }
    return null;
  }
}

/// FR-REM-03 — orthogonal delivery facts, meaningful only while pending.
enum SchedulingStatus {
  scheduled('scheduled'),
  deferred('deferred'),
  permissionNeeded('permission_needed'),
  schedulingFailed('scheduling_failed');

  const SchedulingStatus(this.dbValue);

  final String dbValue;

  static SchedulingStatus? tryParse(String? value) {
    for (final status in SchedulingStatus.values) {
      if (status.dbValue == value) return status;
    }
    return null;
  }
}

/// FR-REM-07 — `exact` only when the platform grants it.
enum ReminderPrecision {
  exact('exact'),
  inexact('inexact');

  const ReminderPrecision(this.dbValue);

  final String dbValue;

  static ReminderPrecision? tryParse(String? value) {
    for (final precision in ReminderPrecision.values) {
      if (precision.dbValue == value) return precision;
    }
    return null;
  }
}

class Reminder {
  const Reminder({
    required this.id,
    required this.memoryId,
    required this.notificationId,
    required this.dueAtUtc,
    required this.scheduledLocalDatetime,
    required this.scheduledTimezone,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    this.precision = ReminderPrecision.inexact,
    this.status = ReminderStatus.pending,
    this.schedulingStatus = SchedulingStatus.deferred,
    this.completedAtUtc,
    this.scheduleAttemptAtUtc,
    this.scheduleErrorCode,
  });

  final String id;
  final String memoryId;

  /// Device-local: regenerated on import (FR-IMP-04).
  final int notificationId;

  /// Immutable instant; never reinterpreted after a zone change (§7.5).
  final DateTime dueAtUtc;

  /// `YYYY-MM-DDTHH:mm`, display and recovery only.
  final String scheduledLocalDatetime;

  final String scheduledTimezone;
  final ReminderPrecision precision;
  final ReminderStatus status;
  final SchedulingStatus schedulingStatus;
  final DateTime? completedAtUtc;
  final DateTime? scheduleAttemptAtUtc;
  final String? scheduleErrorCode;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;

  bool get isPending => status == ReminderStatus.pending;

  bool get isCompleted => status == ReminderStatus.completed;

  /// FR-TODAY-01 — derived, never persisted.
  bool isDue(DateTime nowUtc) => isPending && !dueAtUtc.isAfter(nowUtc);

  /// §5.6 — the display zone differs from the zone the reminder was set in.
  bool zoneDiffersFrom(String currentTimezone) =>
      scheduledTimezone != currentTimezone;

  Reminder copyWith({
    int? notificationId,
    DateTime? dueAtUtc,
    String? scheduledLocalDatetime,
    String? scheduledTimezone,
    ReminderPrecision? precision,
    ReminderStatus? status,
    SchedulingStatus? schedulingStatus,
    DateTime? completedAtUtc,
    DateTime? scheduleAttemptAtUtc,
    String? scheduleErrorCode,
    DateTime? updatedAtUtc,
    bool clearCompletedAt = false,
    bool clearScheduleError = false,
  }) {
    return Reminder(
      id: id,
      memoryId: memoryId,
      notificationId: notificationId ?? this.notificationId,
      dueAtUtc: dueAtUtc ?? this.dueAtUtc,
      scheduledLocalDatetime:
          scheduledLocalDatetime ?? this.scheduledLocalDatetime,
      scheduledTimezone: scheduledTimezone ?? this.scheduledTimezone,
      precision: precision ?? this.precision,
      status: status ?? this.status,
      schedulingStatus: schedulingStatus ?? this.schedulingStatus,
      completedAtUtc: clearCompletedAt
          ? null
          : (completedAtUtc ?? this.completedAtUtc),
      scheduleAttemptAtUtc: scheduleAttemptAtUtc ?? this.scheduleAttemptAtUtc,
      scheduleErrorCode: clearScheduleError
          ? null
          : (scheduleErrorCode ?? this.scheduleErrorCode),
      createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  /// FR-REM-10 — `memory:<uuid>`.
  String get payload => 'memory:$memoryId';
}
