import 'package:flutter/material.dart';

import '../../models/session.dart';
import '../../services/app_scope.dart';
import '../../shared/formatting.dart';
import '../sessions/session_detail_screen.dart';
import 'day_card.dart';

/// The calendar: a horizontally scrollable strip of day cards, colour-coded by
/// conditions. The coach proposes or marks unavailable from a card's back; the
/// athlete reads conditions and opens any proposed session.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final user = appState.currentUser!;
    final days = appState.upcomingDays();
    final unavailable = appState.coachUnavailableDays();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Upcoming conditions',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Swipe sideways. Tap a day to flip it and see the metrics.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 332,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final day = days[i];
                final isUnavailable = unavailable.contains(_dateOnly(day.date));
                final daySessions = appState.daySessionsFor(day);
                return DayCard(
                  day: day,
                  unavailable: isUnavailable,
                  role: user.role,
                  offerableSessions: daySessions.offerableWindows,
                  liveDayRating: appState.liveDayRatingFor(day.date),
                  sessionsWithoutAWindow: daySessions.sessionsWithoutAWindow,
                  liveWeather: appState.liveWeatherFor(day.date),
                  liveWaterRelease: appState.liveWaterRelease,
                  liveDaylight: appState.liveDaylightFor(day.date),
                  onSendProposal: (highTide, meetingTime) {
                    appState.sendProposal(
                      day,
                      highTide,
                      meetingTime: meetingTime,
                    );
                    _snack(
                      context,
                      'Proposal sent \u2014 meet at '
                      '${formatTime(meetingTime)}.',
                    );
                  },
                  onMarkUnavailable: () {
                    appState.markCoachUnavailable(day);
                    _snack(context, "Marked unavailable — won't be proposed.");
                  },
                  onOpenSession: (session) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SessionDetailScreen(sessionId: session.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _Legend(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _LegendRow(Conditions.green, 'Good — any boat can go out.'),
            SizedBox(height: 8),
            _LegendRow(
              Conditions.amber,
              'Marginal — larger boats / experienced only.',
            ),
            SizedBox(height: 8),
            _LegendRow(Conditions.red, 'Not rowable (wind, rain, or release).'),
          ],
        ),
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(this.conditionRating, this.text);
  final Conditions conditionRating;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = switch (conditionRating) {
      Conditions.green => const Color(0xFF2E7D32),
      Conditions.amber => const Color(0xFFEF6C00),
      Conditions.red => const Color(0xFFC62828),
    };
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
      ],
    );
  }
}
