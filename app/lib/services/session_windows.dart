library;

import '../models/session.dart';
import 'tide_windows.dart';

typedef HighTideSession = ({LiveHighTide highTide, Session? session});

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
