import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/features/calendar/day_card.dart';
import 'package:athlunkard_boat_club/models/day_conditions.dart';
import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/day_ratings.dart';
import 'package:athlunkard_boat_club/shared/condition_style.dart';

/// The mock day is deliberately red, so anything green on screen can only have
/// come from the live rating.
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

Widget _card(LiveDayRating? rating) => MaterialApp(
  home: Scaffold(
    body: DayCard(
      day: _day,
      unavailable: false,
      role: UserRole.coach,
      liveDayRating: rating,
      onSendProposal: (_, _) {},
      onMarkUnavailable: () {},
      onOpenSession: (_) {},
    ),
  ),
);

LiveDayRating _rating(Conditions? conditions, {List<String> reasons = const []}) =>
    LiveDayRating(conditions: conditions, reasons: reasons, windows: const []);

void main() {
  testWidgets('the headline colour comes from the engine, not the mock', (
    tester,
  ) async {
    await tester.pumpWidget(_card(_rating(Conditions.green)));

    expect(
      find.text(conditionStyle(Conditions.green).shortLabel),
      findsOneWidget,
    );
    expect(find.text(conditionStyle(Conditions.red).shortLabel), findsNothing);
  });

  testWidgets('a day the engine could not rate says so rather than guessing', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(_rating(null, reasons: ['No forecast reaches this day yet.'])),
    );

    expect(find.text('Not rated yet'), findsOneWidget);
    expect(find.text(conditionStyle(Conditions.red).shortLabel), findsNothing);
  });

  testWidgets('with no live rating at all the card admits it', (tester) async {
    await tester.pumpWidget(_card(null));

    expect(find.text('Not rated yet'), findsOneWidget);
  });

  testWidgets('the reasons behind the call are shown on the back', (
    tester,
  ) async {
    await tester.pumpWidget(
      _card(_rating(Conditions.red, reasons: ['ESB expects a discharge.'])),
    );
    await tester.tap(find.byType(DayCard));
    await tester.pumpAndSettle();

    expect(find.text('ESB expects a discharge.'), findsOneWidget);
  });
}
