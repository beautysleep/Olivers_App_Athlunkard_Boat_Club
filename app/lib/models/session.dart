/// The core domain object for v1: a single on-water session that the coach has
/// proposed and that athletes commit to.
///
/// The row / no-row decision and the commitment loop are the heart of the app,
/// so the *rules* live here (not in the UI) to keep them pure and testable.
library;

import 'user_profile.dart';

/// How good the conditions look for a given day.
///
/// In v1 this is a planning-level rating surfaced to the coach and athletes.
/// The exact numeric thresholds behind it are TBD with the coaches, so we keep
/// it as a simple traffic-light enum for now.
enum Conditions { green, amber, red }

/// What the coach has decided about a proposed session over its lifetime.
///
/// Deterioration does not auto-cancel: a worsening forecast routes the coach
/// here to choose pivot-to-land or cancel-outright. There is no separate
/// cancellation path.
enum SessionLifecycle {
  /// Proposed and live — gathering commitments.
  proposed,

  /// Cancelled on the water but moved to land training; committed athletes
  /// still train.
  cancelledWeatherPivot,

  /// Cancelled outright; the coach can no longer run it.
  cancelledOutright,
}

/// Whether a *still-live* proposed session has gathered enough to actually run.
enum SessionStatus {
  /// Below the minimum crew, or no coach is committed to run it.
  notYetPossible,

  /// Enough athletes have committed *and* a coach is committed (incl. safety
  /// boat). The session is on.
  confirmed,
}

/// A proposed session plus the commitments gathered so far.
class Session {
  Session({
    required this.id,
    required this.date,
    required this.conditions,
    required this.coach,
    required this.committedAthletes,
    this.lifecycle = SessionLifecycle.proposed,
    this.minimumCrew = 4,
  });

  final String id;

  /// The day/time the session is proposed for.
  final DateTime date;

  /// Planning-level condition rating captured when the session was proposed.
  final Conditions conditions;

  /// The coach who proposed the session and will run it.
  final UserProfile coach;

  /// Athletes who have accepted so far. We keep the people, not just a count,
  /// so the UI can show who's going as profile circles.
  final List<UserProfile> committedAthletes;

  /// Where the session is in its lifecycle. Mutable because the coach can act
  /// on it after proposing (pivot / cancel) — kept simple for the demo.
  SessionLifecycle lifecycle;

  /// The minimum crew needed before a session can confirm. Fixed at 4 for v1,
  /// but kept as a field so it's easy to make configurable later.
  final int minimumCrew;

  int get committedCount => committedAthletes.length;

  bool get isCancelled =>
      lifecycle == SessionLifecycle.cancelledWeatherPivot ||
      lifecycle == SessionLifecycle.cancelledOutright;

  /// A coach who proposed the session is, by definition, committed to run it
  /// (incl. safety boat) — until they cancel.
  bool get coachCommitted => !isCancelled;

  /// The single rule that decides whether the session is on: enough crew *and*
  /// a committed coach. Conditions being red is surfaced to the coach for the
  /// cancel / pivot decision, so it does not auto-block here.
  SessionStatus get status =>
      (committedCount >= minimumCrew && coachCommitted)
          ? SessionStatus.confirmed
          : SessionStatus.notYetPossible;

  /// How many more athletes are needed to reach the minimum (0 once met).
  int get stillNeeded => (minimumCrew - committedCount).clamp(0, minimumCrew);

  /// Whether the given athlete is already committed (compared by id).
  bool isCommitted(UserProfile athlete) =>
      committedAthletes.any((a) => a.id == athlete.id);
}
