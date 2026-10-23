import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../core/logging.dart';

/// §7.5 — vendor aliases seen in the wild. Resolved before falling back.
const Map<String, String> kTimezoneAliases = {
  'Asia/Calcutta': 'Asia/Kolkata',
  'Asia/Saigon': 'Asia/Ho_Chi_Minh',
  'Asia/Katmandu': 'Asia/Kathmandu',
  'Asia/Rangoon': 'Asia/Yangon',
  'Europe/Kiev': 'Europe/Kyiv',
  'America/Buenos_Aires': 'America/Argentina/Buenos_Aires',
  'US/Pacific': 'America/Los_Angeles',
  'US/Eastern': 'America/New_York',
  'GMT': 'UTC',
  'Etc/GMT': 'UTC',
};

class TimezoneResolution {
  const TimezoneResolution({
    required this.location,
    required this.identifier,
    required this.unknown,
  });

  final tz.Location location;

  /// Identifier that was actually resolved; persisted for display.
  final String identifier;
  final bool unknown;
}

/// Resolves the device zone without ever crashing on an unknown identifier.
TimezoneResolution resolveLocationId(String? rawId) {
  final candidate = rawId?.trim();
  if (candidate == null || candidate.isEmpty) {
    return TimezoneResolution(
      location: tz.getLocation('UTC'),
      identifier: 'UTC',
      unknown: true,
    );
  }

  for (final id in [
    candidate,
    if (kTimezoneAliases.containsKey(candidate)) kTimezoneAliases[candidate]!,
  ]) {
    try {
      return TimezoneResolution(
        location: tz.getLocation(id),
        identifier: id,
        unknown: false,
      );
    } on tz.LocationNotFoundException {
      continue;
    }
  }

  logEvent(LogCodes.unknownTimezone, detail: candidate);
  return TimezoneResolution(
    location: tz.local,
    identifier: tz.local.name,
    unknown: true,
  );
}

/// Initializes the timezone database and reports the device zone.
Future<TimezoneResolution> initializeDeviceTimezone() async {
  tzdata.initializeTimeZones();
  String? deviceId;
  try {
    deviceId = (await FlutterTimezone.getLocalTimezone()).identifier;
  } on Object {
    deviceId = null;
  }
  final resolution = resolveLocationId(deviceId);
  tz.setLocalLocation(resolution.location);
  return resolution;
}
