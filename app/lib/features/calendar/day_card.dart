import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/day_conditions.dart';
import '../../models/session.dart';
import '../../models/user_profile.dart';
import '../../services/tide_windows.dart';
import '../../shared/condition_style.dart';
import '../../shared/formatting.dart';

/// A calendar day as a flip card: the colour-coded front shows the rating; tap
/// to flip and reveal the metrics behind the call (plus the coach's actions).
class DayCard extends StatefulWidget {
  const DayCard({
    super.key,
    required this.day,
    required this.session,
    required this.unavailable,
    required this.role,
    required this.onSendProposal,
    required this.onMarkUnavailable,
    required this.onOpenSession,
    this.offerableHighTides,
  });

  final DayConditions day;
  final Session? session;

  /// Offerable high-tide sessions from live data (in daylight and at/above the
  /// height threshold). A day can have two. null = no live data (show mock);
  /// an empty list = live data but no rowable window that day.
  final List<LiveHighTide>? offerableHighTides;
  final bool unavailable;
  final UserRole role;
  final VoidCallback onSendProposal;
  final VoidCallback onMarkUnavailable;
  final VoidCallback onOpenSession;

  @override
  State<DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<DayCard> {
  bool _showBack = false;

  String _statusBadge() {
    final s = widget.session;
    if (s != null) {
      if (s.lifecycle == SessionLifecycle.cancelledWeatherPivot) {
        return 'Land training';
      }
      if (s.lifecycle == SessionLifecycle.cancelledOutright) return 'Cancelled';
      return s.status == SessionStatus.confirmed ? 'Confirmed' : 'Proposed';
    }
    if (widget.unavailable) return 'Unavailable';
    return widget.day.conditions == Conditions.red ? 'No row' : 'Available';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _showBack = !_showBack),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: _showBack ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 400),
        builder: (context, t, _) {
          final angle = t * math.pi;
          final isBack = t > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: isBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _back(context),
                  )
                : _front(context),
          );
        },
      ),
    );
  }

  Widget _shell({required Widget child}) => SizedBox(
        width: 180,
        height: 320,
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      );

  Widget _front(BuildContext context) {
    final style = conditionStyle(widget.day.conditions);
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: style.color,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Text(
                  formatWeekday(widget.day.date),
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                Text(
                  '${widget.day.date.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.shortLabel,
                    style: TextStyle(
                      color: style.color,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StatusBadge(text: _statusBadge()),
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.flip_to_back,
                          size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Tap for detail',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _back(BuildContext context) {
    final day = widget.day;
    return _shell(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${formatWeekday(day.date)} ${day.date.day} — conditions',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const Divider(height: 12),
            ..._highTideRows(day),
            _metric(Icons.air, 'Wind', '${day.windKnots.round()} kn'),
            _metric(Icons.water_drop, 'Rain', '${day.rainfallMm} mm'),
            _metric(
              Icons.dangerous,
              'Water release',
              day.waterReleaseActive ? 'YES — no row' : 'None',
              danger: day.waterReleaseActive,
            ),
            _metric(Icons.wb_sunny, 'Daylight',
                '${formatTime(day.sunrise)}–${formatTime(day.sunset)}'),
            const Spacer(),
            ..._actions(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    final hasSession = widget.session != null;
    if (hasSession) {
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonal(
            onPressed: widget.onOpenSession,
            child: const Text('Open session'),
          ),
        ),
      ];
    }
    if (widget.role == UserRole.coach) {
      if (widget.unavailable) {
        return [
          Text("You're marked unavailable",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ];
      }
      if (widget.day.conditions == Conditions.red) {
        return [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onMarkUnavailable,
              child: const Text('Mark unavailable'),
            ),
          ),
        ];
      }
      return [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: widget.onSendProposal,
            child: const Text('Send proposal'),
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: widget.onMarkUnavailable,
            child: const Text('Unavailable'),
          ),
        ),
      ];
    }
    // Athlete / parent with no session for the day: nothing to do here.
    return [
      Text(
        widget.unavailable ? 'No session — coach away' : 'No session proposed',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    ];
  }

  /// High-tide row(s): live offerable windows (one or two) when available,
  /// otherwise the mock high tide. A day with two qualifying highs shows two.
  List<Widget> _highTideRows(DayConditions day) {
    final offer = widget.offerableHighTides;
    if (offer == null) {
      return [
        _metric(Icons.waves, 'High tide',
            '${formatTime(day.highTide)} · ${day.highTideHeightMetres}m'),
      ];
    }
    if (offer.isEmpty) {
      return [
        _metric(Icons.waves, 'High tide',
            'none in daylight ≥${kMinRowableHighTideMetres}m'),
      ];
    }
    return [
      for (var i = 0; i < offer.length; i++)
        _metric(
          Icons.waves,
          offer.length > 1 ? 'High tide ${i + 1}' : 'High tide',
          '${formatTime(offer[i].time)} · '
              '${offer[i].heightMetres.toStringAsFixed(1)}m',
          live: true,
        ),
    ];
  }

  Widget _metric(IconData icon, String label, String value,
      {bool danger = false, bool live = false}) {
    const liveGreen = Color(0xFF2E7D32);
    final valueColor =
        live ? liveGreen : (danger ? const Color(0xFFC62828) : Colors.grey.shade800);
    final iconColor = danger ? const Color(0xFFC62828) : Colors.grey.shade800;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 6),
          if (live) ...[
            Tooltip(
              message: 'Live tide data',
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: liveGreen, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (text) {
      'Confirmed' => (const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
      'Proposed' => (const Color(0xFFE3F2FD), const Color(0xFF1565C0)),
      'Land training' => (const Color(0xFFFFF3E0), const Color(0xFFEF6C00)),
      'Cancelled' => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      'No row' => (const Color(0xFFFFEBEE), const Color(0xFFC62828)),
      'Unavailable' => (const Color(0xFFECEFF1), const Color(0xFF546E7A)),
      _ => (const Color(0xFFECEFF1), const Color(0xFF546E7A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}
