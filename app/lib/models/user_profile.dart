enum UserRole { coach, athlete, parent }

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

  /// Set only on a parent, linking them to the athlete whose commitments they
  /// are notified about.
  final String? childId;

  String get initials {
    final nameParts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (nameParts.isEmpty) return '?';
    if (nameParts.length == 1) {
      return nameParts.first.substring(0, 1).toUpperCase();
    }
    return (nameParts.first.substring(0, 1) + nameParts.last.substring(0, 1))
        .toUpperCase();
  }
}
