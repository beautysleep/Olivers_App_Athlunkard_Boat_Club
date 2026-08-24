import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/features/calendar/day_card.dart';
import 'package:athlunkard_boat_club/models/day_conditions.dart';
import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/daylight_conditions.dart';
import 'package:athlunkard_boat_club/services/weather_conditions.dart';

/// The mock day still exists (it carries the date and the not-yet-live rating),
/// and deliberately holds values that must NEVER be rendered now.
final _day = DayConditions(
  date: DateTime(2026, 8, 24),
  conditions: Conditions.amber,
  highTide: DateTime(2026, 8, 24, 16, 30),
  highTideHeightMetres: 4.1,
  windKnots: 12,
  rainfallMm: 0.5,
  waterReleaseActive: true,
  sunrise: DateTime(2026, 8, 24, 5, 30),
  sunset: DateTime(2026, 8, 24, 21, 45),
);

Widget _card({LiveWeather? weather, LiveDaylight? daylight}) => MaterialApp(
  home: Scaffold(
    body: DayCard(
      day: _day,
      unavailable: false,
      role: UserRole.coach,
      onSendProposal: (_, _) {},
      onMarkUnavailable: () {},
      onOpenSession: (_) {},
      liveWeather: weather,
      liveDaylight: daylight,
    ),
  ),
);

Future<void> _flipToBack(WidgetTester tester) async {
  await tester.tap(find.byType(DayCard));
  await tester.pumpAndSettle();
}

void main() {
  group('a day with no live data', () {
    testWidgets('says "No data" rather than showing mock values', (
      tester,
    ) async {
      await tester.pumpWidget(_card());
      await _flipToBack(tester);

      // tide, wind, rain, water release, daylight
      expect(find.text('No data'), findsNWidgets(5));
      expect(find.text('Daylight'), findsOneWidget);
    });

    testWidgets('never renders the mock numbers behind it', (tester) async {
      await tester.pumpWidget(_card());
      await _flipToBack(tester);

      expect(find.textContaining('4.1m'), findsNothing); // mock tide height
      expect(find.textContaining('22 km/h'), findsNothing); // mock wind
      expect(find.textContaining('0.5 mm'), findsNothing); // mock rain
      expect(find.textContaining('YES'), findsNothing); // mock water release
      expect(find.textContaining('05:30'), findsNothing); // mock sunrise
    });

    testWidgets('shows live daylight when it is available', (tester) async {
      await tester.pumpWidget(
        _card(
          daylight: LiveDaylight(
            localSunrise: DateTime(2026, 8, 24, 6, 15),
            localSunset: DateTime(2026, 8, 24, 20, 10),
          ),
        ),
      );
      await _flipToBack(tester);

      expect(find.textContaining('06:15'), findsOneWidget);
      // tide, wind, rain still missing; daylight now covered
      expect(find.text('No data'), findsNWidgets(4));
    });
  });
}
