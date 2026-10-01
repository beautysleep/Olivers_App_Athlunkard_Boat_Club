import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/features/calendar/day_card.dart';
import 'package:athlunkard_boat_club/models/day_conditions.dart';
import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/day_ratings.dart';
import 'package:athlunkard_boat_club/services/session_windows.dart';
import 'package:athlunkard_boat_club/services/tide_windows.dart';

final _morning = LiveHighTide(
  localTime: DateTime(2026, 8, 26, 6, 41),
  heightMetres: 5.1,
);
final _evening = LiveHighTide(
  localTime: DateTime(2026, 8, 26, 18, 51),
  heightMetres: 5.4,
);

final _day = DayConditions(
  date: DateTime(2026, 8, 26),
  conditionRating: Conditions.red,
  highTideTime: DateTime(2026, 8, 26, 16, 30),
  highTideHeightMetres: 4.1,
  windKnots: 12,
  rainfallMm: 0.5,
  waterReleaseActive: false,
  localSunrise: DateTime(2026, 8, 26, 5, 30),
  localSunset: DateTime(2026, 8, 26, 21, 45),
);

/// The morning tide is unrowable (weather ruled it out) but the depth window
/// still stood; the evening one has weather narrower than the depth, so the
/// card can show them separately.
final _rating = LiveDayRating(
  conditions: Conditions.green,
  reasons: const [],
  windows: [
    LiveWindowRating(
      highTideTime: _morning.localTime,
      conditions: Conditions.red,
      tideStart: DateTime(2026, 8, 26, 5, 30),
      tideEnd: DateTime(2026, 8, 26, 8, 0),
      reasons: const ['No unbroken 1h stretch stays under the limits.'],
    ),
    LiveWindowRating(
      highTideTime: _evening.localTime,
      conditions: Conditions.green,
      start: DateTime(2026, 8, 26, 16, 36),
      end: DateTime(2026, 8, 26, 20, 36),
      tideStart: DateTime(2026, 8, 26, 16, 0),
      tideEnd: DateTime(2026, 8, 26, 21, 0),
      reasons: const [],
    ),
  ],
);

Widget _card() => MaterialApp(
  home: Scaffold(
    body: DayCard(
      day: _day,
      unavailable: false,
      role: UserRole.coach,
      offerableSessions: sessionsByHighTide([_morning, _evening], const []),
      liveDayRating: _rating,
      onSendProposal: (_, _) {},
      onMarkUnavailable: () {},
      onOpenSession: (_) {},
    ),
  ),
);

void main() {
  testWidgets('a tide the engine ruled out is not offered for proposal', (
    tester,
  ) async {
    await tester.pumpWidget(_card());
    await tester.tap(find.byType(DayCard));
    await tester.pumpAndSettle();

    expect(find.text('Propose · 06:41 tide'), findsNothing);
    expect(find.text('Propose · 18:51 tide'), findsOneWidget);
  });

  testWidgets('the ruled-out tide says why, rather than vanishing silently', (
    tester,
  ) async {
    await tester.pumpWidget(_card());
    await tester.tap(find.byType(DayCard));
    await tester.pumpAndSettle();

    expect(find.textContaining('06:41'), findsWidgets);
    expect(find.textContaining('No unbroken 1h stretch'), findsOneWidget);
  });

  testWidgets('the card shows every tide window the engine kept', (
    tester,
  ) async {
    await tester.pumpWidget(_card());
    await tester.tap(find.byType(DayCard));
    await tester.pumpAndSettle();

    expect(find.text('Tide window'), findsNWidgets(2));
    expect(find.textContaining('05:30–08:00'), findsOneWidget);
    expect(find.textContaining('16:00–21:00'), findsOneWidget);
  });

  testWidgets(
    'the narrower weather window is called out alongside the wider tide window',
    (tester) async {
      await tester.pumpWidget(_card());
      await tester.tap(find.byType(DayCard));
      await tester.pumpAndSettle();

      // Evening: tide holds 16:00–21:00 but calm only runs 16:36–20:36 — the
      // card lists both so the coach sees the shortfall rather than a single
      // flattened window.
      expect(find.text('Best weather'), findsOneWidget);
      expect(find.textContaining('16:36–20:36'), findsOneWidget);
    },
  );

  testWidgets(
    'a weather window identical to the tide window is not restated',
    (tester) async {
      final sameAsTide = LiveDayRating(
        conditions: Conditions.green,
        reasons: const [],
        windows: [
          LiveWindowRating(
            highTideTime: _evening.localTime,
            conditions: Conditions.green,
            start: DateTime(2026, 8, 26, 16, 0),
            end: DateTime(2026, 8, 26, 21, 0),
            tideStart: DateTime(2026, 8, 26, 16, 0),
            tideEnd: DateTime(2026, 8, 26, 21, 0),
            reasons: const [],
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DayCard(
              day: _day,
              unavailable: false,
              role: UserRole.coach,
              offerableSessions: sessionsByHighTide([_evening], const []),
              liveDayRating: sameAsTide,
              onSendProposal: (_, _) {},
              onMarkUnavailable: () {},
              onOpenSession: (_) {},
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DayCard));
      await tester.pumpAndSettle();

      expect(find.text('Tide window'), findsOneWidget);
      expect(find.text('Best weather'), findsNothing);
    },
  );

  testWidgets(
    'a ruled-out tide says so in the action area even though the depth window is shown',
    (tester) async {
      await tester.pumpWidget(_card());
      await tester.tap(find.byType(DayCard));
      await tester.pumpAndSettle();

      expect(find.textContaining('06:41 tide — not rowable'), findsOneWidget);
    },
  );
}
