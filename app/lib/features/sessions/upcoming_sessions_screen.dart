import 'package:flutter/material.dart';

import '../../models/session.dart';
import '../../models/user_profile.dart';
import '../../services/app_scope.dart';
import '../../shared/condition_style.dart';
import '../../shared/formatting.dart';
import 'session_detail_screen.dart';

/// "Upcoming Sessions" — an ordered list (not a calendar) of the sessions
/// relevant to the current role, with headcount vs. the minimum shown
/// automatically. Tap one for detail.
class UpcomingSessionsScreen extends StatelessWidget {
  const UpcomingSessionsScreen({super.key});

  String _statusLine(Session s) {
    switch (s.lifecycle) {
      case SessionLifecycle.cancelledWeatherPivot:
        return 'Moved to land training';
      case SessionLifecycle.cancelledOutright:
        return 'Cancelled';
      case SessionLifecycle.proposed:
        return s.status == SessionStatus.confirmed
            ? 'Confirmed · ${s.committedCount} going'
            : 'Not yet possible · ${s.committedCount}/${s.minimumCrew}';
    }
  }

  String _emptyMessage(UserRole role) => switch (role) {
        UserRole.coach => 'No sessions yet. Propose one from the Calendar.',
        UserRole.athlete =>
          "You haven't committed to any sessions yet. Check your Alerts.",
        UserRole.parent => 'Your child has no upcoming sessions yet.',
      };

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final user = appState.currentUser!;
    final sessions = appState.sessionsForCurrentUser();

    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.directions_boat_outlined,
                  size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                _emptyMessage(user.role),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sessions.length,
      itemBuilder: (context, i) {
        final s = sessions[i];
        final style = conditionStyle(s.conditions);
        final confirmed = !s.isCancelled && s.status == SessionStatus.confirmed;
        return Card(
          child: ListTile(
            leading: Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 4),
              decoration:
                  BoxDecoration(color: style.color, shape: BoxShape.circle),
            ),
            title: Text(formatDayTime(s.date),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(_statusLine(s)),
            trailing: Icon(
              s.isCancelled
                  ? Icons.block
                  : confirmed
                      ? Icons.check_circle
                      : Icons.chevron_right,
              color: s.isCancelled
                  ? Colors.grey
                  : confirmed
                      ? const Color(0xFF2E7D32)
                      : null,
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SessionDetailScreen(sessionId: s.id),
            )),
          ),
        );
      },
    );
  }
}
