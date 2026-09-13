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

/// The morning tide is unrowable, the evening one is fine — the case a single
/// day-level colour used to hide.
final _rating = LiveDayRating(
  conditions: Conditions.green,
  reasons: const [],
  windows: [
    LiveWindowRating(
      highTideTime: _morning.localTime,
      conditions: Conditions.red,
      reasons: const ['No unbroken 1.5h stretch stays under the limits.'],
    ),
    LiveWindowRating(
      highTideTime: _evening.localTime,
      conditions: Conditions.green,
      start: DateTime(2026, 8, 26, 16, 36),
      end: DateTime(2026, 8, 26, 20, 36),
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
    expect(find.textContaining('No unbroken 1.5h stretch'), findsOneWidget);
  });
}
