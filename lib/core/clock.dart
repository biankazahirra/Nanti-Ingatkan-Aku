import 'package:timezone/timezone.dart' as tz;

/// The only source of "now" and of the device zone.
///
/// FR-MEM-09 / §7.2: direct `DateTime.now()` is banned outside an
/// implementation of this interface, so every rule is testable with a fake.
abstract class Clock {
  DateTime nowUtc();

  /// Device zone, already resolved to a known IANA location (see §7.5).
  tz.Location get zone;
}

class SystemClock implements Clock {
  const SystemClock(this._zone);

  final tz.Location _zone;

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  tz.Location get zone => _zone;
}
