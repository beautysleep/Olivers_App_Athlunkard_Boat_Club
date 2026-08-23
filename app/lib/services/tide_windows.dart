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

/// How far outside sunrise/sunset still counts as light enough to row, in
/// minutes. Rowing clubs often launch before dawn, but whether *this* club does
/// is unknown — so the default is 0 (strict sunrise..sunset) rather than a
/// guessed twilight allowance. Tunable, confirm with the coaches alongside the
/// other thresholds.
const kDaylightEdgeOffsetMinutes = 0;

/// The high tides that can be offered as sessions for a day.
///
/// A day usually has two high tides. Each one that is at/above
/// [minHeightMetres] AND falls within daylight is a separate offerable session
/// — so this can return two.
///
/// [daylightEdgeOffsetMinutes] widens the daylight window symmetrically, for a
/// club that launches before sunrise or lands after sunset.
List<LiveHighTide> offerableHighTides(
  List<LiveHighTide> highs, {
  required DateTime sunrise,
  required DateTime sunset,
  double minHeightMetres = kMinRowableHighTideMetres,
  int daylightEdgeOffsetMinutes = kDaylightEdgeOffsetMinutes,
}) {
  final edge = Duration(minutes: daylightEdgeOffsetMinutes);
  final firstLight = sunrise.subtract(edge);
  final lastLight = sunset.add(edge);
  return [
    for (final h in highs)
      if (h.heightMetres >= minHeightMetres &&
          !h.time.isBefore(firstLight) &&
          !h.time.isAfter(lastLight))
        h,
  ];
}
