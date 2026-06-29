import 'package:flutter/material.dart';

import '../../models/app_notification.dart';
import '../../services/app_scope.dart';
import '../sessions/session_detail_screen.dart';

/// The in-app notification inbox. No real push yet (FCM comes later) — this is
/// the same information an athlete/parent/coach would receive on their phone.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final notes = appState.notifications();

    if (notes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No notifications yet.',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: notes.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final n = notes[i];
        final (icon, color) = _style(n.type);
        final session =
            n.sessionId == null ? null : appState.sessionById(n.sessionId!);
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.15),
            child: Icon(icon, color: color),
          ),
          title: Text(n.title,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('${n.body}\n${_relative(n.createdAt)}'),
          isThreeLine: true,
          trailing: session != null ? const Icon(Icons.chevron_right) : null,
          onTap: session == null
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SessionDetailScreen(sessionId: session.id),
                  )),
        );
      },
    );
  }

  (IconData, Color) _style(NotificationType type) => switch (type) {
        NotificationType.proposalReceived => (
            Icons.mark_email_unread,
            const Color(0xFF1565C0)
          ),
        NotificationType.sessionConfirmed => (
            Icons.check_circle,
            const Color(0xFF2E7D32)
          ),
        NotificationType.sessionCancelled => (
            Icons.cancel,
            const Color(0xFFC62828)
          ),
        NotificationType.sessionPivoted => (
            Icons.directions_run,
            const Color(0xFFEF6C00)
          ),
        NotificationType.childCommitted => (
            Icons.family_restroom,
            const Color(0xFF6A1B9A)
          ),
      };

  String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
