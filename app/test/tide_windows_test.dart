import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/services/tide_windows.dart';

void main() {
  // Summer daylight bounds (local, naive) — mock until a live source exists.
  final sunrise = DateTime(2026, 7, 4, 5, 30);
  final sunset = DateTime(2026, 7, 4, 21, 45);

  LiveHighTide high(int h, int m, double height) =>
      LiveHighTide(time: DateTime(2026, 7, 4, h, m), heightMetres: height);

  group('offerableHighTides', () {
    test('returns BOTH high tides when both are in daylight and >= 4.2m', () {
      // The fix: a day with two qualifying highs offers two sessions, not one.
      final result = offerableHighTides(
        [high(9, 27, 5.19), high(21, 34, 5.41)],
        sunrise: sunrise,
        sunset: sunset,
      );
      expect(result.length, 2);
    });

    test('drops a high below the 4.2m threshold', () {
      final result = offerableHighTides(
        [high(9, 27, 4.0), high(21, 34, 5.41)],
        sunrise: sunrise,
        sunset: sunset,
      );
      expect(result.map((h) => h.heightMetres).toList(), [5.41]);
    });

    test('drops highs outside daylight (before sunrise / after sunset)', () {
      final result = offerableHighTides(
        [high(4, 10, 5.5), high(22, 30, 5.5)],
        sunrise: sunrise,
        sunset: sunset,
      );
      expect(result, isEmpty);
    });

    test('threshold is tunable', () {
      final result = offerableHighTides(
        [high(9, 27, 4.0)],
        sunrise: sunrise,
        sunset: sunset,
        minHeightMetres: 3.5,
      );
      expect(result.length, 1);
    });

    test('default threshold is 4.2m', () {
      expect(kMinRowableHighTideMetres, 4.2);
    });
  });
}
