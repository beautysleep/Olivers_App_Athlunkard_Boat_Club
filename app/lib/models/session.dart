import 'user_profile.dart';

enum Conditions { green, amber, red }

/// Deterioration never auto-cancels. A worsening forecast routes the coach here
/// to choose, which is why there is no separate cancellation path.
enum SessionLifecycle { proposed, cancelledWeatherPivot, cancelledOutright }

enum SessionStatus { notYetPossible, confirmed }

class Session {
  Session({
    required this.id,
    required this.meetingTime,
    required this.highTideTime,
    required this.conditionRating,
    required this.coach,
    required this.committedAthletes,
    this.lifecycle = SessionLifecycle.proposed,
    this.minimumCrew = 4,
  });

  final String id;

  final DateTime meetingTime;

  /// Which of the day's two high tides this session rows on. [meetingTime]
  /// cannot tell them apart, because the coach picks a time before the tide
  /// rather than at it.
  final DateTime highTideTime;

  final Conditions conditionRating;
  final UserProfile coach;

  /// The people, not a count, so the UI can show who is going.
  final List<UserProfile> committedAthletes;

  SessionLifecycle lifecycle;
  final int minimumCrew;

  int get committedCount => committedAthletes.length;

  bool get isCancelled =>
      lifecycle == SessionLifecycle.cancelledWeatherPivot ||
      lifecycle == SessionLifecycle.cancelledOutright;

  /// Proposing a session is itself the coach committing to run it, safety boat
  /// included, until they cancel.
  bool get coachCommitted => !isCancelled;

  /// Red conditions deliberately do not block here: they are surfaced to the
  /// coach for the cancel-or-pivot decision instead.
  SessionStatus get status => (committedCount >= minimumCrew && coachCommitted)
      ? SessionStatus.confirmed
      : SessionStatus.notYetPossible;

  int get stillNeeded => (minimumCrew - committedCount).clamp(0, minimumCrew);

  bool isCommitted(UserProfile athlete) =>
      committedAthletes.any((committed) => committed.id == athlete.id);
}
