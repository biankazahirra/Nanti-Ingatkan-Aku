import 'package:uuid/uuid.dart';

abstract class IdGenerator {
  String newId();
}

class UuidIdGenerator implements IdGenerator {
  const UuidIdGenerator();

  static const Uuid _uuid = Uuid();

  @override
  String newId() => _uuid.v4();
}

/// §7.3: `int.parse(first8HexOfUuid, radix: 16) & 0x7FFFFFFF`, `0` remapped to
/// `1`. Deterministic, so a reschedule reuses the same OS notification slot
/// (FR-REM-05).
int deriveNotificationId(String uuid) {
  final hex = uuid.replaceAll('-', '');
  if (hex.length < 8) {
    throw ArgumentError('Not a usable uuid: $uuid');
  }
  final value = int.parse(hex.substring(0, 8), radix: 16) & 0x7FFFFFFF;
  return value == 0 ? 1 : value;
}

/// Linear probe for uniqueness (FR-REM-05).
int allocateNotificationId(String uuid, Set<int> taken) {
  var candidate = deriveNotificationId(uuid);
  while (taken.contains(candidate)) {
    candidate = candidate >= 0x7FFFFFFF ? 1 : candidate + 1;
  }
  return candidate;
}
