import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/services/day_ratings.dart';

final _morningTide = DateTime.utc(2026, 8, 26, 6, 41);
final _eveningTide = DateTime.utc(2026, 8, 26, 18, 51);

Map<String, dynamic> _document() => {
  'rating': 'green',
  'reasons': <String>[],
  'windows': [
    {
      'high_tide_at': _morningTide,
      'rating': 'red',
      'window_start': null,
      'window_end': null,
      'tide_window_start': DateTime.utc(2026, 8, 26, 5, 30),
      'tide_window_end': DateTime.utc(2026, 8, 26, 8, 0),
      'reasons': ['No unbroken 1h stretch stays under the limits.'],
    },
    {
      'high_tide_at': _eveningTide,
      'rating': 'green',
      'window_start': DateTime.utc(2026, 8, 26, 16, 36),
      'window_end': DateTime.utc(2026, 8, 26, 20, 36),
      'tide_window_start': DateTime.utc(2026, 8, 26, 16, 0),
      'tide_window_end': DateTime.utc(2026, 8, 26, 21, 0),
      'reasons': <String>[],
    },
  ],
};

void main() {
  group('liveDayRatingFromDocument', () {
    test('reads the day rating and each tide beneath it', () {
      final rating = liveDayRatingFromDocument(_document())!;

      expect(rating.conditions, Conditions.green);
      expect(rating.windows.map((w) => w.conditions), [
        Conditions.red,
        Conditions.green,
      ]);
      expect(rating.windows.last.start!.toUtc().hour, 16);
    });

    test('each tide carries the depth window the engine kept it for', () {
      final rating = liveDayRatingFromDocument(_document())!;

      final morning = rating.forHighTide(_morningTide)!;
      expect(morning.tideStart, DateTime.utc(2026, 8, 26, 5, 30));
      expect(morning.tideEnd, DateTime.utc(2026, 8, 26, 8, 0));

      // The evening weather window (16:36–20:36) sits inside its wider tide
      // window (16:00–21:00) — the two must stay separate so the card can show
      // both.
      final evening = rating.forHighTide(_eveningTide)!;
      expect(evening.tideStart, DateTime.utc(2026, 8, 26, 16, 0));
      expect(evening.tideEnd, DateTime.utc(2026, 8, 26, 21, 0));
    });

    test('finds the verdict for a tide by its time', () {
      final rating = liveDayRatingFromDocument(_document())!;

      expect(rating.forHighTide(_morningTide)!.conditions, Conditions.red);
      expect(rating.forHighTide(_eveningTide)!.conditions, Conditions.green);
      expect(rating.forHighTide(DateTime.utc(2026, 8, 26, 9)), isNull);
    });

    test('a day the engine could not rate has no colour to show', () {
      final rating = liveDayRatingFromDocument({
        'rating': null,
        'reasons': ['No forecast reaches this day yet.'],
        'windows': <dynamic>[],
      })!;

      expect(rating.conditions, isNull);
      expect(rating.reasons.single, 'No forecast reaches this day yet.');
    });

    test('no document at all is not a rating', () {
      expect(liveDayRatingFromDocument(null), isNull);
    });

    test('a rating word the app does not know is not guessed at', () {
      final rating = liveDayRatingFromDocument({
        'rating': 'chartreuse',
        'reasons': <String>[],
        'windows': <dynamic>[],
      })!;

      expect(rating.conditions, isNull);
    });
  });
}
