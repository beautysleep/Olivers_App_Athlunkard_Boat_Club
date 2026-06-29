import 'package:flutter/material.dart';

import '../../models/session.dart';

/// The first interactive flow: an athlete looks at a proposed session, accepts
/// or declines, and watches it move toward "Confirmed".
///
/// Everything here runs on in-memory mock data — there is no backend yet. The
/// point is to make the commitment loop visible and tappable.
class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  // --- Mock proposal data (what the coach has set up) -----------------------
  static const _coachName = 'Coach Niamh';
  final DateTime _date = DateTime(2026, 7, 4, 6, 30);
  final Conditions _conditions = Conditions.amber;

  // Athletes who had already committed before "you" looked at it.
  final List<String> _otherAthletes = ['Aoife', 'Cian', 'Saoirse'];

  // The one piece of state this screen owns: has the current user accepted?
  bool _youAccepted = false;

  /// Build the session as it stands right now, including "you" if accepted.
  Session get _session => Session(
        date: _date,
        conditions: _conditions,
        coachName: _coachName,
        coachCommitted: true,
        committedAthletes: [
          ..._otherAthletes,
          if (_youAccepted) 'You',
        ],
      );

  void _accept() => setState(() => _youAccepted = true);
  void _decline() => setState(() => _youAccepted = false);

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Next session'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SessionCard(session: session),
            const SizedBox(height: 16),
            _CommitmentControls(
              youAccepted: _youAccepted,
              onAccept: _accept,
              onDecline: _decline,
            ),
          ],
        ),
      ),
    );
  }
}

/// The card showing the proposed session: when, conditions, status, and who is
/// going.
class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final confirmed = session.status == SessionStatus.confirmed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDate(session.date),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                _ConditionChip(conditions: session.conditions),
              ],
            ),
            const SizedBox(height: 4),
            Text('Proposed by ${session.coachName}'),
            const Divider(height: 24),

            // Status banner — the thing that changes as commitments arrive.
            Row(
              children: [
                Icon(
                  confirmed ? Icons.check_circle : Icons.hourglass_top,
                  color: confirmed ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    confirmed
                        ? 'Confirmed — the session is on'
                        : 'Not yet possible — '
                            '${session.stillNeeded} more needed',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Text('${session.committedCount} / ${session.minimumCrew} committed'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: session.committedCount / session.minimumCrew,
              minHeight: 8,
            ),
            const SizedBox(height: 16),

            Text('Going', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (session.committedAthletes.isEmpty)
              const Text('Nobody yet')
            else
              Wrap(
                spacing: 8,
                children: [
                  for (final name in session.committedAthletes)
                    Chip(label: Text(name)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Accept / decline buttons. Disabled state reflects the current choice.
class _CommitmentControls extends StatelessWidget {
  const _CommitmentControls({
    required this.youAccepted,
    required this.onAccept,
    required this.onDecline,
  });

  final bool youAccepted;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: youAccepted ? null : onAccept,
            icon: const Icon(Icons.check),
            label: const Text('Accept'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: youAccepted ? onDecline : null,
            icon: const Icon(Icons.close),
            label: const Text('Decline'),
          ),
        ),
      ],
    );
  }
}

/// Small coloured pill showing the traffic-light condition rating.
class _ConditionChip extends StatelessWidget {
  const _ConditionChip({required this.conditions});

  final Conditions conditions;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (conditions) {
      Conditions.green => (Colors.green, 'Good'),
      Conditions.amber => (Colors.orange, 'Marginal'),
      Conditions.red => (Colors.red, 'Unsafe'),
    };
    return Chip(
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
      avatar: CircleAvatar(backgroundColor: color, radius: 6),
      label: Text(label),
    );
  }
}

String _formatDate(DateTime d) {
  const weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]}, $hh:$mm';
}
