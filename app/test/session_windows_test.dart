import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/day_ratings.dart';
import 'package:athlunkard_boat_club/services/session_windows.dart';
import 'package:athlunkard_boat_club/services/tide_windows.dart';

const _coach = UserProfile(
  id: 'u_coach',
  displayName: 'Aoife Ryan',
  email: 'coach@athlunkard.club',
  role: UserRole.coach,
);

LiveHighTide _highTide(int hour) =>
    LiveHighTide(localTime: DateTime(2026, 8, 25, hour), heightMetres: 4.6);

Session _sessionAt(DateTime time) => Session(
  id: 's_$time',
  meetingTime: time,
  highTideTime: time,
  conditionRating: Conditions.green,
  coach: _coach,
  committedAthletes: [],
);

void main() {
  group('sessionsByHighTide', () {
    test('pairs each offerable high tide with the session proposed for it', () {
      final morning = _highTide(7);
      final evening = _highTide(19);
      final proposed = _sessionAt(evening.localTime);

      final byHighTide = sessionsByHighTide([morning, evening], [proposed]);

      expect(byHighTide.map((w) => w.highTide), [morning, evening]);
      expect(byHighTide.map((w) => w.session), [null, proposed]);
    });

    test('keeps a session whose window is no longer offered', () {
      final stranded = _sessionAt(_highTide(19).localTime);

      final orphaned = sessionsWithoutAHighTide([_highTide(7)], [stranded]);

      expect(orphaned, [stranded]);
    });

    test('strands every session for a day with no live tide data at all', () {
      final morning = _sessionAt(_highTide(7).localTime);

      expect(sessionsWithoutAHighTide(const [], [morning]), [morning]);
    });

    test('leaves a window unproposed when no session sits at its time', () {
      final morning = _highTide(7);

      final byHighTide = sessionsByHighTide(
        [morning],
        [_sessionAt(_highTide(19).localTime)],
      );

      expect(byHighTide.single.session, isNull);
    });
  });

  group('daySessionsFromRating', () {
    LiveWindowRating entryFor(
      LiveHighTide highTide, {
      required bool rowable,
    }) => LiveWindowRating(
      highTideTime: highTide.localTime,
      conditions: rowable ? Conditions.green : Conditions.red,
      tideStart: rowable ? highTide.localTime.subtract(const Duration(hours: 2)) : null,
      tideEnd: rowable ? highTide.localTime.add(const Duration(hours: 2)) : null,
      reasons: const [],
    );

    LiveDayRating ratingOf(List<LiveWindowRating> entries) => LiveDayRating(
      conditions: Conditions.green,
      reasons: const [],
      windows: entries,
    );

    test('offers only tides the engine kept a depth window for', () {
      // The club has mock tide data for both tides, but the engine only kept
      // the evening one (e.g. the morning tide held 3.7m for too little
      // daylight) — the morning must not reappear in the offers.
      final morning = _highTide(7);
      final evening = _highTide(19);
      final rating = ratingOf([
        entryFor(morning, rowable: false),
        entryFor(evening, rowable: true),
      ]);

      final sessions = daySessionsFromRating(
        highs: [morning, evening],
        rating: rating,
        sessionsThatDay: const [],
      );

      expect(sessions.offerableWindows!.map((w) => w.highTide), [evening]);
    });

    test('without a rating the day is treated as "no data", not open-season', () {
      // Falling back to the live tide alone would reintroduce the 4.2m proxy
      // the engine replaced; the card must say "No data" until the engine's
      // verdict arrives.
      final sessions = daySessionsFromRating(
        highs: [_highTide(7)],
        rating: null,
        sessionsThatDay: const [],
      );

      expect(sessions.offerableWindows, isNull);
    });

    test(
      'a session proposed for a tide the engine no longer keeps is stranded, not lost',
      () {
        final morning = _highTide(7);
        final rating = ratingOf([entryFor(morning, rowable: false)]);
        final strandedSession = _sessionAt(morning.localTime);

        final sessions = daySessionsFromRating(
          highs: [morning],
          rating: rating,
          sessionsThatDay: [strandedSession],
        );

        expect(sessions.offerableWindows, isEmpty);
        expect(sessions.sessionsWithoutAWindow, [strandedSession]);
      },
    );
  });
}
