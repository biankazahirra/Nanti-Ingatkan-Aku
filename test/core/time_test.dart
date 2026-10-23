import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/core/time.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  group('timestamp formatting (FR-MEM-09)', () {
    test('formats UTC with milliseconds and Z', () {
      expect(
        formatUtcIso(DateTime.utc(2026, 10, 23, 9, 12, 31, 7)),
        '2026-10-23T09:12:31.007Z',
      );
    });

    test('lexicographic order equals chronological order', () {
      final a = formatUtcIso(DateTime.utc(2026, 1, 2, 3, 4, 5, 6));
      final b = formatUtcIso(DateTime.utc(2026, 1, 2, 3, 4, 5, 7));
      final c = formatUtcIso(DateTime.utc(2026, 1, 10, 0, 0, 0, 0));
      expect(a.compareTo(b) < 0, isTrue);
      expect(b.compareTo(c) < 0, isTrue);
    });

    test('parses back to the same instant', () {
      final value = DateTime.utc(2027, 12, 12, 13, 0, 0, 0);
      expect(parseUtcIso(formatUtcIso(value)), value);
    });

    test('rejects garbage without throwing', () {
      expect(parseUtcIso('not a date'), isNull);
      expect(parseUtcIso(null), isNull);
      expect(parseUtcIso(42), isNull);
    });

    test('local fields format is minute precision without a zone', () {
      expect(
        formatLocalDateTimeFields(DateTime(2027, 12, 12, 20, 0)),
        '2027-12-12T20:00',
      );
    });
  });

  group('local time resolution (§7.5)', () {
    test('zone without DST is exact', () {
      final jakarta = tz.getLocation('Asia/Jakarta');
      final result = resolveLocalToUtc(jakarta, DateTime(2027, 12, 12, 20, 0));
      expect(result.utc, DateTime.utc(2027, 12, 12, 13, 0));
      expect(result.shifted, isFalse);
      expect(result.ambiguous, isFalse);
    });

    test('spring-forward gap shifts forward by the gap length', () {
      final berlin = tz.getLocation('Europe/Berlin');
      // 2027-03-28 02:30 does not exist in Berlin: the clock jumps 02:00→03:00.
      final result = resolveLocalToUtc(berlin, DateTime(2027, 3, 28, 2, 30));
      expect(result.shifted, isTrue);
      expect(result.ambiguous, isFalse);
      // The shifted instant renders as 03:30 local, i.e. 01:30Z.
      expect(result.utc, DateTime.utc(2027, 3, 28, 1, 30));
      expect(tz.TZDateTime.from(result.utc, berlin).hour, 3);
      expect(tz.TZDateTime.from(result.utc, berlin).minute, 30);
    });

    test('fall-back overlap chooses the earlier occurrence', () {
      final berlin = tz.getLocation('Europe/Berlin');
      // 2027-10-31 02:30 happens twice: CEST (+2) then CET (+1).
      final result = resolveLocalToUtc(berlin, DateTime(2027, 10, 31, 2, 30));
      expect(result.ambiguous, isTrue);
      expect(result.shifted, isFalse);
      expect(result.utc, DateTime.utc(2027, 10, 31, 0, 30));
    });

    test('normal times are unaffected in a DST zone', () {
      final berlin = tz.getLocation('Europe/Berlin');
      final result = resolveLocalToUtc(berlin, DateTime(2027, 6, 1, 12, 0));
      expect(result.utc, DateTime.utc(2027, 6, 1, 10, 0));
      expect(result.shifted, isFalse);
      expect(result.ambiguous, isFalse);
    });

    test('the same instant keeps its meaning after a device zone change', () {
      final jakarta = tz.getLocation('Asia/Jakarta');
      final tokyo = tz.getLocation('Asia/Tokyo');
      final due = resolveLocalToUtc(jakarta, DateTime(2027, 12, 12, 20, 0));
      // due_at_utc is immutable: only the display changes. 20:00 in Jakarta is
      // 13:00Z, which is 22:00 in Tokyo.
      expect(tz.TZDateTime.from(due.utc, tokyo).hour, 22);
      expect(tz.TZDateTime.from(due.utc, jakarta).hour, 20);
    });
  });
}
