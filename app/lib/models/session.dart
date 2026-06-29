/// The core domain object for v1: a single on-water session that the coach has
/// proposed and that athletes commit to.
///
/// The row / no-row decision and the commitment loop are the heart of the app,
/// so the *rules* live here (not in the UI) to keep them pure and testable.
library;

/// How good the conditions look for a given day.
///
/// In v1 this is a planning-level rating surfaced to the coach and athletes.
/// The exact numeric thresholds behind it are TBD with the coaches, so we keep
/// it as a simple traffic-light enum for now.
enum Conditions { green, amber, red }

/// Whether the proposed session has gathered enough commitment to actually run.
enum SessionStatus {
  /// Below the minimum crew, or no coach has committed to run it yet.
  notYetPossible,

  /// Enough athletes have committed *and* a coach is committed (incl. safety
  /// boat). The session is on.
  confirmed,
}

/// A proposed session plus the commitments gathered so far.
class Session {
  Session({
    required this.date,
    required this.conditions,
    required this.coachName,
    required this.coachCommitted,
    required this.committedAthletes,
    this.minimumCrew = 4,
  });

  /// The day/time the session is proposed for.
  final DateTime date;

  /// Planning-level condition rating for the day.
  final Conditions conditions;

  /// The coach who proposed the session.
  final String coachName;

  /// A confirmed session must always have a coach committed to run it (incl.
  /// safety boat). Until that's true, the session can't confirm.
  final bool coachCommitted;

  /// Names of athletes who have accepted so far. Athletes want to see who else
  /// is going, so we keep the names, not just a count.
  final List<String> committedAthletes;

  /// The minimum crew needed before a session can confirm. Fixed at 4 for v1,
  /// but kept as a field so it's easy to make configurable later.
  final int minimumCrew;

  /// How many athletes have committed.
  int get committedCount => committedAthletes.length;

  /// The single rule that decides whether the session is on: enough crew *and*
  /// a committed coach. Conditions being red is surfaced to the coach for the
  /// cancel / pivot decision (out of scope for this first screen), so it does
  /// not auto-block here.
  SessionStatus get status =>
      (committedCount >= minimumCrew && coachCommitted)
          ? SessionStatus.confirmed
          : SessionStatus.notYetPossible;

  /// How many more athletes are needed to reach the minimum (0 once met).
  int get stillNeeded =>
      (minimumCrew - committedCount).clamp(0, minimumCrew);
}
