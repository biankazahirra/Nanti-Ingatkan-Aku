import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/core/time.dart';
import 'package:nanti_ingatkan_aku/features/memories/domain/memory.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/due_state.dart';
import 'package:nanti_ingatkan_aku/features/reminders/domain/reminder.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

Memory _memory(String id, {bool archived = false}) => Memory(
  id: id,
  title: 'Catatan $id',
  body: 'isi',
  category: MemoryCategory.general,
  isArchived: archived,
  createdAtUtc: DateTime.utc(2026, 1, 1),
  updatedAtUtc: DateTime.utc(2026, 1, 1),
);

Reminder _reminder(
  String memoryId,
  DateTime dueUtc, {
  ReminderStatus status = ReminderStatus.pending,
  String id = 'r',
}) => Reminder(
  id: '$id-$memoryId',
  memoryId: memoryId,
  notificationId:
      memoryId.codeUnits.fold<int>(1, (a, b) => a * 31 + b) % 0x7FFFFFFF,
  dueAtUtc: dueUtc.toUtc(),
  scheduledLocalDatetime: formatLocalDateTimeFields(dueUtc.toUtc()),
  scheduledTimezone: 'Asia/Jakarta',
  status: status,
  createdAtUtc: DateTime.utc(2026, 1, 1),
  updatedAtUtc: DateTime.utc(2026, 1, 1),
);

TodayEntry _entry(
  String id,
  DateTime dueUtc, {
  ReminderStatus status = ReminderStatus.pending,
  bool archived = false,
}) => TodayEntry(
  reminder: _reminder(id, dueUtc, status: status),
  memory: _memory(id, archived: archived),
);

void main() {
  // `tz.getLocation` below runs while `main` is being evaluated, so the
  // database must be ready before the zone lookup, not in `setUpAll`.
  tzdata.initializeTimeZones();

  final jakarta = tz.getLocation('Asia/Jakarta');
  // 2026-10-23T02:00Z == 09:00 local in Jakarta.
  final now = DateTime.utc(2026, 10, 23, 2);

  DueGroups group(List<TodayEntry> entries, {tz.Location? zone}) =>
      groupDueItems(entries: entries, nowUtc: now, zone: zone ?? jakarta);

  test('an empty input produces an empty result', () {
    final groups = group(const []);
    expect(groups.isEmpty, isTrue);
    expect(groups.length, 0);
  });

  test('FR-TODAY-01: past instants are overdue, not a stored flag', () {
    final groups = group([
      _entry('past', DateTime.utc(2026, 10, 23, 1)),
      _entry('future', DateTime.utc(2026, 10, 23, 5)),
    ]);
    expect(groups.overdue.single.memory.id, 'past');
    expect(groups.today.single.memory.id, 'future');
    expect(groups.upcoming, isEmpty);
  });

  test('a due instant exactly equal to now counts as overdue', () {
    final groups = group([_entry('now', now)]);
    expect(groups.overdue.single.memory.id, 'now');
    expect(groups.today, isEmpty);
  });

  test('same local day splits into today, later days into upcoming', () {
    final groups = group([
      _entry('today', DateTime.utc(2026, 10, 23, 10)), // 17:00 local
      _entry('tomorrow', DateTime.utc(2026, 10, 24, 1)), // 08:00 local
      _entry('plus7', DateTime.utc(2026, 10, 30, 1)), // 08:00 local
      _entry('plus8', DateTime.utc(2026, 10, 31, 1)), // 08:00 local
    ]);
    expect(groups.today.map((e) => e.memory.id), ['today']);
    expect(groups.upcoming.map((e) => e.memory.id), ['tomorrow', 'plus7']);
    // `plus8` is beyond the 7-day horizon and belongs to no group (FR-TODAY-02).
    expect(groups.length, 3);
  });

  test(
    'FR-TODAY-02: groups are mutually exclusive and ordered by due time',
    () {
      final groups = group([
        _entry('u2', DateTime.utc(2026, 10, 26, 1)),
        _entry('o2', DateTime.utc(2026, 10, 22, 1)),
        _entry('t2', DateTime.utc(2026, 10, 23, 9)),
        _entry('u1', DateTime.utc(2026, 10, 25, 1)),
        _entry('o1', DateTime.utc(2026, 10, 21, 1)),
      ]);
      expect(groups.overdue.map((e) => e.memory.id), ['o1', 'o2']);
      expect(groups.today.map((e) => e.memory.id), ['t2']);
      expect(groups.upcoming.map((e) => e.memory.id), ['u1', 'u2']);
      expect(groups.length, 5);
    },
  );

  test('completed reminders never appear', () {
    final groups = group([
      _entry(
        'done',
        DateTime.utc(2026, 10, 20),
        status: ReminderStatus.completed,
      ),
    ]);
    expect(groups.isEmpty, isTrue);
  });

  test(
    'FR-TODAY-03: a pending reminder of an archived memory stays visible',
    () {
      final groups = group([
        _entry('arch', DateTime.utc(2026, 10, 23, 5), archived: true),
      ]);
      expect(groups.today.single.memory.isArchived, isTrue);
    },
  );

  test('the display zone decides which group a reminder lands in', () {
    // 2026-10-23T18:00Z is 24 Oct 01:00 in Jakarta but still 23 Oct in UTC.
    final entry = _entry('x', DateTime.utc(2026, 10, 23, 18));
    expect(group([entry]).upcoming.single.memory.id, 'x');
    expect(
      group([entry], zone: tz.getLocation('UTC')).today.single.memory.id,
      'x',
    );
  });
}
