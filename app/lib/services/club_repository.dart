/// The seam that makes "mock now, real later" work: the demo ships
/// [MockClubRepository], and a Firestore implementation can replace it without
/// the UI changing.
library;

import '../models/app_notification.dart';
import '../models/day_conditions.dart';
import '../models/session.dart';
import '../models/user_profile.dart';

abstract class ClubRepository {
  List<UserProfile> accounts();

  UserProfile? authenticate(String email, String password);

  List<DayConditions> upcomingDays();

  Set<DateTime> coachUnavailableDays();
  void markCoachUnavailable(DateTime date);

  List<Session> sessions();
  List<Session> sessionsForDate(DateTime date);

  void upsertSession(Session session);

  List<AppNotification> notificationsForUser(String userId);
  void addNotification(AppNotification notification);

  /// A real backend would assign these server-side.
  String nextId(String prefix);
}
