import 'due_state.dart';
import 'reminder.dart';

/// Everything a caller needs to schedule one reminder.
class ReminderRequest {
  const ReminderRequest({
    required this.memoryId,
    required this.dueAtUtc,
    required this.scheduledLocalDatetime,
    required this.scheduledTimezone,
    this.notificationTitle,
  });

  final String memoryId;
  final DateTime dueAtUtc;

  /// `YYYY-MM-DDTHH:mm` of the picked local wall-clock time.
  final String scheduledLocalDatetime;
  final String scheduledTimezone;

  /// Only used for the OS notification; the memory stays the source of truth.
  final String? notificationTitle;
}

abstract class ReminderRepository {
  /// Creates or replaces the single reminder of a memory (FR-REM-01).
  Future<Reminder> save(ReminderRequest request);

  /// FR-REM-08 / FR-REM-01 — the only path back to pending.
  Future<Reminder> reopen(String memoryId, ReminderRequest request);

  Future<Reminder> complete(String memoryId);

  Future<void> deleteForMemory(String memoryId);

  /// Cancels one OS notification without touching stored rows (used after a
  /// cascade delete where the row is already gone — FR-MEM-05).
  Future<void> cancelNotification(int notificationId);

  Future<Reminder?> findByMemory(String memoryId);

  Future<Map<String, Reminder>> byMemoryIds(Iterable<String> memoryIds);

  Future<List<TodayEntry>> pendingEntries();

  Future<List<Reminder>> all();

  Future<Set<int>> usedNotificationIds();

  Future<int> count();

  Future<int> pendingCount();
}
