import 'package:flutter_test/flutter_test.dart';
import 'package:nanti_ingatkan_aku/core/ids.dart';

void main() {
  group('deriveNotificationId (FR-REM-05)', () {
    test('is deterministic for the same uuid', () {
      const uuid = '3f1c8a2e-8b1d-4f0a-9a3e-5a7f0f2c9d11';
      expect(deriveNotificationId(uuid), deriveNotificationId(uuid));
    });

    test('fits in 31 bits and is never zero', () {
      for (var i = 0; i < 500; i++) {
        final id = deriveNotificationId(
          '0000000$i-0000-4000-8000-000000000000',
        );
        expect(id, greaterThan(0));
        expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      }
    });

    test('remaps a zero result to 1', () {
      expect(deriveNotificationId('00000000-0000-4000-8000-000000000000'), 1);
    });

    test('rejects a uuid that is too short', () {
      expect(() => deriveNotificationId('abc'), throwsArgumentError);
    });
  });

  group('allocateNotificationId', () {
    test('probes linearly on collision', () {
      final first = allocateNotificationId(
        '3f1c8a2e-8b1d-4f0a-9a3e-5a7f0f2c9d11',
        <int>{},
      );
      final second = allocateNotificationId(
        '3f1c8a2e-8b1d-4f0a-9a3e-5a7f0f2c9d11',
        <int>{first},
      );
      expect(second, isNot(first));
      expect(second, greaterThan(0));
    });

    test('never returns a taken id', () {
      final taken = <int>{1, 2, 3, 4, 5};
      final id = allocateNotificationId(
        '00000001-0000-4000-8000-000000000000',
        taken,
      );
      expect(taken.contains(id), isFalse);
    });
  });
}
