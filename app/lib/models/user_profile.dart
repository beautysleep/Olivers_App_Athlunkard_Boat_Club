/// People in the club and the role each one plays.
///
/// Pure Dart (no Flutter imports) so the same models can be reused by a future
/// backend without dragging UI dependencies along.
library;

/// The three roles in v1. Coach is primary, athlete secondary, parent tertiary.
enum UserRole { coach, athlete, parent }

/// A single person: enough to identify who is who and drive the role-specific
/// experience. No extra profile complexity in v1.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.email,
    required this.role,
    this.childId,
  });

  final String id;
  final String displayName;
  final String email;
  final UserRole role;

  /// For a parent: the id of the athlete they are linked to (so they can be
  /// notified when that child commits). Null for coaches and athletes.
  final String? childId;

  /// One or two initials for avatar circles, derived from the display name.
  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}
