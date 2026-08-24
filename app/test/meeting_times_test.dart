import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/services/meeting_times.dart';

DateTime _at(int hour, int minute) => DateTime(2026, 8, 26, hour, minute);

void main() {
  group('meetingTimesBefore', () {
    test('defaults to the half-hour mark that leaves time to launch', () {
      expect(meetingTimesBefore(_at(6, 41)).first, _at(6, 0));
    });

    test('offers earlier half-hour steps for a longer session', () {
      expect(meetingTimesBefore(_at(6, 41)), [_at(6, 0), _at(5, 30), _at(5, 0)]);
    });

    test('steps back when the half hour is too close to launch in', () {
      expect(meetingTimesBefore(_at(7, 17)).first, _at(6, 30));
    });

    test('lands on the half hour, not the hour, when that is the fit', () {
      expect(meetingTimesBefore(_at(19, 40)).first, _at(19, 0));
      expect(meetingTimesBefore(_at(18, 51)).first, _at(18, 0));
    });

    test('crosses midnight backwards without inventing a time', () {
      expect(meetingTimesBefore(_at(0, 20)).first, DateTime(2026, 8, 25, 23, 30));
    });
  });
}
