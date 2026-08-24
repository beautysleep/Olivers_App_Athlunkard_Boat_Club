import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/services/daylight_conditions.dart';

void main() {
  group('liveDaylightFromDocument', () {
    test('maps a document carrying both bounds', () {
      final d = liveDaylightFromDocument({
        'sunrise': DateTime.utc(2026, 8, 24, 5, 30),
        'sunset': DateTime.utc(2026, 8, 24, 20, 45),
      });
      expect(d, isNotNull);
      expect(d!.localSunrise.isUtc, isFalse, reason: 'converted to local for display');
      expect(d.localSunset.difference(d.localSunrise).inHours, 15);
    });

    test('null document returns null', () {
      expect(liveDaylightFromDocument(null), isNull);
    });

    test('a day beyond the forecast horizon has no daylight, not a guess', () {
      expect(liveDaylightFromDocument({'date': '2026-09-30'}), isNull);
    });

    test('one bound without the other is unusable, so null', () {
      expect(
        liveDaylightFromDocument({'sunrise': DateTime.utc(2026, 8, 24, 5, 30)}),
        isNull,
      );
    });
  });
}
