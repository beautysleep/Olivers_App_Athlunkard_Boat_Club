import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/day_conditions.dart';
import '../../models/session.dart';
import '../../models/user_profile.dart';
import '../../services/day_ratings.dart';
import '../../services/daylight_conditions.dart';
import '../../services/meeting_times.dart';
import '../../services/session_windows.dart';
import '../../services/tide_windows.dart';
import '../../services/water_release_conditions.dart';
import '../../services/weather_conditions.dart';
import '../../shared/condition_style.dart';
import '../../shared/formatting.dart';

/// [unknown] is live data that could not be classified; [missing] is no live
/// data at all. Neither ever falls back to a mock value: a plausible-looking
/// number the coach cannot tell from a real reading discredits every other
/// number on the card.
enum MetricStatus { normal, live, danger, unknown, missing }

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
    this.liveDayRating,
    this.sessionsWithoutAWindow = const [],
    this.liveWeather,
    this.liveWaterRelease,
    this.liveDaylight,
  });

  final DayConditions day;

  /// Null means no live tide or daylight data; empty means live data but
  /// nothing rowable. Either way there is no window, so nothing to propose.
  final List<HighTideSession>? offerableSessions;

  /// The decision engine's verdict. Null, or carrying a null rating, means the
  /// engine has not reached this day — which the card says, rather than falling
  /// back to [DayConditions.conditionRating], the last mock on it.
  final LiveDayRating? liveDayRating;

  /// Their commitments are real even though that time can no longer be offered
  /// as a fresh proposal, so the card still shows them.
  final List<Session> sessionsWithoutAWindow;

  final LiveWeather? liveWeather;
  final LiveWaterRelease? liveWaterRelease;
  final LiveDaylight? liveDaylight;
  final bool unavailable;
  final UserRole role;
  final void Function(LiveHighTide highTide, DateTime meetingTime)
  onSendProposal;
  final VoidCallback onMarkUnavailable;
  final void Function(Session session) onOpenSession;

  @override
  State<DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<DayCard> {
  bool _showBack = false;

  List<HighTideSession> get _windows =>
      widget.offerableSessions ?? const <HighTideSession>[];

  List<Session> get _proposedSessions => [
    for (final window in _windows) ?window.session,
    ...widget.sessionsWithoutAWindow,
  ];

  String? _statusBadge() {
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
    if (_rating == null) return null;
    return _rating == Conditions.red ? 'No row' : 'Available';
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

  /// 300px shows about 1.2 cards on a ~360px phone. Fitting two ellipsised
  /// every live value away, and while the club is still learning to trust the
  /// automated call, the evidence matters more than the extra day.
  Widget _shell({required Widget child}) => SizedBox(
    width: 300,
    height: 320,
    child: Card(clipBehavior: Clip.antiAlias, child: child),
  );

  Conditions? get _rating => widget.liveDayRating?.conditions;

  Widget _front(BuildContext context) {
    final rating = _rating;
    final style = rating == null ? null : conditionStyle(rating);
    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: style?.color ?? Colors.grey.shade500,
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
                    style?.shortLabel ?? 'Not rated yet',
                    style: TextStyle(
                      color: style?.color ?? Colors.grey.shade600,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ?switch (_statusBadge()) {
                    final badge? => _StatusBadge(text: badge),
                    _ => null,
                  },
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

  /// Below the actions so it never competes with them. ESB's own sentence runs
  /// verbatim next to a link to the document: the first question a new user
  /// asks is "where did that come from?", and they should be able to go and
  /// look rather than take the app's word.
  List<Widget> _additionalInformation() {
    final w = widget.liveWaterRelease;
    final reasons = widget.liveDayRating?.reasons ?? const <String>[];
    if (w == null && reasons.isEmpty) return const [];
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
      for (final reason in reasons) ...[
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            reason,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: Colors.grey.shade800,
            ),
          ),
        ),
      ],
      if (w != null) ...[
        Text(
          'Water release',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        ),
      ],
      if (w != null && w.statementRaw.isNotEmpty) ...[
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
      if (w != null) ...[
        const SizedBox(height: 6),
        _sourceLink('ESB Shannon Hydro Forecast (PDF)', w.sourceUrl),
      ],
    ];
  }

  /// External browser, not a webview: esbhydro.ie is plain HTTP with no HTTPS
  /// listener, which Android's default cleartext policy blocks.
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }

  List<Widget> _actions(BuildContext context) {
    final windows = _windows;
    final stranded = widget.sessionsWithoutAWindow;
    final nameWindowsByTime = windows.length + stranded.length > 1;

    final actions = <Widget>[
      for (final window in windows) ?_windowAction(window, nameWindowsByTime),
      for (final session in stranded) _openSession(session, nameWindowsByTime),
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

  /// Null when there is nothing this viewer can do with the window.
  Widget? _windowAction(HighTideSession window, bool nameWindowsByTime) {
    final time = formatTime(window.highTide.localTime);
    final session = window.session;
    if (session != null) return _openSession(session, nameWindowsByTime);
    if (widget.role != UserRole.coach ||
        widget.unavailable ||
        _rating == Conditions.red) {
      return null;
    }

    // The engine rates each tide separately, so a windy morning does not have
    // to take a calm evening down with it.
    final verdict = widget.liveDayRating?.forHighTide(
      window.highTide.localTime,
    );
    if (verdict != null && verdict.conditions == Conditions.red) {
      return _ruledOutWindow(time, verdict);
    }
    return _fullWidth(
      FilledButton(
        onPressed: () => _chooseMeetingTime(window.highTide),
        child: Text(
          nameWindowsByTime ? 'Propose \u00b7 $time tide' : 'Send proposal',
        ),
      ),
    );
  }

  Future<void> _chooseMeetingTime(LiveHighTide highTide) async {
    final chosen = await showModalBottomSheet<DateTime>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text(
                'Meet at',
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                'High tide ${formatTime(highTide.localTime)} \u00b7 '
                'earlier means a longer session',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ),
            for (final meetingTime in meetingTimesBefore(highTide.localTime))
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text(formatTime(meetingTime)),
                onTap: () => Navigator.of(sheetContext).pop(meetingTime),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) widget.onSendProposal(highTide, chosen);
  }

  Widget _ruledOutWindow(String time, LiveWindowRating verdict) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$time tide — not rowable',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: conditionStyle(Conditions.red).color,
          ),
        ),
        for (final reason in verdict.reasons)
          Text(
            reason,
            style: TextStyle(
              fontSize: 11,
              height: 1.3,
              color: Colors.grey.shade700,
            ),
          ),
      ],
    ),
  );

  Widget _openSession(Session session, bool nameWindowsByTime) => _fullWidth(
    FilledButton.tonal(
      onPressed: () => widget.onOpenSession(session),
      child: Text(
        nameWindowsByTime
            ? 'Open ${formatTime(session.meetingTime)} session'
            : 'Open session',
      ),
    ),
  );

  /// The coach's own availability holds even on a day with no rowable window,
  /// which is why it does not sit behind one.
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

  Widget _note(String text) =>
      Text(text, style: TextStyle(fontSize: 12, color: Colors.grey.shade600));

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
          'none in daylight ≥${kMinimumRowableHighTideMetres}m',
          status: MetricStatus.live,
        ),
      ];
    }
    return [
      for (var i = 0; i < windows.length; i++)
        _metric(
          Icons.waves,
          windows.length > 1 ? 'High tide ${i + 1}' : 'High tide',
          '${formatTime(windows[i].highTide.localTime)} · '
          '${windows[i].highTide.heightMetres.toStringAsFixed(1)}m',
          status: MetricStatus.live,
        ),
    ];
  }

  Widget _windRow() {
    final weather = widget.liveWeather;
    if (weather == null) return _missing(Icons.air, 'Wind');
    return _metric(
      Icons.air,
      'Wind',
      '${weather.windKmh.round()} km/h',
      status: MetricStatus.live,
    );
  }

  Widget _rainRow() {
    final weather = widget.liveWeather;
    if (weather == null) return _missing(Icons.water_drop, 'Rain');
    return _metric(
      Icons.water_drop,
      'Rain',
      '${weather.rainMm.toStringAsFixed(1)} mm',
      status: MetricStatus.live,
    );
  }

  /// Amber is the case where ESB's wording matched no phrasing we have ever
  /// observed, so it was never guessed either way — see
  /// functions/water_release/README.md.
  Widget _waterReleaseRow() {
    final waterRelease = widget.liveWaterRelease;
    if (waterRelease == null) return _missing(Icons.dangerous, 'Water release');
    return _metric(
      Icons.dangerous,
      'Water release',
      waterRelease.summaryLabel,
      status: switch (waterRelease) {
        _ when waterRelease.isDischarging => MetricStatus.danger,
        _ when waterRelease.isClear => MetricStatus.live,
        _ => MetricStatus.unknown,
      },
    );
  }

  Widget _missing(IconData icon, String label) =>
      _metric(icon, label, 'No data', status: MetricStatus.missing);

  Widget _daylightRow() {
    final daylight = widget.liveDaylight;
    if (daylight == null) return _missing(Icons.wb_sunny, 'Daylight');
    return _metric(
      Icons.wb_sunny,
      'Daylight',
      '${formatTime(daylight.localSunrise)}–'
          '${formatTime(daylight.localSunset)}',
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
          // A smaller share than the value, and loose: the label is a fixed
          // short word, while the value carries live data that must not be
          // ellipsised (a truncated "No row · 55–170 m³/s" loses the number).
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
