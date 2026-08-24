import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/features/calendar/day_card.dart';
import 'package:athlunkard_boat_club/models/day_conditions.dart';
import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/session_windows.dart';
import 'package:athlunkard_boat_club/services/tide_windows.dart';

final _day = DayConditions(
  date: DateTime(2026, 8, 24),
  conditions: Conditions.green,
  highTide: DateTime(2026, 8, 24, 16, 30),
  highTideHeightMetres: 4.1,
  windKnots: 12,
  rainfallMm: 0.5,
  waterReleaseActive: false,
  sunrise: DateTime(2026, 8, 24, 5, 30),
  sunset: DateTime(2026, 8, 24, 21, 45),
);

const _coach = UserProfile(
  id: 'u_coach',
  displayName: 'Aoife Ryan',
  email: 'coach@athlunkard.club',
  role: UserRole.coach,
);

final _morning = LiveHighTide(
  localTime: DateTime(2026, 8, 24, 7, 15),
  heightMetres: 4.6,
);
final _evening = LiveHighTide(
  localTime: DateTime(2026, 8, 24, 19, 40),
  heightMetres: 4.4,
);

Session _sessionAt(DateTime time) => Session(
  id: 's_$time',
  date: time,
  highTideTime: time,
  conditions: Conditions.green,
  coach: _coach,
  committedAthletes: [],
);

Widget _card(
  List<HighTideSession>? offerableSessions, {
  UserRole role = UserRole.coach,
  void Function(LiveHighTide, DateTime)? onSendProposal,
  List<Session> sessionsWithoutAWindow = const [],
}) => MaterialApp(
  home: Scaffold(
    body: DayCard(
      day: _day,
      unavailable: false,
      role: role,
      offerableSessions: offerableSessions,
      sessionsWithoutAWindow: sessionsWithoutAWindow,
      onSendProposal: onSendProposal ?? (_, _) {},
      onMarkUnavailable: () {},
      onOpenSession: (_) {},
    ),
  ),
);

Future<void> _flipToBack(WidgetTester tester) async {
  await tester.tap(find.byType(DayCard));
  await tester.pumpAndSettle();
}

void main() {
  group('a day with two rowable high tides', () {
    testWidgets('offers the coach a proposal per window, named by its time', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(sessionsByHighTide([_morning, _evening], const [])),
      );
      await _flipToBack(tester);

      expect(find.text('Propose · 07:15 tide'), findsOneWidget);
      expect(find.text('Propose · 19:40 tide'), findsOneWidget);
    });

    testWidgets('asks when to meet rather than assuming the tide time', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(sessionsByHighTide([_morning, _evening], const [])),
      );
      await _flipToBack(tester);
      await tester.tap(find.text('Propose · 07:15 tide'));
      await tester.pumpAndSettle();

      expect(find.text('06:30'), findsOneWidget);
      expect(find.text('06:00'), findsOneWidget);
      expect(find.text('05:30'), findsOneWidget);
      expect(find.text('07:15'), findsNothing);
    });

    testWidgets('proposes the window and meeting time the coach picked', (
      tester,
    ) async {
      LiveHighTide? chosenWindow;
      DateTime? chosenMeetingTime;
      await tester.pumpWidget(
        _card(
          sessionsByHighTide([_morning, _evening], const []),
          onSendProposal: (highTide, meetingTime) {
            chosenWindow = highTide;
            chosenMeetingTime = meetingTime;
          },
        ),
      );
      await _flipToBack(tester);
      await tester.tap(find.text('Propose · 19:40 tide'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18:30'));
      await tester.pumpAndSettle();

      expect(chosenWindow, _evening);
      expect(chosenMeetingTime, DateTime(2026, 8, 24, 18, 30));
    });

    testWidgets('keeps offering the free window once the other is proposed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(
          sessionsByHighTide([_morning, _evening], [_sessionAt(_morning.localTime)]),
        ),
      );
      await _flipToBack(tester);

      expect(find.text('Open 07:15 session'), findsOneWidget);
      expect(find.text('Propose · 19:40 tide'), findsOneWidget);
    });
  });

  group('a session the offerable windows no longer cover', () {
    testWidgets('is still shown, alongside the windows that are offered', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(
          sessionsByHighTide([_morning], const []),
          sessionsWithoutAWindow: [_sessionAt(DateTime(2026, 8, 24, 16, 30))],
        ),
      );
      await _flipToBack(tester);

      expect(find.text('Open 16:30 session'), findsOneWidget);
      expect(find.text('Propose · 07:15 tide'), findsOneWidget);
    });

    testWidgets('survives a day that has no live tide data at all', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(
          null,
          sessionsWithoutAWindow: [_sessionAt(DateTime(2026, 8, 24, 16, 30))],
        ),
      );
      await _flipToBack(tester);

      expect(find.text('Open session'), findsOneWidget);
      expect(find.text('Mark unavailable'), findsNothing);
    });
  });

  group('a day with nothing to offer', () {
    testWidgets('gives the coach no proposal choice without live tide data', (
      tester,
    ) async {
      await tester.pumpWidget(_card(null));
      await _flipToBack(tester);

      expect(find.textContaining('Propose'), findsNothing);
      expect(find.text('Send proposal'), findsNothing);
      expect(find.text('Mark unavailable'), findsOneWidget);
    });

    testWidgets('gives no proposal choice when no window is rowable', (
      tester,
    ) async {
      await tester.pumpWidget(_card(sessionsByHighTide(const [], const [])));
      await _flipToBack(tester);

      expect(find.textContaining('Propose'), findsNothing);
      expect(find.text('Send proposal'), findsNothing);
    });
  });
}
