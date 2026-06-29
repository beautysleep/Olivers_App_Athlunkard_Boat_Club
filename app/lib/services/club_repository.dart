/// The data boundary for the whole app.
///
/// Everything the UI needs to read or persist goes through this interface. The
/// demo ships a [MockClubRepository] with in-memory seed data; when the backend
/// is ready, a `FirestoreClubRepository` implements the same methods and the UI
/// does not change. This is the seam that makes "mock now, real later" work.
library;

import '../models/app_notification.dart';
import '../models/day_conditions.dart';
import '../models/session.dart';
import '../models/user_profile.dart';

abstract class ClubRepository {
  // --- Authentication ------------------------------------------------------
  /// Accounts that can sign in (used to offer quick-fill in the demo login).
  List<UserProfile> accounts();

  /// Returns the matching user, or null if the credentials don't match.
  UserProfile? authenticate(String email, String password);

  // --- Calendar ------------------------------------------------------------
  List<DayConditions> upcomingDays();

  /// Days the coach has explicitly marked themselves unavailable for.
  Set<DateTime> unavailableDays();
  void markUnavailable(DateTime date);

  // --- Sessions ------------------------------------------------------------
  List<Session> sessions();
  Session? sessionForDate(DateTime date);

  /// Insert or update a session (after a proposal, a commit, or a cancel).
  void upsertSession(Session session);

  // --- Notifications -------------------------------------------------------
  List<AppNotification> notificationsForUser(String userId);
  void addNotification(AppNotification notification);

  // --- Ids -----------------------------------------------------------------
  /// Mint a new id. A real backend would assign these server-side.
  String nextId(String prefix);
}
