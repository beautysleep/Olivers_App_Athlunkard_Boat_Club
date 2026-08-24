import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/shared/formatting.dart';

void main() {
  // A Saturday, deliberately with a single-digit day and an hour and minute
  // that both need zero-padding.
  final saturdayMorning = DateTime(2026, 7, 4, 6, 40);

  group('the formatters the day card and notifications read', () {
    test('formatDayDate abbreviates weekday and month', () {
      expect(formatDayDate(saturdayMorning), 'Sat 4 Jul');
    });

    test('formatTime is 24-hour and zero-padded', () {
      expect(formatTime(saturdayMorning), '06:40');
      expect(formatTime(DateTime(2026, 7, 4, 19, 5)), '19:05');
      expect(formatTime(DateTime(2026, 7, 4)), '00:00');
    });

    test('formatDayTime joins the two with a comma', () {
      expect(formatDayTime(saturdayMorning), 'Sat 4 Jul, 06:40');
    });

    test('formatWeekday is the abbreviation alone', () {
      expect(formatWeekday(saturdayMorning), 'Sat');
      expect(formatWeekday(DateTime(2026, 7, 6)), 'Mon');
      expect(formatWeekday(DateTime(2026, 7, 5)), 'Sun');
    });
  });
}
