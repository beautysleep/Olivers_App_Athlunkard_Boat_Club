class LiveHighTide {
  const LiveHighTide({required this.localTime, required this.heightMetres});
  final DateTime localTime;
  final double heightMetres;
}

/// Provisional. Settle with the coaches rather than refining the guess.
const kMinimumRowableHighTideMetres = 4.2;

/// Zero means strict sunrise..sunset. Rowing clubs often launch before dawn,
/// but whether *this* one does is unknown, so it is not guessed at.
const kDaylightEdgeOffsetMinutes = 0;

List<LiveHighTide> offerableHighTides(
  List<LiveHighTide> highs, {
  required DateTime sunrise,
  required DateTime sunset,
  double minimumHeightMetres = kMinimumRowableHighTideMetres,
  int daylightEdgeOffsetMinutes = kDaylightEdgeOffsetMinutes,
}) {
  final edge = Duration(minutes: daylightEdgeOffsetMinutes);
  final firstLight = sunrise.subtract(edge);
  final lastLight = sunset.add(edge);
  return [
    for (final high in highs)
      if (high.heightMetres >= minimumHeightMetres &&
          !high.localTime.isBefore(firstLight) &&
          !high.localTime.isAfter(lastLight))
        high,
  ];
}
