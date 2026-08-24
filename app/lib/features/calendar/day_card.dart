import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/day_conditions.dart';
import '../../models/session.dart';
import '../../models/user_profile.dart';
import '../../services/daylight_conditions.dart';
import '../../services/session_windows.dart';
import '../../services/tide_windows.dart';
import '../../services/water_release_conditions.dart';
import '../../services/weather_conditions.dart';
import '../../shared/condition_style.dart';
import '../../shared/formatting.dart';

/// A metric row's visual treatment.
///
/// [unknown] is distinct from [danger]: it means live data arrived but couldn't
/// be classified (e.g. the water-release PDF's discharge sentence didn't match
/// any phrasing ever observed) — a real gap to flag, not a confirmed override.
///
/// [missing] means no live data reached us at all. It is deliberately NOT a
/// fallback to mock values: a plausible-looking number the coach cannot tell
/// apart from a real reading destroys trust in every other number on the card.
enum MetricStatus { normal, live, danger, unknown, missing }

/// A calendar day as a flip card: the colour-coded front shows the rating; tap
/// to flip and reveal the metrics behind the call (plus the coach's actions).
class DayCard extends StatefulWidget {
  const DayCard({
    super.key,
    required this.day,
    required this.unavailable,
    required this.role,
    required this.onSendProposal,
    required this.onMarkUnavailable,
    required this.onOpenSession,
    this.offerableSessions,
    this.liveWeather,
    this.liveWaterRelease,
    this.liveDaylight,
  });

  final DayConditions day;

  /// Each rowable window for the day (in daylight, at/above the height
  /// threshold) with whatever session has been proposed for it. A day can have
  /// two, each committable on its own. null = no live tide or daylight data;
  /// an empty list = live data but no rowable window that day. Either way there
  /// is no window to offer, so no proposal is possible.
  final List<HighTideSession>? offerableSessions;

  /// Live daily weather (km/h wind, mm rain) for this day, or null → show mock.
  final LiveWeather? liveWeather;

  /// Live water-release status (global, not per-day), or null → "No data".
  final LiveWaterRelease? liveWaterRelease;

  /// Live daylight bounds for this day, or null → "No data".
  final LiveDaylight? liveDaylight;
  final bool unavailable;
  final UserRole role;
  final void Function(LiveHighTide highTide) onSendProposal;
  final VoidCallback onMarkUnavailable;
  final void Function(Session session) onOpenSession;

