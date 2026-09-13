import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/session.dart';
import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/session_documents.dart';

const _coach = UserProfile(
  id: 'u_coach',
  displayName: 'Niamh Ryan',
  email: 'coach@athlunkard.club',
  role: UserRole.coach,
);
const _saoirse = UserProfile(
  id: 'u_saoirse',
  displayName: 'Saoirse Kelly',
  email: 'saoirse@athlunkard.club',
  role: UserRole.athlete,
);

final _club = {_coach.id: _coach, _saoirse.id: _saoirse};
UserProfile? _findAccount(String id) => _club[id];

Session _session() => Session(
  id: 's_1',
  meetingTime: DateTime.utc(2026, 8, 26, 17),
  highTideTime: DateTime.utc(2026, 8, 26, 17, 51),
  conditionRating: Conditions.amber,
  coach: _coach,
  committedAthletes: [_saoirse],
  lifecycle: SessionLifecycle.cancelledWeatherPivot,
);

void main() {
  group('a session as a Firestore document', () {
    test('stores people by id rather than copying their profiles', () {
      final document = sessionToDocument(_session());

      expect(document['coach_id'], 'u_coach');
      expect(document['committed_athlete_ids'], ['u_saoirse']);
      expect(document.containsKey('coach'), isFalse);
    });

    test('survives a round trip unchanged', () {
      final original = _session();

      final restored = sessionFromDocument(
        's_1',
        sessionToDocument(original),
        _findAccount,
      )!;

      expect(restored.id, original.id);
      expect(restored.meetingTime, original.meetingTime);
      expect(restored.highTideTime, original.highTideTime);
      expect(restored.conditionRating, original.conditionRating);
      expect(restored.coach.id, original.coach.id);
      expect(restored.committedAthletes.map((a) => a.id), ['u_saoirse']);
      expect(restored.lifecycle, original.lifecycle);
      expect(restored.minimumCrew, original.minimumCrew);
    });

    test('a session whose coach is not a known account is not a session', () {
      final document = sessionToDocument(_session())
        ..['coach_id'] = 'u_departed';

      expect(sessionFromDocument('s_1', document, _findAccount), isNull);
    });

    test('an athlete who has left is dropped, not faked', () {
      final document = sessionToDocument(_session())
        ..['committed_athlete_ids'] = ['u_saoirse', 'u_departed'];

      final restored = sessionFromDocument('s_1', document, _findAccount)!;

      expect(restored.committedAthletes.map((a) => a.id), ['u_saoirse']);
    });

    test('a lifecycle this build does not know is not guessed at', () {
      final document = sessionToDocument(_session())
        ..['lifecycle'] = 'abandoned';

      expect(sessionFromDocument('s_1', document, _findAccount), isNull);
    });
  });
}
