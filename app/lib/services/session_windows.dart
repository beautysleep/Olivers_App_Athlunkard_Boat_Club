import '../models/session.dart';
import 'tide_windows.dart';

typedef HighTideSession = ({LiveHighTide highTide, Session? session});

typedef DaySessions = ({
  List<HighTideSession>? offerableWindows,
  List<Session> sessionsWithoutAWindow,
});

List<HighTideSession> sessionsByHighTide(
  List<LiveHighTide> offerableHighTides,
  List<Session> sessionsThatDay,
) => [
  for (final highTide in offerableHighTides)
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
  List<LiveHighTide> offerableHighTides,
  List<Session> sessionsThatDay,
) => [
  for (final session in sessionsThatDay)
    if (!offerableHighTides.any(
      (highTide) => highTide.localTime == session.highTideTime,
    ))
      session,
];
