import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/app_state.dart';
import 'package:athlunkard_boat_club/services/member_directory.dart';
import 'package:athlunkard_boat_club/services/mock_club_repository.dart';

const _coach = UserProfile(
  id: 'uid_coach',
  displayName: 'Niamh Ryan',
  email: 'coach@athlunkard.club',
  role: UserRole.coach,
);
const _athlete = UserProfile(
  id: 'uid_saoirse',
  displayName: 'Saoirse Walsh',
  email: 'saoirse@athlunkard.club',
  role: UserRole.athlete,
);

class _FakeDirectory implements MemberDirectory {
  _FakeDirectory({this.outcome = SignInOutcome.succeeded, this.signedIn});

  SignInOutcome outcome;
  UserProfile? signedIn;
  bool signedOut = false;

  @override
  Future<UserProfile?> currentMember() async => signedIn;

  @override
  Future<SignInOutcome> signIn(String email, String password) async {
    if (outcome == SignInOutcome.succeeded) signedIn = _coach;
    return outcome;
  }

  @override
  Future<SignInOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
    String? childId,
  }) async {
    if (outcome == SignInOutcome.succeeded) signedIn = _athlete;
    return outcome;
  }

  @override
  Future<void> signOut() async {
    signedOut = true;
    signedIn = null;
  }

  @override
  Future<List<UserProfile>> roster() async => [_coach, _athlete];
}

void main() {
  group('signing in', () {
    test('a successful sign-in makes that member the current user', () async {
      final directory = _FakeDirectory();
      final state = AppState(MockClubRepository(), memberDirectory: directory);

      final outcome = await state.login('coach@athlunkard.club', 'good');

      expect(outcome, SignInOutcome.succeeded);
      expect(state.isLoggedIn, true);
      expect(state.currentUser?.role, UserRole.coach);
    });

    test('a refused sign-in leaves nobody signed in', () async {
      final directory = _FakeDirectory(
        outcome: SignInOutcome.wrongEmailOrPassword,
      );
      final state = AppState(MockClubRepository(), memberDirectory: directory);

      final outcome = await state.login('coach@athlunkard.club', 'wrong');

      expect(outcome, SignInOutcome.wrongEmailOrPassword);
      expect(state.isLoggedIn, false);
      expect(state.currentUser, isNull);
    });

    test('a refused invite code leaves nobody signed in', () async {
      final directory = _FakeDirectory(
        outcome: SignInOutcome.inviteCodeRefused,
      );
      final state = AppState(MockClubRepository(), memberDirectory: directory);

      final outcome = await state.signUp(
        email: 'new@athlunkard.club',
        password: 'secret123',
        displayName: 'New Member',
        inviteCode: 'nope',
      );

      expect(outcome, SignInOutcome.inviteCodeRefused);
      expect(state.isLoggedIn, false);
    });

    test('signing out clears the member and tells the directory', () async {
      final directory = _FakeDirectory();
      final state = AppState(MockClubRepository(), memberDirectory: directory);
      await state.login('coach@athlunkard.club', 'good');

      await state.logout();

      expect(state.isLoggedIn, false);
      expect(directory.signedOut, true);
    });

    test(
      'a member already signed in from a previous run is restored',
      () async {
        final state = AppState(
          MockClubRepository(),
          memberDirectory: _FakeDirectory(signedIn: _athlete),
        );

        await state.restoreSession();

        expect(state.currentUser?.id, 'uid_saoirse');
      },
    );

    test('the roster is loaded so athletes can be notified', () async {
      final state = AppState(
        MockClubRepository(),
        memberDirectory: _FakeDirectory(),
      );

      await state.loadRoster();

      expect(state.roster.map((m) => m.id), ['uid_coach', 'uid_saoirse']);
    });
  });
}
