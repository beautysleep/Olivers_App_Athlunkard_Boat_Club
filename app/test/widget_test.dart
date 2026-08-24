import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/main.dart';
import 'package:athlunkard_boat_club/services/app_state.dart';
import 'package:athlunkard_boat_club/services/mock_club_repository.dart';

import 'fake_member_directory.dart';

void main() {
  testWidgets('boots to login, then signs in to the role home', (tester) async {
    await tester.pumpWidget(
      AthlunkardBoatClubApp(
        appState: AppState(
          MockClubRepository(),
          memberDirectory: FakeMemberDirectory(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sign in to see your sessions'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Email'),
      saoirseProfile.email,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      fakePassword,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    // We land in the signed-in shell: a bottom nav with a Calendar tab.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Calendar'), findsWidgets);
  });

  testWidgets('an invite code is the way in for someone new', (tester) async {
    await tester.pumpWidget(
      AthlunkardBoatClubApp(
        appState: AppState(
          MockClubRepository(),
          memberDirectory: FakeMemberDirectory(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('invite code'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Invite code'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Join'), findsOneWidget);
  });
}
