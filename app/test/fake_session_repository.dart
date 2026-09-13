import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/session_repository.dart';

/// In-memory [SessionRepository] for tests — the session-only analogue of
/// [FakeMemberDirectory]. [actingAs] stands in for the identity a real
/// backend would derive from the caller's verified token: switch it the same
/// way a test logs out and back in as someone else against the real thing.
class FakeSessionRepository implements SessionRepository {
  FakeSessionRepository({required this.actingAs, List<Session>? seed})
    : _sessions = seed ?? [];

  UserProfile actingAs;

  final List<Session> _sessions;
  int _idCounter = 1000;

  @override
  Future<List<Session>> loadSessions(
    UserProfile? Function(String id) findAccount,
  ) async => List.unmodifiable(_sessions);

  @override
  Future<String> proposeSession({
    required DateTime meetingTime,
    required DateTime highTideTime,
    required Conditions conditionRating,
    int minimumCrew = 4,
  }) async {
    final id = 's_${_idCounter++}';
    _sessions.add(
      Session(
        id: id,
        meetingTime: meetingTime,
        highTideTime: highTideTime,
        conditionRating: conditionRating,
        coach: actingAs,
        committedAthletes: [],
        minimumCrew: minimumCrew,
      ),
    );
    return id;
  }

  @override
  Future<void> respondToSession(
    String sessionId, {
    required bool accept,
  }) async {
    final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) return;
    session.committedAthletes.removeWhere((a) => a.id == actingAs.id);
    if (accept) session.committedAthletes.add(actingAs);
  }

  @override
  Future<void> cancelSession(
    String sessionId, {
    required bool pivotToLand,
  }) async {
    final session = _sessions.where((s) => s.id == sessionId).firstOrNull;
    if (session == null) return;
    session.lifecycle = pivotToLand
        ? SessionLifecycle.cancelledWeatherPivot
        : SessionLifecycle.cancelledOutright;
  }
}
