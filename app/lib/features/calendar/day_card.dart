import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/day_conditions.dart';
import '../../models/session.dart';
import '../../models/user_profile.dart';
import '../../services/tide_windows.dart';
import '../../services/water_release_conditions.dart';
import '../../services/weather_conditions.dart';
import '../../shared/condition_style.dart';
import '../../shared/formatting.dart';

/// 1 knot = 1.852 km/h — for showing mock wind (stored in knots) in km/h, the
/// unit the live data and the row/no-row thresholds use.
const double _knotsToKmh = 1.852;

/// A metric row's visual treatment. [unknown] is distinct from [danger]: it
/// means live data arrived but couldn't be classified (e.g. the water-release
/// PDF's discharge sentence didn't match the one phrasing ever observed) — a
/// real gap to flag, not a confirmed override, so it must not read the same
/// as [danger].
enum MetricStatus { normal, live, danger, unknown }

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
    this.liveWeather,
    this.liveWaterRelease,
  });

  final DayConditions day;
  final Session? session;

  /// Offerable high-tide sessions from live data (in daylight and at/above the
  /// height threshold). A day can have two. null = no live data (show mock);
  /// an empty list = live data but no rowable window that day.
  final List<LiveHighTide>? offerableHighTides;

  /// Live daily weather (km/h wind, mm rain) for this day, or null → show mock.
  final LiveWeather? liveWeather;

  /// Live water-release status (global, not per-day), or null → show mock.
  final LiveWaterRelease? liveWaterRelease;
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

  /// 300 logical px on a ~360px-wide phone deliberately shows about 1.2 cards
  /// at a time. Fitting two cards meant every live value ellipsised away, and
  /// while the club is still learning to trust the automated call, showing the
  /// evidence in full matters more than showing more days at once.
  Widget _shell({required Widget child}) => SizedBox(
    width: 300,
    height: 320,
    child: Card(clipBehavior: Clip.antiAlias, child: child),
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
                      Icon(
                        Icons.flip_to_back,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Tap for detail',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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
      child: SingleChildScrollView(
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
            _windRow(day),
            _rainRow(day),
            _waterReleaseRow(day),
            _metric(
              Icons.wb_sunny,
              'Daylight',
              '${formatTime(day.sunrise)}–${formatTime(day.sunset)}',
            ),
            const SizedBox(height: 16),
            ..._actions(context),
            ..._additionalInformation(),
          ],
        ),
      ),
    );
  }

  /// Sources behind the numbers above, placed below the actions so it never
  /// competes with them — the coach scrolls to it only when they want to check.
  /// Shows ESB's own sentence verbatim plus a link to the document it came
  /// from: a new user's first question is "where did that come from?", and
  /// they should be able to go and look rather than take the app's word.
  List<Widget> _additionalInformation() {
    final w = widget.liveWaterRelease;
    if (w == null) return const [];
    return [
      const SizedBox(height: 20),
      const Divider(height: 1),
      const SizedBox(height: 10),
      Text(
        'Additional information',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade700,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Water release',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
        ),
      ),
      if (w.statementRaw.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(
          '“${w.statementRaw}”',
          style: TextStyle(
            fontSize: 11,
            height: 1.35,
            fontStyle: FontStyle.italic,
            color: Colors.grey.shade800,
          ),
        ),
      ],
      const SizedBox(height: 6),
      _sourceLink('ESB Shannon Hydro Forecast (PDF)', w.sourceUrl),
    ];
  }

  /// A source as a tappable link. Opens in the external browser rather than an
  /// in-app view: esbhydro.ie is plain HTTP with no HTTPS listener, which
  /// Android's default cleartext policy blocks in a webview.
  Widget _sourceLink(String label, String? url) {
    if (url == null) {
      return Text(
        label,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      );
    }
    return InkWell(
      onTap: () => _openSource(url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.open_in_new, size: 13, color: Color(0xFF1565C0)),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF1565C0),
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF1565C0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSource(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
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
          Text(
            "You're marked unavailable",
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
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
        _metric(
          Icons.waves,
          'High tide',
          '${formatTime(day.highTide)} · ${day.highTideHeightMetres}m',
        ),
      ];
    }
    if (offer.isEmpty) {
      return [
        _metric(
          Icons.waves,
          'High tide',
          'none in daylight ≥${kMinRowableHighTideMetres}m',
        ),
      ];
    }
    return [
      for (var i = 0; i < offer.length; i++)
        _metric(
          Icons.waves,
          offer.length > 1 ? 'High tide ${i + 1}' : 'High tide',
          '${formatTime(offer[i].time)} · '
          '${offer[i].heightMetres.toStringAsFixed(1)}m',
          status: MetricStatus.live,
        ),
    ];
  }

  /// Wind in km/h — live when available (green dot), else the mock value
  /// converted from knots. km/h matches the row/no-row wind thresholds.
  Widget _windRow(DayConditions day) {
    final w = widget.liveWeather;
    if (w == null) {
      return _metric(
        Icons.air,
        'Wind',
        '${(day.windKnots * _knotsToKmh).round()} km/h',
      );
    }
    return _metric(
      Icons.air,
      'Wind',
      '${w.windKmh.round()} km/h',
      status: MetricStatus.live,
    );
  }

  /// Rainfall in mm — live when available (green dot), else the mock value.
  Widget _rainRow(DayConditions day) {
    final w = widget.liveWeather;
    if (w == null) {
      return _metric(Icons.water_drop, 'Rain', '${day.rainfallMm} mm');
    }
    return _metric(
      Icons.water_drop,
      'Rain',
      '${w.rainMm.toStringAsFixed(1)} mm',
      status: MetricStatus.live,
    );
  }

  /// Water release (ESB Parteen Weir) — live when available: red when ESB
  /// expects a discharge (the hard override), green when it expects none,
  /// amber when the wording matched neither and so was never guessed either
  /// way (see functions/water_release/README.md). The wording itself lives on
  /// LiveWaterRelease.summaryLabel. Otherwise the mock override.
  Widget _waterReleaseRow(DayConditions day) {
    final w = widget.liveWaterRelease;
    if (w == null) {
      return _metric(
        Icons.dangerous,
        'Water release',
        day.waterReleaseActive ? 'YES — no row' : 'None',
        status: day.waterReleaseActive
            ? MetricStatus.danger
            : MetricStatus.normal,
      );
    }
    return _metric(
      Icons.dangerous,
      'Water release',
      w.summaryLabel,
      status: switch (w) {
        _ when w.isDischarging => MetricStatus.danger,
        _ when w.isClear => MetricStatus.live,
        _ => MetricStatus.unknown,
      },
    );
  }

  Widget _metric(
    IconData icon,
    String label,
    String value, {
    MetricStatus status = MetricStatus.normal,
  }) {
    const liveGreen = Color(0xFF2E7D32);
    const dangerRed = Color(0xFFC62828);
    const unknownAmber = Color(0xFFEF6C00);
    final valueColor = switch (status) {
      MetricStatus.live => liveGreen,
      MetricStatus.danger => dangerRed,
      MetricStatus.unknown => unknownAmber,
      MetricStatus.normal => Colors.grey.shade800,
    };
    final iconColor = status == MetricStatus.danger
        ? dangerRed
        : Colors.grey.shade800;
    final showDot =
        status == MetricStatus.live || status == MetricStatus.unknown;
    final dotColor = status == MetricStatus.live ? liveGreen : unknownAmber;
    final dotMessage = status == MetricStatus.live
        ? 'Live data'
        : 'Live data — unparsed, check ESB';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          // Loose fit, and a smaller share than the value: the label is a
          // fixed short word but the value carries live data that must not be
          // ellipsised away (a truncated "No row · 55–170 m³/s" loses the
          // number entirely). Expanded here would tightly claim half the row.
          Flexible(
            flex: 2,
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          if (showDot) ...[
            Tooltip(
              message: dotMessage,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
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
