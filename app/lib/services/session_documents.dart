/// A session as it is stored, and back again. Pure: no Firestore dependency, so
/// the round trip and the awkward cases are unit-testable directly.
library;

import '../models/session.dart';
import '../models/user_profile.dart';

/// People are stored by id, not copied in. A session's job is to say who is
/// coming, not to hold a stale snapshot of who they were when they accepted.
Map<String, dynamic> sessionToDocument(Session session) => {
  'meeting_time': session.meetingTime,
  'high_tide_time': session.highTideTime,
  'condition_rating': session.conditionRating.name,
  'coach_id': session.coach.id,
  'committed_athlete_ids': [
    for (final athlete in session.committedAthletes) athlete.id,
  ],
  'lifecycle': session.lifecycle.name,
  'minimum_crew': session.minimumCrew,
};

/// Null when the document cannot be read as a session this build understands —
/// an unknown coach, an unknown lifecycle. Guessing would put a session on the
/// calendar that nobody can account for.
Session? sessionFromDocument(
  String id,
  Map<String, dynamic> document,
  UserProfile? Function(String id) findAccount,
) {
  final coach = findAccount(document['coach_id'] as String? ?? '');
  if (coach == null) return null;

  final lifecycle = SessionLifecycle.values.asNameMap()[document['lifecycle']];
  final rating = Conditions.values.asNameMap()[document['condition_rating']];
  if (lifecycle == null || rating == null) return null;

  final meetingTime = document['meeting_time'] as DateTime?;
  final highTideTime = document['high_tide_time'] as DateTime?;
  if (meetingTime == null || highTideTime == null) return null;

  return Session(
    id: id,
    meetingTime: meetingTime,
    highTideTime: highTideTime,
    conditionRating: rating,
    coach: coach,
    // An athlete who has left the club drops out of the crew rather than
    // becoming a placeholder nobody can contact.
    committedAthletes: [
      for (final athleteId
          in (document['committed_athlete_ids'] as List?) ?? const [])
        ?findAccount(athleteId as String),
    ],
    lifecycle: lifecycle,
    minimumCrew: (document['minimum_crew'] as num?)?.toInt() ?? 4,
  );
}
