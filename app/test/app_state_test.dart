import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/app_notification.dart';
import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/app_state.dart';
import 'package:athlunkard_boat_club/services/mock_club_repository.dart';

void main() {
  group('AppState use-cases', () {
    test('login rejects a wrong password and accepts the demo password', () {
      final s = AppState(MockClubRepository());
      expect(s.login('coach@athlunkard.club', 'nope'), false);
      expect(s.isLoggedIn, false);
      expect(s.login('coach@athlunkard.club', demoPassword), true);
      expect(s.currentUser?.role, UserRole.coach);
    });

    test('an athlete accepting tips a gathering session to confirmed', () {
      final s = AppState(MockClubRepository());
      s.login('saoirse@athlunkard.club', demoPassword);

      final session = s.sessionById('s_day2')!; // seeded with 3 of 4
      expect(session.status, SessionStatus.notYetPossible);

      s.respondToProposal(session, accept: true);

      expect(session.status, SessionStatus.confirmed);
      expect(
        s.notifications().any((n) => n.type == NotificationType.sessionConfirmed),
        true,
      );
    });

    test('a coach proposing creates a session for that day', () {
      final s = AppState(MockClubRepository());
      s.login('coach@athlunkard.club', demoPassword);

      final freeGreenDay = s.upcomingDays().firstWhere((d) =>
          d.conditions == Conditions.green &&
          s.sessionForDate(d.date) == null);

      s.sendProposal(freeGreenDay);
      expect(s.sessionForDate(freeGreenDay.date), isNotNull);
    });

    test('a coach pivoting a session marks it as land training', () {
      final s = AppState(MockClubRepository());
      s.login('coach@athlunkard.club', demoPassword);

      final session = s.sessionById('s_day5')!; // confirmed
      s.cancelSession(session, pivotToLand: true);

      expect(session.lifecycle, SessionLifecycle.cancelledWeatherPivot);
      expect(session.isCancelled, true);
    });

    test('a parent only sees sessions their child is in', () {
      final s = AppState(MockClubRepository());
      s.login('parent@athlunkard.club', demoPassword);

      // Seed data has Cian (the child) committed to s_day5.
      final visible = s.sessionsForCurrentUser();
      expect(visible.any((x) => x.id == 's_day5'), true);
      expect(visible.every((x) => x.committedAthletes.any((a) => a.id == 'u_cian')),
          true);
    });
  });
}