  @override
  State<DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<DayCard> {
  bool _showBack = false;

  List<HighTideSession> get _windows =>
      widget.offerableSessions ?? const <HighTideSession>[];

  List<Session> get _proposedSessions =>
      [for (final window in _windows) ?window.session];

  String _statusBadge() {
    final sessions = _proposedSessions;
    if (sessions.any((s) => s.status == SessionStatus.confirmed)) {
      return 'Confirmed';
    }
    if (sessions.any((s) => !s.isCancelled)) return 'Proposed';
    if (sessions.any(
      (s) => s.lifecycle == SessionLifecycle.cancelledWeatherPivot,
    )) {
      return 'Land training';
    }
    if (sessions.isNotEmpty) return 'Cancelled';
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
            ..._highTideRows(),
            _windRow(),
            _rainRow(),
            _waterReleaseRow(),
            _daylightRow(),
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
    final windows = _windows;
    final nameWindowsByTime = windows.length > 1;

    final actions = <Widget>[
      for (final window in windows) ?_windowAction(window, nameWindowsByTime),
    ];
    final dayAction = _dayAction(nothingOfferedForAWindow: actions.isEmpty);
    if (dayAction != null) actions.add(dayAction);

    return [
      for (var i = 0; i < actions.length; i++) ...[
        if (i > 0) const SizedBox(height: 6),
        actions[i],
      ],
    ];
  }

  /// The action for one rowable window: open the session proposed for it, or —
  /// for a coach on a day they can still row — propose one. Null when there is
  /// nothing this viewer can do with the window.
  Widget? _windowAction(HighTideSession window, bool nameWindowsByTime) {
    final time = formatTime(window.highTide.time);
    final session = window.session;
    if (session != null) {
      return _fullWidth(
        FilledButton.tonal(
          onPressed: () => widget.onOpenSession(session),
          child: Text(nameWindowsByTime ? 'Open $time session' : 'Open session'),
        ),
      );
    }
    if (widget.role != UserRole.coach ||
        widget.unavailable ||
        widget.day.conditions == Conditions.red) {
      return null;
    }
    return _fullWidth(
      FilledButton(
        onPressed: () => widget.onSendProposal(window.highTide),
        child: Text(nameWindowsByTime ? 'Propose $time' : 'Send proposal'),
      ),
    );
  }

  /// The action that belongs to the whole day rather than to a window. The
  /// coach's own availability is one of these: it holds even on a day with no
  /// rowable window at all, which is why it does not sit behind one.
  Widget? _dayAction({required bool nothingOfferedForAWindow}) {
    if (widget.role != UserRole.coach) {
      if (!nothingOfferedForAWindow) return null;
      return _note(
        widget.unavailable ? 'No session — coach away' : 'No session proposed',
      );
    }
    if (widget.unavailable) return _note("You're marked unavailable");
    if (_proposedSessions.isNotEmpty) return null;
    return _fullWidth(
      OutlinedButton(
        onPressed: widget.onMarkUnavailable,
        child: const Text('Mark unavailable'),
      ),
    );
  }

  Widget _fullWidth(Widget child) =>
      SizedBox(width: double.infinity, child: child);

  Widget _note(String text) => Text(
    text,
    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
  );

  List<Widget> _highTideRows() {
    final windows = widget.offerableSessions;
    if (windows == null) {
      return [_missing(Icons.waves, 'High tide')];
    }
    if (windows.isEmpty) {
      return [
        _metric(
          Icons.waves,
          'High tide',
          'none in daylight ≥${kMinRowableHighTideMetres}m',
          status: MetricStatus.live,
        ),
      ];
    }
    return [
      for (var i = 0; i < windows.length; i++)
        _metric(
          Icons.waves,
          windows.length > 1 ? 'High tide ${i + 1}' : 'High tide',
          '${formatTime(windows[i].highTide.time)} · '
          '${windows[i].highTide.heightMetres.toStringAsFixed(1)}m',
          status: MetricStatus.live,
        ),
    ];
  }

  /// Wind in km/h — live when available (green dot), else the mock value
  /// converted from knots. km/h matches the row/no-row wind thresholds.
  Widget _windRow() {
    final w = widget.liveWeather;
    if (w == null) return _missing(Icons.air, 'Wind');
    return _metric(
      Icons.air,
      'Wind',
      '${w.windKmh.round()} km/h',
      status: MetricStatus.live,
    );
  }

  /// Rainfall in mm — live when available (green dot), else the mock value.
  Widget _rainRow() {
    final w = widget.liveWeather;
    if (w == null) return _missing(Icons.water_drop, 'Rain');
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
  Widget _waterReleaseRow() {
    final w = widget.liveWaterRelease;
    if (w == null) return _missing(Icons.dangerous, 'Water release');
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

  /// A metric with no live data behind it. Says so, rather than showing a mock
  /// value that reads as real.
  Widget _missing(IconData icon, String label) =>
      _metric(icon, label, 'No data', status: MetricStatus.missing);

  /// Daylight bounds — live from the weather forecast (OpenWeather returns
  /// sunrise/sunset on its daily records), or "No data" beyond its horizon.
  Widget _daylightRow() {
    final d = widget.liveDaylight;
    if (d == null) return _missing(Icons.wb_sunny, 'Daylight');
    return _metric(
      Icons.wb_sunny,
      'Daylight',
      '${formatTime(d.sunrise)}–${formatTime(d.sunset)}',
      status: MetricStatus.live,
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
      MetricStatus.missing => Colors.grey.shade500,
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
