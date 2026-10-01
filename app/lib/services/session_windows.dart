import '../models/session.dart';
import 'day_ratings.dart';
import 'tide_windows.dart';

typedef HighTideSession = ({LiveHighTide highTide, Session? session});

typedef DaySessions = ({
  List<HighTideSession>? offerableWindows,
  List<Session> sessionsWithoutAWindow,
});

List<HighTideSession> sessionsByHighTide(
  List<LiveHighTide> highs,
  List<Session> sessionsThatDay,
) => [
  for (final highTide in highs)
    (
      highTide: highTide,
      session: sessionsThatDay
          .where((session) => session.highTideTime == highTide.localTime)
          .firstOrNull,
    ),
];

/// A window can stop being offered — the forecast shifts, or the day slips past
/// the tide horizon — while the session proposed for it, and the commitments
/// made to it, stay real.
List<Session> sessionsWithoutAHighTide(
  List<LiveHighTide> highs,
  List<Session> sessionsThatDay,
) => [
  for (final session in sessionsThatDay)
    if (!highs.any((high) => high.localTime == session.highTideTime))
      session,
];

/// Which of today's high tides are offerable, keyed on the engine's verdict
/// rather than the app re-deciding against its own threshold.
///
/// A tide is offered iff the engine kept a depth window for it (every entry
/// does, after Step 2); a missing rating means "no data", not "fall back to a
/// local filter" — the proxy that approach would reintroduce is exactly what
/// the engine's time-at-depth rule replaced.
DaySessions daySessionsFromRating({
  required List<LiveHighTide> highs,
  required LiveDayRating? rating,
  required List<Session> sessionsThatDay,
}) {
  if (highs.isEmpty || rating == null) {
    return (offerableWindows: null, sessionsWithoutAWindow: sessionsThatDay);
  }
  final offerable = [
    for (final high in highs)
      if (rating.forHighTide(high.localTime)?.hasTideWindow ?? false) high,
  ];
  return (
    offerableWindows: sessionsByHighTide(offerable, sessionsThatDay),
    sessionsWithoutAWindow: sessionsWithoutAHighTide(offerable, sessionsThatDay),
  );
}
