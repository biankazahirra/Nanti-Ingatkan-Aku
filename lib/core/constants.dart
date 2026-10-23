/// Central limits and timings. Values are traceable to the PRD; change them here
/// only, never inline at a call site.
class Limits {
  const Limits._();

  /// FR-MEM-01: title is 1-120 user-perceived characters after trim.
  static const int titleMax = 120;

  /// Counter appears after this many characters (FR-5.7).
  static const int titleCounterThreshold = 100;

  /// FR-MEM-01: body cap.
  static const int bodyMax = 10000;

  static const int personNameMax = 80;
  static const int itemNameMax = 120;

  /// FR-SRH-02: at most 5 tokens, each at most 50 characters.
  static const int queryTokenMax = 5;
  static const int queryTokenLengthMax = 50;

  /// FR-MEM-02: page size for lists.
  static const int pageSize = 50;

  /// FR-TODAY-06: items rendered per Today group.
  static const int todayGroupLimit = 20;

  /// FR-REM-09 / DEC-07: nearest pending reminders handed to the OS.
  static const int scheduleCap = 100;

  /// FR-SRH-06 / NFR-PERF-03.
  static const Duration searchDebounce = Duration(milliseconds: 150);

  /// FR-REM-12 / NFR-PERF-06.
  static const Duration reconcileThrottle = Duration(seconds: 60);

  /// FR-REM-04: Today refresh cadence while visible.
  static const Duration todayTick = Duration(seconds: 60);

  /// FR-IMP-01 file limits.
  static const int importMaxBytes = 10 * 1024 * 1024;
  static const int importMaxRows = 20000;

  /// FR-SET-07: backup nudge after this many memories.
  static const int backupNudgeMemoryCount = 10;
  static const Duration backupNudgeInterval = Duration(days: 30);

  /// FR-MEM-10 / FR-REM-04: undo windows.
  static const Duration undoWindow = Duration(seconds: 5);
}
