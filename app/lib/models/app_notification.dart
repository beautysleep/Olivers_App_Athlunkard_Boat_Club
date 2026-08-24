/// Push is not wired up yet, so notifications live here and surface in an
/// in-app inbox instead.
library;

enum NotificationType {
  proposalReceived,
  sessionConfirmed,
  sessionCancelled,
  sessionPivoted,
  childCommitted,
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.recipientId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.sessionId,
  });

  final String id;
  final String recipientId;
  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? sessionId;
}
