import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/session_windows.dart';
import 'package:athlunkard_boat_club/services/tide_windows.dart';

const _coach = UserProfile(
  id: 'u_coach',
  displayName: 'Aoife Ryan',
  email: 'coach@athlunkard.club',
  role: UserRole.coach,
);

LiveHighTide _highTide(int hour) =>
    LiveHighTide(time: DateTime(2026, 8, 25, hour), heightMetres: 4.6);

Session _sessionAt(DateTime time) => Session(
  id: 's_$time',
  date: time,
  highTideTime: time,
  conditions: Conditions.green,
  coach: _coach,
  committedAthletes: [],
);

void main() {
  group('sessionsByHighTide', () {
    test('pairs each offerable high tide with the session proposed for it', () {
      final morning = _highTide(7);
      final evening = _highTide(19);
      final proposed = _sessionAt(evening.time);

      final byHighTide = sessionsByHighTide([morning, evening], [proposed]);

      expect(byHighTide.map((w) => w.highTide), [morning, evening]);
      expect(byHighTide.map((w) => w.session), [null, proposed]);
    });

    test('keeps a session whose window is no longer offered', () {
      final stranded = _sessionAt(_highTide(19).time);

      final orphaned = sessionsWithoutAHighTide([_highTide(7)], [stranded]);

      expect(orphaned, [stranded]);
    });

    test('strands every session for a day with no live tide data at all', () {
      final morning = _sessionAt(_highTide(7).time);

      expect(sessionsWithoutAHighTide(const [], [morning]), [morning]);
    });

    test('leaves a window unproposed when no session sits at its time', () {
      final morning = _highTide(7);

      final byHighTide = sessionsByHighTide([morning], [_sessionAt(_highTide(19).time)]);

      expect(byHighTide.single.session, isNull);
    });
  });
}
