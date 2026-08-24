import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/app_notification.dart';
import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/app_state.dart';
import 'package:athlunkard_boat_club/services/mock_club_repository.dart';
import 'package:athlunkard_boat_club/services/tide_windows.dart';

LiveHighTide _highTideOn(
  DateTime date, {
  required int hour,
  required int minute,
  double heightMetres = 4.6,
}) => LiveHighTide(
  time: DateTime(date.year, date.month, date.day, hour, minute),
  heightMetres: heightMetres,
);

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

    test('a coach proposes a meeting time, not the high tide itself', () {
      final s = AppState(MockClubRepository());
      s.login('coach@athlunkard.club', demoPassword);

      final day = s.upcomingDays().firstWhere((d) =>
          d.conditions == Conditions.green &&
          s.sessionsForDate(d.date).isEmpty);
      final window = _highTideOn(day.date, hour: 6, minute: 41);
      final meetAt = DateTime(day.date.year, day.date.month, day.date.day, 6);

      s.sendProposal(day, window, meetingTime: meetAt);

      final session = s.sessionsForDate(day.date).single;
      expect(session.date, meetAt);
      expect(session.highTideTime, window.time);
    });

    test('tells athletes when to meet, not when the tide is high', () {
      final s = AppState(MockClubRepository());
      s.login('coach@athlunkard.club', demoPassword);

      final day = s.upcomingDays().firstWhere((d) =>
          d.conditions == Conditions.green &&
          s.sessionsForDate(d.date).isEmpty);
      final window = _highTideOn(day.date, hour: 6, minute: 41);
      final meetAt = DateTime(day.date.year, day.date.month, day.date.day, 6);

      s.sendProposal(day, window, meetingTime: meetAt);

      s.logout();
      s.login('saoirse@athlunkard.club', demoPassword);
      final invitation = s.notifications().first.body;
      expect(invitation, contains('06:00'));
      expect(invitation, isNot(contains('06:41')));
    });

    test("a day's two high tides become two independent sessions", () {
      final s = AppState(MockClubRepository());
      s.login('coach@athlunkard.club', demoPassword);

      final day = s.upcomingDays().firstWhere((d) =>
          d.conditions == Conditions.green &&
          s.sessionsForDate(d.date).isEmpty);
      final morning = _highTideOn(day.date, hour: 7, minute: 15);
      final evening = _highTideOn(day.date, hour: 19, minute: 40);

      s.sendProposal(day, morning, meetingTime: morning.time);
      s.sendProposal(day, evening, meetingTime: evening.time);

      final sessions = s.sessionsForDate(day.date);
      expect(sessions.map((x) => x.date), [morning.time, evening.time]);

      s.logout();
      s.login('saoirse@athlunkard.club', demoPassword);
      s.respondToProposal(sessions.first, accept: true);

      expect(sessions.first.committedCount, 1);
      expect(sessions.last.committedCount, 0);
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
