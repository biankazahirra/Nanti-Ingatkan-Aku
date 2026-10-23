import 'package:flutter/foundation.dart';

/// Release builds log event codes only. Never pass titles, bodies, query
/// strings, file contents, or notification text (NFR-SEC-04, §7.10).
class LogCodes {
  const LogCodes._();

  static const String scheduleFailed = 'REM_SCHEDULE_FAILED';
  static const String scheduleOk = 'REM_SCHEDULE_OK';
  static const String permissionNeeded = 'REM_PERMISSION_NEEDED';
  static const String reconcileDone = 'REM_RECONCILE_DONE';
  static const String storageFailed = 'DB_STORAGE_FAILED';
  static const String importRejected = 'IMP_REJECTED';
  static const String importOk = 'IMP_OK';
  static const String exportOk = 'EXP_OK';
  static const String exportCancelled = 'EXP_CANCELLED';
  static const String unknownTimezone = 'TZ_UNKNOWN_ID';
  static const String notificationTapMissing = 'REM_TAP_MISSING';
}

void logEvent(String code, {String? detail}) {
  if (kReleaseMode) return;
  debugPrint(detail == null ? code : '$code:$detail');
}
