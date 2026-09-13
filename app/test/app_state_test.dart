import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/app_notification.dart';
import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/services/app_state.dart';
import 'package:athlunkard_boat_club/services/mock_club_repository.dart';
import 'package:athlunkard_boat_club/services/tide_windows.dart';

import 'fake_member_directory.dart';
import 'fake_session_repository.dart';

LiveHighTide _highTideOn(
  DateTime date, {
  required int hour,
  required int minute,
  double heightMetres = 4.6,
}) => LiveHighTide(
  localTime: DateTime(date.year, date.month, date.day, hour, minute),
  heightMetres: heightMetres,
);

/// Mirrors MockClubRepository's own day/tide scheme, so a session seeded here
/// lands on the same calendar day as its DayConditions.
DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _at(int dayOffset, int hour, int minute) =>
    _today().add(Duration(days: dayOffset, hours: hour, minutes: minute));

DateTime _tide(int dayOffset) =>
    _at(dayOffset, 6, 40).add(Duration(minutes: 45 * dayOffset));

void main() {
  group('AppState use-cases', () {
    test(
      'an athlete accepting tips a gathering session to confirmed',
      () async {
        final sessions = FakeSessionRepository(
          actingAs: coachProfile,
          seed: [
            Session(
              id: 's_day2',
              meetingTime: _tide(2),
              highTideTime: _tide(2),
              conditionRating: Conditions.amber,
              coach: coachProfile,
              committedAthletes: [aoifeProfile, cianProfile, darraghProfile],
            ),
          ],
        );
        final s = AppState(
          MockClubRepository(),
          memberDirectory: FakeMemberDirectory(),
          sessionRepository: sessions,
        );
        await s.login('saoirse@athlunkard.club', fakePassword);
        sessions.actingAs = saoirseProfile;

        final session = s.sessionById('s_day2')!; // seeded with 3 of 4
        expect(session.status, SessionStatus.notYetPossible);

        final ok = await s.respondToProposal(session, accept: true);

        expect(ok, true);
        expect(s.sessionById('s_day2')!.status, SessionStatus.confirmed);
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
        sessionRepository: FakeSessionRepository(actingAs: coachProfile),
      );
      await s.login('coach@athlunkard.club', fakePassword);

      final day = s.upcomingDays().firstWhere(
        (d) =>
            d.conditionRating == Conditions.green &&
            s.sessionsForDate(d.date).isEmpty,
      );
      final window = _highTideOn(day.date, hour: 6, minute: 41);
      final meetAt = DateTime(day.date.year, day.date.month, day.date.day, 6);

      final sent = await s.sendProposal(day, window, meetingTime: meetAt);

      expect(sent, true);
      final session = s.sessionsForDate(day.date).single;
      expect(session.meetingTime, meetAt);
      expect(session.highTideTime, window.localTime);
    });

    test('tells athletes when to meet, not when the tide is high', () async {
      final sessions = FakeSessionRepository(actingAs: coachProfile);
      final s = AppState(
        MockClubRepository(),
        memberDirectory: FakeMemberDirectory(),
        sessionRepository: sessions,
      );
      await s.login('coach@athlunkard.club', fakePassword);

      final day = s.upcomingDays().firstWhere(
        (d) =>
            d.conditionRating == Conditions.green &&
            s.sessionsForDate(d.date).isEmpty,
      );
      final window = _highTideOn(day.date, hour: 6, minute: 41);
      final meetAt = DateTime(day.date.year, day.date.month, day.date.day, 6);

      await s.sendProposal(day, window, meetingTime: meetAt);

      await s.logout();
      await s.login('saoirse@athlunkard.club', fakePassword);
      sessions.actingAs = saoirseProfile;
      final invitation = s.notifications().first.body;
      expect(invitation, contains('06:00'));
      expect(invitation, isNot(contains('06:41')));
    });

    test("a day's two high tides become two independent sessions", () async {
      final sessions = FakeSessionRepository(actingAs: coachProfile);
      final s = AppState(
        MockClubRepository(),
        memberDirectory: FakeMemberDirectory(),
        sessionRepository: sessions,
      );
      await s.login('coach@athlunkard.club', fakePassword);

      final day = s.upcomingDays().firstWhere(
        (d) =>
            d.conditionRating == Conditions.green &&
            s.sessionsForDate(d.date).isEmpty,
      );
      final morning = _highTideOn(day.date, hour: 7, minute: 15);
      final evening = _highTideOn(day.date, hour: 19, minute: 40);

      await s.sendProposal(day, morning, meetingTime: morning.localTime);
      await s.sendProposal(day, evening, meetingTime: evening.localTime);

      final proposed = s.sessionsForDate(day.date);
      expect(proposed.map((x) => x.meetingTime), [
        morning.localTime,
        evening.localTime,
      ]);

      await s.logout();
      await s.login('saoirse@athlunkard.club', fakePassword);
      sessions.actingAs = saoirseProfile;
      final ok = await s.respondToProposal(proposed.first, accept: true);

      expect(ok, true);
      final updated = s.sessionsForDate(day.date);
      expect(updated.first.committedCount, 1);
      expect(updated.last.committedCount, 0);
    });

    test('a coach pivoting a session marks it as land training', () async {
      final sessions = FakeSessionRepository(
        actingAs: coachProfile,
        seed: [
          Session(
            id: 's_day5',
            meetingTime: _tide(5),
            highTideTime: _tide(5),
            conditionRating: Conditions.green,
            coach: coachProfile,
            committedAthletes: [
              aoifeProfile,
              cianProfile,
              darraghProfile,
              saoirseProfile,
            ],
          ),
        ],
      );
      final s = AppState(
        MockClubRepository(),
        memberDirectory: FakeMemberDirectory(),
        sessionRepository: sessions,
      );
      await s.login('coach@athlunkard.club', fakePassword);

      final session = s.sessionById('s_day5')!; // confirmed
      final ok = await s.cancelSession(session, pivotToLand: true);

      expect(ok, true);
      final updated = s.sessionById('s_day5')!;
      expect(updated.lifecycle, SessionLifecycle.cancelledWeatherPivot);
      expect(updated.isCancelled, true);
    });

    test('a parent only sees sessions their child is in', () async {
      final sessions = FakeSessionRepository(
        actingAs: coachProfile,
        seed: [
          Session(
            id: 's_day5',
            meetingTime: _tide(5),
            highTideTime: _tide(5),
            conditionRating: Conditions.green,
            coach: coachProfile,
            committedAthletes: [
              aoifeProfile,
              cianProfile,
              darraghProfile,
              saoirseProfile,
            ],
          ),
        ],
      );
      final s = AppState(
        MockClubRepository(),
        memberDirectory: FakeMemberDirectory(),
        sessionRepository: sessions,
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
