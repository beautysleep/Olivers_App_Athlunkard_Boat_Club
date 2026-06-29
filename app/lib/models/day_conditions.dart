/// The conditions for one upcoming day — the data behind the calendar's
/// green / amber / red rating, and behind the flip-card detail.
///
/// In v1 these are mock values. Later they are filled by the scheduled
/// condition-check services (tide, wind, rainfall, water release, daylight).
library;

import 'session.dart';

class DayConditions {
  const DayConditions({
    required this.date,
    required this.conditions,
    required this.highTide,
    required this.highTideHeightMetres,
    required this.windKnots,
    required this.rainfallMm,
    required this.waterReleaseActive,
    required this.sunrise,
    required this.sunset,
  });

  final DateTime date;

  /// The overall traffic-light rating for the day.
  final Conditions conditions;

  /// High-tide time — the key piece of information: it tells the coach *when*
  /// rowing would be possible that day.
  final DateTime highTide;
  final double highTideHeightMetres;

  final double windKnots;
  final double rainfallMm;

  /// Hard override: ESB Parteen Weir water release. When true, no rowing
  /// regardless of the other metrics (the deciding upstream signal).
  final bool waterReleaseActive;

  /// Daylight bounds — must be light enough to row; sunrise/sunset bound every
  /// possible window.
  final DateTime sunrise;
  final DateTime sunset;
}
