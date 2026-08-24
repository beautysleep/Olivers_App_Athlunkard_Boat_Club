/// Still mock data — the decision engine is what will fill these in. The live
/// tide, weather, daylight and water-release readings reach the UI by their own
/// routes, not through here.
library;

import 'session.dart';

class DayConditions {
  const DayConditions({
    required this.date,
    required this.conditionRating,
    required this.highTideTime,
    required this.highTideHeightMetres,
    required this.windKnots,
    required this.rainfallMm,
    required this.waterReleaseActive,
    required this.localSunrise,
    required this.localSunset,
  });

  final DateTime date;
  final Conditions conditionRating;
  final DateTime highTideTime;
  final double highTideHeightMetres;
  final double windKnots;
  final double rainfallMm;

  /// ESB's Parteen Weir release: true means no rowing whatever the rest says.
  final bool waterReleaseActive;

  final DateTime localSunrise;
  final DateTime localSunset;
}
