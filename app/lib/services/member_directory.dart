/// Who is signed in, and who else is in the club.
///
/// The seam that keeps Firebase out of [AppState], the same way
/// [ClubRepository] keeps the data source out of it. Tests supply their own.
library;

import '../models/user_profile.dart';

/// The membership function's URL, from `terraform output membership_function_uri`.
/// Passed in at build time rather than committed, because it changes with the
/// deployment and is not the app's to remember:
///
///     flutter run --dart-define=MEMBERSHIP_ENDPOINT=https://...
const membershipEndpoint = String.fromEnvironment('MEMBERSHIP_ENDPOINT');

/// Why a sign-in or signup did not work, in terms the screen can show. The
/// distinctions the user can act on are kept; the rest collapse into
/// [SignInOutcome.failed] rather than leaking provider vocabulary into the UI.
enum SignInOutcome {
  succeeded,
  wrongEmailOrPassword,
  emailAlreadyRegistered,
  weakPassword,
  inviteCodeRefused,
  noNetwork,
  failed,
}

abstract class MemberDirectory {
  /// The member already signed in from a previous run, or null.
  Future<UserProfile?> currentMember();

  Future<SignInOutcome> signIn(String email, String password);

  /// Creates the account, then claims membership with [inviteCode] — the code
  /// is what decides the role, and it is checked on the server.
  Future<SignInOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
    String? childId,
  });

  Future<void> signOut();

  /// Everyone in the club. Needed to notify athletes of a proposal and to show
  /// who is going.
  Future<List<UserProfile>> roster();
}
