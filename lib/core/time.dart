import 'package:timezone/timezone.dart' as tz;

/// Outcome of turning a user-chosen local wall-clock time into an instant.
class LocalTimeResolution {
  const LocalTimeResolution({
    required this.utc,
    required this.shifted,
    required this.ambiguous,
  });

  /// The instant to persist (`due_at_utc`).
  final DateTime utc;

  /// True when the chosen local time did not exist (DST gap) and was moved
  /// forward; the UI must say so before saving (§7.5).
  final bool shifted;

  /// True when the chosen local time occurred twice (DST overlap); the earlier
  /// occurrence was chosen (§7.5).
  final bool ambiguous;
}

/// §7.5 — resolve local wall-clock fields to UTC, handling DST gaps and
/// overlaps explicitly instead of silently trusting `TZDateTime`.
///
/// Both candidate instants are derived from the offsets around the chosen time:
/// one from the offset 24 h before, one from 24 h after. A candidate counts when
/// converting it back to the zone reproduces the chosen wall-clock fields.
/// - two valid candidates → the time occurs twice (fall back): earlier wins.
/// - none valid → the time does not exist (spring forward): the earlier-offset
///   candidate is the instant shifted forward by the gap.
LocalTimeResolution resolveLocalToUtc(tz.Location zone, DateTime local) {
  final naiveUtc = DateTime.utc(
    local.year,
    local.month,
    local.day,
    local.hour,
    local.minute,
  );

  const day = Duration(days: 1);
  final offsetBefore = zone
      .timeZone(naiveUtc.subtract(day).millisecondsSinceEpoch)
      .offset;
  final offsetAfter = zone
      .timeZone(naiveUtc.add(day).millisecondsSinceEpoch)
      .offset;

  final candidateBefore = naiveUtc.subtract(offsetBefore);
  final candidateAfter = naiveUtc.subtract(offsetAfter);

  final beforeValid = _mapsBackTo(zone, candidateBefore, local);
  final afterValid = _mapsBackTo(zone, candidateAfter, local);

  if (beforeValid && afterValid) {
    // Equal candidates mean one unchanged offset, so the time occurs once and
    // there is nothing ambiguous about it (a zone without DST, or a DST zone
    // outside a transition).
    if (candidateBefore == candidateAfter) {
      return LocalTimeResolution(
        utc: candidateBefore,
        shifted: false,
        ambiguous: false,
      );
    }
    final earlier = candidateBefore.isBefore(candidateAfter)
        ? candidateBefore
        : candidateAfter;
    return LocalTimeResolution(utc: earlier, shifted: false, ambiguous: true);
  }
  if (beforeValid) {
    return LocalTimeResolution(
      utc: candidateBefore,
      shifted: false,
      ambiguous: false,
    );
  }
  if (afterValid) {
    return LocalTimeResolution(
      utc: candidateAfter,
      shifted: false,
      ambiguous: false,
    );
  }
  if (candidateBefore == candidateAfter) {
    return LocalTimeResolution(
      utc: candidateBefore,
      shifted: false,
      ambiguous: false,
    );
  }
  // Spring-forward gap.
  return LocalTimeResolution(
    utc: candidateBefore,
    shifted: true,
    ambiguous: false,
  );
}

bool _mapsBackTo(tz.Location zone, DateTime utc, DateTime local) {
  final zoned = tz.TZDateTime.from(utc, zone);
  return zoned.year == local.year &&
      zoned.month == local.month &&
      zoned.day == local.day &&
      zoned.hour == local.hour &&
      zoned.minute == local.minute;
}

/// `YYYY-MM-DDTHH:mm` as persisted in `scheduled_local_datetime` (§7.3).
String formatLocalDateTimeFields(DateTime local) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)}T${two(local.hour)}:${two(local.minute)}';
}

/// `YYYY-MM-DDTHH:mm:ss.SSSZ` as persisted everywhere else (FR-MEM-09).
String formatUtcIso(DateTime utc) {
  final u = utc.toUtc();
  String three(int v) => v.toString().padLeft(3, '0');
  return '${u.year.toString().padLeft(4, '0')}-'
      '${u.month.toString().padLeft(2, '0')}-'
      '${u.day.toString().padLeft(2, '0')}T'
      '${u.hour.toString().padLeft(2, '0')}:'
      '${u.minute.toString().padLeft(2, '0')}:'
      '${u.second.toString().padLeft(2, '0')}.'
      '${three(u.millisecond)}Z';
}

/// Tolerant parser for persisted timestamps. Returns null when unusable.
DateTime? parseUtcIso(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value)?.toUtc();
}
