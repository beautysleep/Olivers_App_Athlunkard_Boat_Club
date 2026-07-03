/// Pure tide-window logic: which high tides can be offered as rowing sessions.
///
/// No Firestore/Flutter dependency, so it is unit-testable directly.
library;

/// A predicted high-water event, in local time.
class LiveHighTide {
  const LiveHighTide({required this.time, required this.heightMetres});
  final DateTime time;
  final double heightMetres;
}

/// Minimum high-water height (metres) for a rowable window. The coach's field
/// threshold — tunable, refine with the coaches; not a hard-coded guess.
const kMinRowableHighTideMetres = 4.2;

/// The high tides that can be offered as sessions for a day.
///
/// A day usually has two high tides. Each one that is at/above
/// [minHeightMetres] AND falls within daylight (sunrise..sunset) is a separate
/// offerable session — so this can return two.
///
/// Daylight currently uses the day's mock sunrise/sunset until a live
/// sunrise/sunset source exists.
List<LiveHighTide> offerableHighTides(
  List<LiveHighTide> highs, {
  required DateTime sunrise,
  required DateTime sunset,
  double minHeightMetres = kMinRowableHighTideMetres,
}) {
  return [
    for (final h in highs)
      if (h.heightMetres >= minHeightMetres &&
          !h.time.isBefore(sunrise) &&
          !h.time.isAfter(sunset))
        h,
  ];
}
