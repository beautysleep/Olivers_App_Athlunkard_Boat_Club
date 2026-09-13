import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/models/user_profile.dart';
import 'package:athlunkard_boat_club/services/club_members.dart';

Map<String, dynamic> _document({String role = 'athlete', String? childUid}) => {
  'display_name': 'Saoirse Walsh',
  'email': 'saoirse@athlunkard.club',
  'role': role,
  'child_uid': childUid,
};

void main() {
  group('a club member read back from their profile document', () {
    test('is identified by the uid they signed in with', () {
      final member = clubMemberFromDocument('abc123', _document())!;

      expect(member.id, 'abc123');
      expect(member.displayName, 'Saoirse Walsh');
      expect(member.email, 'saoirse@athlunkard.club');
      expect(member.role, UserRole.athlete);
    });

    test('a parent carries the athlete they are linked to', () {
      final member = clubMemberFromDocument(
        'p1',
        _document(role: 'parent', childUid: 'abc123'),
      )!;

      expect(member.role, UserRole.parent);
      expect(member.childId, 'abc123');
    });

    test('a role this build does not know is not guessed at', () {
      expect(clubMemberFromDocument('x', _document(role: 'captain')), isNull);
    });

    test('a profile with no name is not a member we can show', () {
      final nameless = _document()..['display_name'] = '';

      expect(clubMemberFromDocument('x', nameless), isNull);
    });

    test('no document at all is not a member', () {
      expect(clubMemberFromDocument('x', null), isNull);
    });
  });

  group('the roster', () {
    test('keeps only the members it could read', () {
      final roster = clubRosterFromDocuments({
        'a': _document(),
        'b': _document(role: 'captain'),
        'c': _document(role: 'coach'),
      });

      expect(roster.map((m) => m.id), ['a', 'c']);
    });

    test('is ordered by name so the crew reads the same everywhere', () {
      final roster = clubRosterFromDocuments({
        'b': _document()..['display_name'] = 'Zoe',
        'a': _document()..['display_name'] = 'Aoife',
      });

      expect(roster.map((m) => m.displayName), ['Aoife', 'Zoe']);
    });
  });
}
