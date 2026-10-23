import 'package:timezone/timezone.dart' as tz;

import '../../memories/domain/memory.dart';
import 'reminder.dart';

/// A reminder joined with its memory — what Today renders.
class TodayEntry {
  const TodayEntry({required this.reminder, required this.memory});

  final Reminder reminder;
  final Memory memory;
}

enum DueBucket { overdue, today, upcoming }

/// FR-TODAY-02 — mutually exclusive groups, ordered as specified in §5.4.
class DueGroups {
  const DueGroups({
    required this.overdue,
    required this.today,
    required this.upcoming,
  });

  const DueGroups.empty()
    : overdue = const [],
      today = const [],
      upcoming = const [];

  /// Oldest due first.
  final List<TodayEntry> overdue;

  /// Earliest due first.
  final List<TodayEntry> today;

  /// Earliest due first, local dates in (today, today + 7].
  final List<TodayEntry> upcoming;

  bool get isEmpty => overdue.isEmpty && today.isEmpty && upcoming.isEmpty;

  int get length => overdue.length + today.length + upcoming.length;
}

/// Groups pending reminders using the device's local calendar date (§5.4).
/// Pure and clock-injected: `overdue` is never a stored flag (FR-TODAY-01).
DueGroups groupDueItems({
  required List<TodayEntry> entries,
  required DateTime nowUtc,
  required tz.Location zone,
}) {
  final today = tz.TZDateTime.from(nowUtc, zone);
  final todayDate = tz.TZDateTime(zone, today.year, today.month, today.day);
  final horizon = todayDate.add(const Duration(days: 8));

  final overdue = <TodayEntry>[];
  final dueToday = <TodayEntry>[];
  final upcoming = <TodayEntry>[];

  for (final entry in entries) {
    final reminder = entry.reminder;
    if (!reminder.isPending) continue;

    if (!reminder.dueAtUtc.isAfter(nowUtc)) {
      overdue.add(entry);
      continue;
    }

    final dueLocal = tz.TZDateTime.from(reminder.dueAtUtc, zone);
    if (dueLocal.isBefore(todayDate)) {
      // Future instant but an earlier local day: impossible except across a
      // backward zone shift; treat as overdue rather than hide it.
      overdue.add(entry);
      continue;
    }
    if (dueLocal.isBefore(horizon)) {
      dueToday.add(entry);
    }
  }

  // `today` holds dues later today; anything on a later day is upcoming.
  final todayOnly = <TodayEntry>[];
  for (final entry in dueToday) {
    final dueLocal = tz.TZDateTime.from(entry.reminder.dueAtUtc, zone);
    final isSameLocalDay =
        dueLocal.year == todayDate.year &&
        dueLocal.month == todayDate.month &&
        dueLocal.day == todayDate.day;
    if (isSameLocalDay) {
      todayOnly.add(entry);
    } else {
      upcoming.add(entry);
    }
  }

  int byDue(TodayEntry a, TodayEntry b) =>
      a.reminder.dueAtUtc.compareTo(b.reminder.dueAtUtc);

  overdue.sort(byDue);
  todayOnly.sort(byDue);
  upcoming.sort(byDue);

  return DueGroups(overdue: overdue, today: todayOnly, upcoming: upcoming);
}
