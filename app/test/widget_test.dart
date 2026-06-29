import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/main.dart';
import 'package:athlunkard_boat_club/models/session.dart';

void main() {
  group('Session.status', () {
    Session sessionWith({
      required int athletes,
      required bool coachCommitted,
    }) {
      return Session(
        date: DateTime(2026, 7, 4, 6, 30),
        conditions: Conditions.green,
        coachName: 'Coach',
        coachCommitted: coachCommitted,
        committedAthletes:
            List.generate(athletes, (i) => 'Athlete ${i + 1}'),
      );
    }

    test('is not yet possible below the minimum crew', () {
      expect(
        sessionWith(athletes: 3, coachCommitted: true).status,
        SessionStatus.notYetPossible,
      );
    });

    test('is not yet possible without a committed coach', () {
      expect(
        sessionWith(athletes: 4, coachCommitted: false).status,
        SessionStatus.notYetPossible,
      );
    });

    test('confirms at the minimum crew with a committed coach', () {
      expect(
        sessionWith(athletes: 4, coachCommitted: true).status,
        SessionStatus.confirmed,
      );
    });
  });

  testWidgets('accepting tips the session from not-yet-possible to confirmed',
      (tester) async {
    await tester.pumpWidget(const AthlunkardBoatClubApp());

    // Starts with 3 committed athletes -> not yet possible.
    expect(find.textContaining('Not yet possible'), findsOneWidget);
    expect(find.text('3 / 4 committed'), findsOneWidget);

    // Accepting adds "You" -> 4 committed, coach already committed -> confirmed.
    await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
    await tester.pump();

    expect(find.textContaining('Confirmed'), findsOneWidget);
    expect(find.text('4 / 4 committed'), findsOneWidget);
  });
}
