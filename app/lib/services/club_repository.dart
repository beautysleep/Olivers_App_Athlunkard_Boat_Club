/// The seam that makes "mock now, real later" work: the demo ships
/// [MockClubRepository], and a Firestore implementation can replace it without
/// the UI changing. Sessions have their own seam — [SessionRepository] — now
/// that they are the first of these four concerns to become real.
library;

import '../models/app_notification.dart';
import '../models/day_conditions.dart';

abstract class ClubRepository {
  List<DayConditions> upcomingDays();

  Set<DateTime> coachUnavailableDays();
  void markCoachUnavailable(DateTime date);

  List<AppNotification> notificationsForUser(String userId);
  void addNotification(AppNotification notification);

  /// A real backend would assign these server-side.
  String nextId(String prefix);
}
