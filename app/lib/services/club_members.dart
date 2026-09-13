/// A club member as stored in `users/{uid}`, written by the membership function
/// when someone signs up with an invite code. Pure — no Firestore dependency —
/// so the refusals are testable directly.
library;

import '../models/user_profile.dart';

/// Null when the document cannot be read as a member this build understands.
/// A role we do not know must not become a role we do: it decides what the
/// person is allowed to do.
UserProfile? clubMemberFromDocument(
  String uid,
  Map<String, dynamic>? document,
) {
  if (document == null) return null;

  final role = UserRole.values.asNameMap()[document['role']];
  final displayName = (document['display_name'] as String?)?.trim() ?? '';
  if (role == null || displayName.isEmpty) return null;

  return UserProfile(
    id: uid,
    displayName: displayName,
    email: (document['email'] as String?) ?? '',
    role: role,
    childId: document['child_uid'] as String?,
  );
}

/// Ordered by name so the crew reads the same on every screen and every device.
List<UserProfile> clubRosterFromDocuments(
  Map<String, Map<String, dynamic>> documents,
) {
  final roster = <UserProfile>[
    for (final entry in documents.entries)
      ?clubMemberFromDocument(entry.key, entry.value),
  ];
  roster.sort((a, b) => a.displayName.compareTo(b.displayName));
  return roster;
}
