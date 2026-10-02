import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/services/meeting_times.dart';

DateTime _at(int hour, int minute) => DateTime(2026, 8, 26, hour, minute);

void main() {
  group('quarterHourAtOrBefore', () {
    test('leaves a time already on a quarter alone', () {
      expect(quarterHourAtOrBefore(_at(7, 15)), _at(7, 15));
    });

    test('rounds a between-ticks time down to the previous quarter', () {
      expect(quarterHourAtOrBefore(_at(7, 20)), _at(7, 15));
      expect(quarterHourAtOrBefore(_at(7, 29)), _at(7, 15));
      expect(quarterHourAtOrBefore(_at(7, 44)), _at(7, 30));
    });

    test('crosses the hour backwards without inventing a time', () {
      // 08:07 rounds down to 08:00, not 07:45 — the floor is on the quarter
      // nearest or at the time, never past it.
      expect(quarterHourAtOrBefore(_at(8, 7)), _at(8, 0));
    });
  });

  group('defaultMeetingTime', () {
    test(
      'lands 30 minutes before the earliest rowable water, rounded to a quarter',
      () {
        // Water reaches rowable depth at 07:21 — 30 min earlier is 06:51,
        // which the Cupertino wheel can only stop on at 06:45.
        expect(defaultMeetingTime(_at(7, 21)), _at(6, 45));
      },
    );

    test('stays on a quarter when the arithmetic lands on one', () {
      // 08:00 earliest water → 07:30 default, already a quarter.
      expect(defaultMeetingTime(_at(8, 0)), _at(7, 30));
    });

    test('crosses midnight backwards without inventing a date', () {
      expect(defaultMeetingTime(_at(0, 20)), DateTime(2026, 8, 25, 23, 45));
    });
  });

  group('earliestMeetingTime', () {
    test('is one hour before the earliest rowable water on a quarter', () {
      // 07:21 - 1h = 06:21 → floor to 06:15 so the wheel's lower bound lines
      // up with a tick.
      expect(earliestMeetingTime(_at(7, 21)), _at(6, 15));
    });
  });

  group('latestMeetingTime', () {
    test(
      'is one hour before the water drops back below rowable, on a quarter',
      () {
        // Rowable water ends at 12:38 — 1h earlier is 11:38, which the wheel
        // can only stop on at 11:30.
        expect(latestMeetingTime(_at(12, 38)), _at(11, 30));
      },
    );

    test('refuses to drift later than the one-hour cushion', () {
      // Tide window ends at 12:00; 11:00 is already a quarter, so the picker
      // stops there rather than 11:15.
      expect(latestMeetingTime(_at(12, 0)), _at(11, 0));
    });
  });
}
