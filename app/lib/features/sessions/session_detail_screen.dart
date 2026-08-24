import 'package:flutter/material.dart';

import '../../models/session.dart';
import '../../models/user_profile.dart';
import '../../services/app_scope.dart';
import '../../shared/avatar.dart';
import '../../shared/condition_style.dart';
import '../../shared/formatting.dart';

/// Detail for one session: conditions, status, who's going, and the actions
/// available to the current role (athlete accept/decline; coach cancel/pivot;
/// parent read-only).
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final session = appState.sessionById(sessionId);
    final user = appState.currentUser;

    if (session == null || user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Session')),
        body: const Center(child: Text('Session not found.')),
      );
    }

    final style = conditionStyle(session.conditionRating);

    return Scaffold(
      appBar: AppBar(title: Text(formatDayDate(session.meetingTime))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatDayTime(session.meetingTime),
                  style: Theme.of(context).textTheme.titleLarge),
              Chip(
                backgroundColor: style.color.withValues(alpha: 0.15),
                side: BorderSide(color: style.color),
                avatar: CircleAvatar(backgroundColor: style.color, radius: 6),
                label: Text(style.shortLabel),
              ),
            ],
          ),
          Text('Run by ${session.coach.displayName}'),
          const SizedBox(height: 16),
          _StatusBanner(session: session),
          const SizedBox(height: 20),
          Text('Going', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ProfileCircleRow(users: session.committedAthletes),
          const SizedBox(height: 12),
          if (session.committedAthletes.isEmpty)
            const Text('No commitments yet.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final a in session.committedAthletes)
                  Chip(
                    avatar: ProfileCircle(user: a, radius: 12),
                    label: Text(a.displayName),
                  ),
              ],
            ),
          const SizedBox(height: 24),
          _actions(context, appState, session, user),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    appState,
    Session session,
    UserProfile user,
  ) {
    if (session.isCancelled) {
      return const SizedBox.shrink();
    }

    switch (user.role) {
      case UserRole.athlete:
        final going = session.isCommitted(user);
        return Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: going
                    ? null
                    : () {
                        appState.respondToProposal(session, accept: true);
                        _snack(context, "You're in — see you on the water.");
                      },
                icon: const Icon(Icons.check),
                label: const Text('Accept'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: going
                    ? () {
                        appState.respondToProposal(session, accept: false);
                        _snack(context, 'You have declined this session.');
                      }
                    : null,
                icon: const Icon(Icons.close),
                label: const Text('Decline'),
              ),
            ),
          ],
        );

      case UserRole.coach:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change this session',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _confirmCancel(context, appState, session,
                  pivot: true),
              icon: const Icon(Icons.directions_run),
              label: const Text('Move to land training'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
              onPressed: () => _confirmCancel(context, appState, session,
                  pivot: false),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel outright'),
            ),
          ],
        );

      case UserRole.parent:
        return Card(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'You can see this because your child is attending. '
              "You'll be notified if anything changes.",
            ),
          ),
        );
    }
  }

  Future<void> _confirmCancel(
    BuildContext context,
    appState,
    Session session, {
    required bool pivot,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(pivot ? 'Move to land training?' : 'Cancel session?'),
        content: Text(pivot
            ? 'Athletes who committed will be told the session has moved off '
                'the water to land training.'
            : 'Athletes who committed will be told the session is cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(pivot ? 'Move to land' : 'Cancel it'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      appState.cancelSession(session, pivotToLand: pivot);
      _snack(context,
          pivot ? 'Moved to land — athletes notified.' : 'Cancelled — athletes notified.');
    }
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final (icon, color, title, subtitle) = switch (session.lifecycle) {
      SessionLifecycle.cancelledWeatherPivot => (
          Icons.directions_run,
          const Color(0xFFEF6C00),
          'Moved to land training',
          'Conditions turned — training continues on land.',
        ),
      SessionLifecycle.cancelledOutright => (
          Icons.cancel,
          const Color(0xFFC62828),
          'Cancelled',
          'This session will not run.',
        ),
      SessionLifecycle.proposed =>
        session.status == SessionStatus.confirmed
            ? (
                Icons.check_circle,
                const Color(0xFF2E7D32),
                'Confirmed — the session is on',
                '${session.committedCount} going.',
              )
            : (
                Icons.hourglass_top,
                const Color(0xFFEF6C00),
                'Not yet possible',
                '${session.stillNeeded} more needed to reach '
                    '${session.minimumCrew}.',
              ),
    };

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: color)),
                  Text(subtitle),
                  if (session.lifecycle == SessionLifecycle.proposed &&
                      session.status != SessionStatus.confirmed) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: session.committedCount / session.minimumCrew,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '${session.committedCount} / ${session.minimumCrew} committed'),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
