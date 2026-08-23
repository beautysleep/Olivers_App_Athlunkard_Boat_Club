/// Pure live-water-release logic: the app-facing model and the mapping from a
/// stored `water_release_status/current` Firestore document to it. No
/// Firestore/Flutter dependency, so it is unit-testable directly (mirrors
/// weather_conditions.dart).
library;

/// The three classifications the backend fetcher can produce (see
/// `functions/water_release/models.py`). [kNoDischargeExpected] and
/// [kDischargeExpected] each cover several real ESB phrasings; [kUnparsed] is
/// wording ESB has never been observed to use, and is never guessed as either
/// safe or dangerous.
const String kNoDischargeExpected = 'no_discharge_expected';
const String kDischargeExpected = 'discharge_expected';
const String kUnparsed = 'unparsed';

/// Live water-release status, read from `water_release_status/current`.
class LiveWaterRelease {
  const LiveWaterRelease({
    required this.classification,
    required this.statementRaw,
    this.expectedMinM3s,
    this.expectedMaxM3s,
  });

  // kNoDischargeExpected | kDischargeExpected | kUnparsed
  final String classification;
  final String statementRaw;

  /// The discharge range ESB expects, when discharging. ESB does not always
  /// state one in a form we can read, so this is absent even for some
  /// [kDischargeExpected] days — the classification alone decides the override.
  final double? expectedMinM3s;
  final double? expectedMaxM3s;

  bool get isClear => classification == kNoDischargeExpected;

  /// Water is being released upstream: the hard override, no rowing.
  bool get isDischarging => classification == kDischargeExpected;

  /// The range formatted for display ("55–170"), or null if ESB gave none.
  String? get expectedRangeM3s {
    final min = expectedMinM3s;
    final max = expectedMaxM3s;
    if (min == null || max == null) return null;
    return '${_trim(min)}–${_trim(max)}';
  }

  static String _trim(double value) =>
      value == value.roundToDouble() ? '${value.round()}' : '$value';
}

/// Builds [LiveWaterRelease] from the Firestore document, or null when
/// there's no usable classification (so the UI falls back to mock).
LiveWaterRelease? liveWaterReleaseFromDoc(Map<String, dynamic>? doc) {
  if (doc == null) return null;
  final forecast = (doc['parteen_forecast'] as Map?)?.cast<String, dynamic>();
  if (forecast == null) return null;
  final classification = forecast['discharge_classification'] as String?;
  if (classification == null) return null;
  return LiveWaterRelease(
    classification: classification,
    statementRaw: (forecast['discharge_statement_raw'] as String?) ?? '',
    expectedMinM3s: (forecast['expected_discharge_min_m3s'] as num?)?.toDouble(),
    expectedMaxM3s: (forecast['expected_discharge_max_m3s'] as num?)?.toDouble(),
  );
}
