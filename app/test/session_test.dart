import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';

const _coach = UserProfile(
    id: 'c', displayName: 'Coach', email: 'c@x', role: UserRole.coach);

UserProfile _athlete(int i) => UserProfile(
    id: 'a$i', displayName: 'A $i', email: 'a$i@x', role: UserRole.athlete);

Session _session({
  required int athletes,
  SessionLifecycle lifecycle = SessionLifecycle.proposed,
}) =>
    Session(
      id: 's',
      meetingTime: DateTime(2026, 7, 4, 6, 30),
      highTideTime: DateTime(2026, 7, 4, 7, 15),
      conditionRating: Conditions.green,
      coach: _coach,
      committedAthletes: List.generate(athletes, _athlete),
      lifecycle: lifecycle,
    );

void main() {
  group('Session.status', () {
    test('below the minimum crew -> not yet possible', () {
      expect(_session(athletes: 3).status, SessionStatus.notYetPossible);
    });

    test('at the minimum crew -> confirmed', () {
      expect(_session(athletes: 4).status, SessionStatus.confirmed);
    });

    test('cancelled outright -> coach not committed -> not yet possible', () {
      final s = _session(
          athletes: 5, lifecycle: SessionLifecycle.cancelledOutright);
      expect(s.isCancelled, true);
      expect(s.coachCommitted, false);
      expect(s.status, SessionStatus.notYetPossible);
    });

    test('stillNeeded counts down to the minimum', () {
      expect(_session(athletes: 1).stillNeeded, 3);
      expect(_session(athletes: 4).stillNeeded, 0);
    });

    test('isCommitted compares by id', () {
      final a = _athlete(0);
      final s = Session(
        id: 's',
        meetingTime: DateTime(2026, 7, 4),
        highTideTime: DateTime(2026, 7, 4, 7, 15),
        conditionRating: Conditions.green,
        coach: _coach,
        committedAthletes: [a],
      );
      expect(s.isCommitted(a), true);
      expect(s.isCommitted(_athlete(9)), false);
    });
  });
}
