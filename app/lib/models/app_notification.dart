/// An in-app notification. v1 has no real push yet (Firebase Cloud Messaging
/// comes later), so notifications are modelled here and shown in an inbox.
library;

enum NotificationType {
  /// Athlete: the coach has proposed a session you can attend.
  proposalReceived,

  /// Athlete + coach: the session reached the minimum and is confirmed.
  sessionConfirmed,

  /// Athlete: a session you committed to was cancelled outright.
  sessionCancelled,

  /// Athlete: a session was moved off the water to land training.
  sessionPivoted,

  /// Parent: your child has committed to a session (plan transport).
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

  /// The user who should see this notification.
  final String recipientId;

  final NotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;

  /// The session this is about, if any (lets the inbox deep-link to it).
  final String? sessionId;
}
