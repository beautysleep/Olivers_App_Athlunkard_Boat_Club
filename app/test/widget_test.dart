import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/main.dart';

void main() {
  testWidgets('boots to login, then signs in to the role home', (tester) async {
    await tester.pumpWidget(const AthlunkardBoatClubApp());

    // The login screen is shown first.
    expect(find.text('Sign in to see your sessions'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);

    // Quick-fill the athlete account, then sign in.
    await tester.tap(find.textContaining('Athlete ·'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // We land in the signed-in shell: a bottom nav with a Calendar tab.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Calendar'), findsWidgets);
  });
}
