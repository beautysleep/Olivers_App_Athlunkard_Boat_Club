import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/member_directory.dart';

/// Ids match MockClubRepository's seeded people, so a signed-in member lines up
/// with the crews already committed to the seeded sessions. Sessions are still
/// mock on this branch; they move to Firestore next, and these become real uids
/// then.
const coachProfile = UserProfile(
  id: 'u_coach',
  displayName: 'Niamh Ryan',
  email: 'coach@athlunkard.club',
  role: UserRole.coach,
);
const saoirseProfile = UserProfile(
  id: 'u_saoirse',
  displayName: 'Saoirse Walsh',
  email: 'saoirse@athlunkard.club',
  role: UserRole.athlete,
);
const parentProfile = UserProfile(
  id: 'u_parent',
  displayName: "Liam O'Brien",
  email: 'parent@athlunkard.club',
  role: UserRole.parent,
  childId: 'u_cian',
);

const _knownMembers = [coachProfile, saoirseProfile, parentProfile];
const fakePassword = 'rowing';

class FakeMemberDirectory implements MemberDirectory {
  FakeMemberDirectory({this.roster_ = _knownMembers});

  final List<UserProfile> roster_;
  UserProfile? signedIn;
  bool signedOut = false;

  @override
  Future<UserProfile?> currentMember() async => signedIn;

  @override
  Future<SignInOutcome> signIn(String email, String password) async {
    if (password != fakePassword) return SignInOutcome.wrongEmailOrPassword;
    for (final member in roster_) {
      if (member.email == email) {
        signedIn = member;
        return SignInOutcome.succeeded;
      }
    }
    return SignInOutcome.wrongEmailOrPassword;
  }

  @override
  Future<SignInOutcome> signUp({
    required String email,
    required String password,
    required String displayName,
    required String inviteCode,
    String? childId,
  }) async => SignInOutcome.failed;

  @override
  Future<void> signOut() async {
    signedOut = true;
    signedIn = null;
  }

  @override
  Future<List<UserProfile>> roster() async => roster_;
}
