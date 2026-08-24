library;

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
          .where((session) => session.date == highTide.time)
          .firstOrNull,
    ),
];

/// Sessions the coach has already proposed that no offerable window matches —
/// because the forecast has shifted since, or the day has slipped past the tide
/// horizon and offers no windows at all. The session and its commitments are
/// real either way, so it stays on the card.
List<Session> sessionsWithoutAHighTide(
  List<LiveHighTide> offerableHighTides,
  List<Session> sessionsThatDay,
) => [
  for (final session in sessionsThatDay)
    if (!offerableHighTides.any((highTide) => highTide.time == session.date))
      session,
];
