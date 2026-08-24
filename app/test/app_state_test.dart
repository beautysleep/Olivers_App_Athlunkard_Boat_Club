import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/app_notification.dart';
import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/services/app_state.dart';
import 'package:athlunkard_boat_club/services/mock_club_repository.dart';

import 'fake_member_directory.dart';
import 'package:athlunkard_boat_club/services/tide_windows.dart';

LiveHighTide _highTideOn(
  DateTime date, {
  required int hour,
  required int minute,
  double heightMetres = 4.6,
}) => LiveHighTide(
  localTime: DateTime(date.year, date.month, date.day, hour, minute),
  heightMetres: heightMetres,
);

void main() {
  group('AppState use-cases', () {
    test(
      'an athlete accepting tips a gathering session to confirmed',
      () async {
        final s = AppState(
          MockClubRepository(),
          memberDirectory: FakeMemberDirectory(),
        );
        await s.login('saoirse@athlunkard.club', fakePassword);

        final session = s.sessionById('s_day2')!; // seeded with 3 of 4
        expect(session.status, SessionStatus.notYetPossible);

        s.respondToProposal(session, accept: true);

        expect(session.status, SessionStatus.confirmed);
        expect(
          s.notifications().any(
            (n) => n.type == NotificationType.sessionConfirmed,
          ),
          true,
        );
      },
    );

    test('a coach proposes a meeting time, not the high tide itself', () async {
      final s = AppState(
        MockClubRepository(),
        memberDirectory: FakeMemberDirectory(),
      );
      await s.login('coach@athlunkard.club', fakePassword);

      final day = s.upcomingDays().firstWhere(
        (d) =>
            d.conditionRating == Conditions.green &&
            s.sessionsForDate(d.date).isEmpty,
      );
      final window = _highTideOn(day.date, hour: 6, minute: 41);
      final meetAt = DateTime(day.date.year, day.date.month, day.date.day, 6);

      s.sendProposal(day, window, meetingTime: meetAt);

      final session = s.sessionsForDate(day.date).single;
      expect(session.meetingTime, meetAt);
      expect(session.highTideTime, window.localTime);
    });

    test('tells athletes when to meet, not when the tide is high', () async {
      final s = AppState(
        MockClubRepository(),
        memberDirectory: FakeMemberDirectory(),
      );
      await s.login('coach@athlunkard.club', fakePassword);

      final day = s.upcomingDays().firstWhere(
        (d) =>
            d.conditionRating == Conditions.green &&
            s.sessionsForDate(d.date).isEmpty,
      );
      final window = _highTideOn(day.date, hour: 6, minute: 41);
      final meetAt = DateTime(day.date.year, day.date.month, day.date.day, 6);

      s.sendProposal(day, window, meetingTime: meetAt);

      await s.logout();
      await s.login('saoirse@athlunkard.club', fakePassword);
      final invitation = s.notifications().first.body;
      expect(invitation, contains('06:00'));
      expect(invitation, isNot(contains('06:41')));
    });

    test("a day's two high tides become two independent sessions", () async {
      final s = AppState(
        MockClubRepository(),
        memberDirectory: FakeMemberDirectory(),
      );
      await s.login('coach@athlunkard.club', fakePassword);

      final day = s.upcomingDays().firstWhere(
        (d) =>
            d.conditionRating == Conditions.green &&
            s.sessionsForDate(d.date).isEmpty,
      );
      final morning = _highTideOn(day.date, hour: 7, minute: 15);
      final evening = _highTideOn(day.date, hour: 19, minute: 40);

      s.sendProposal(day, morning, meetingTime: morning.localTime);
      s.sendProposal(day, evening, meetingTime: evening.localTime);

      final sessions = s.sessionsForDate(day.date);
      expect(sessions.map((x) => x.meetingTime), [
        morning.localTime,
        evening.localTime,
      ]);

      await s.logout();
      await s.login('saoirse@athlunkard.club', fakePassword);
      s.respondToProposal(sessions.first, accept: true);

      expect(sessions.first.committedCount, 1);
      expect(sessions.last.committedCount, 0);
    });

    test('a coach pivoting a session marks it as land training', () async {
      final s = AppState(
        MockClubRepository(),
        memberDirectory: FakeMemberDirectory(),
      );
      await s.login('coach@athlunkard.club', fakePassword);

      final session = s.sessionById('s_day5')!; // confirmed
      s.cancelSession(session, pivotToLand: true);

      expect(session.lifecycle, SessionLifecycle.cancelledWeatherPivot);
      expect(session.isCancelled, true);
    });

    test('a parent only sees sessions their child is in', () async {
      final s = AppState(
        MockClubRepository(),
        memberDirectory: FakeMemberDirectory(),
      );
      await s.login('parent@athlunkard.club', fakePassword);

      // Seed data has Cian (the child) committed to s_day5.
      final visible = s.sessionsForCurrentUser();
      expect(visible.any((x) => x.id == 's_day5'), true);
      expect(
        visible.every((x) => x.committedAthletes.any((a) => a.id == 'u_cian')),
        true,
      );
    });
  });
}
