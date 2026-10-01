/// The seam a real, Firestore-backed implementation fills in behind
/// [ClubRepository]'s still-mock day/coach-availability/notification
/// concerns. Shaped around the three things a server can actually authorise
/// — propose, respond, cancel — rather than a generic overwrite: a real
/// backend decides for itself exactly what each intent is allowed to change,
/// which a blind `upsertSession(Session)` cannot express.
library;

import '../models/session.dart';
import '../models/user_profile.dart';

/// The sessions functions' URLs, from `terraform output
/// propose_session_uri` etc. Passed in at build time rather than committed,
/// the same way [membershipEndpoint] is:
///
///     flutter run --dart-define=PROPOSE_SESSION_ENDPOINT=https://...
const proposeSessionEndpoint = String.fromEnvironment(
  'PROPOSE_SESSION_ENDPOINT',
);
const respondToSessionEndpoint = String.fromEnvironment(
  'RESPOND_TO_SESSION_ENDPOINT',
);
const cancelSessionEndpoint = String.fromEnvironment('CANCEL_SESSION_ENDPOINT');
const registerDeviceTokenEndpoint = String.fromEnvironment(
  'REGISTER_DEVICE_TOKEN_ENDPOINT',
);

abstract class SessionRepository {
  /// Every session the caller can see. [findAccount] resolves a stored id
  /// back to the [UserProfile] it names — sessions are only loaded once the
  /// roster already is, so the resolution never has to guess.
  Future<List<Session>> loadSessions(
    UserProfile? Function(String id) findAccount,
  );

  /// Returns the new session's id. The coach is never a parameter here: a
  /// real backend derives who is proposing from the caller's own verified
  /// identity, not from anything the client claims.
  Future<String> proposeSession({
    required DateTime meetingTime,
    required DateTime highTideTime,
    required Conditions conditionRating,
    int minimumCrew = 4,
  });

  /// The athlete responding is likewise always the caller themselves.
  Future<void> respondToSession(String sessionId, {required bool accept});

  Future<void> cancelSession(String sessionId, {required bool pivotToLand});
}
