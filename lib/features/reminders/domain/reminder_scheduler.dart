/// Permission outcome (FR-REM-06).
enum PermissionState { granted, denied, permanentlyDenied }

/// Result of one scheduling attempt. Delivery facts only (FR-REM-04).
class ScheduleOutcome {
  const ScheduleOutcome({
    required this.status,
    this.precisionExact = false,
    this.errorCode,
  });

  const ScheduleOutcome.scheduled({required bool exact})
    : status = ScheduleOutcomeStatus.scheduled,
      precisionExact = exact,
      errorCode = null;

  const ScheduleOutcome.permissionNeeded()
    : status = ScheduleOutcomeStatus.permissionNeeded,
      precisionExact = false,
      errorCode = null;

  const ScheduleOutcome.failed(String code)
    : status = ScheduleOutcomeStatus.failed,
      precisionExact = false,
      errorCode = code;

  final ScheduleOutcomeStatus status;
  final bool precisionExact;
  final String? errorCode;
}

enum ScheduleOutcomeStatus { scheduled, permissionNeeded, failed }

/// Notification port. Implemented by the platform adapter, faked in tests.
abstract class ReminderScheduler {
  Future<PermissionState> ensurePermission();

  /// FR-SET-01 — is the OS currently delivering our notifications at all.
  Future<bool> notificationsEnabled();

  /// FR-REM-07 — false means inexact is the normal path, not an edge case.
  Future<bool> canScheduleExact();

  /// FR-REM-07 — the OS grant screen for exact alarms, offered rather than
  /// demanded. Platforms without one answer `false`.
  Future<bool> requestExactAlarmsPermission();

  Future<ScheduleOutcome> schedule({
    required int notificationId,
    required DateTime dueAtUtc,
    required String title,
    required String body,
    required String payload,
  });

  Future<void> cancel(int notificationId);

  /// Only "delete all data" and post-import cleanup use this (FR-REM-05).
  Future<void> cancelAll();

  Future<Set<int>> pendingNotificationIds();

  /// FR-SET-01 / FR-REM-06 — the OS screen that owns our permission toggles,
  /// which the app itself cannot draw.
  Future<void> openAppSettings();
}
