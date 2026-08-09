/// Pure live-water-release logic: the app-facing model and the mapping from a
/// stored `water_release_status/current` Firestore document to it. No
/// Firestore/Flutter dependency, so it is unit-testable directly (mirrors
/// weather_conditions.dart).
library;

/// The only two classifications the backend fetcher can produce (see
/// `functions/water_release/models.py`) — the one Parteen Weir discharge
/// phrasing ESB has ever been observed to publish is [kNoDischargeExpected];
/// anything else, including a real "discharging" statement (never captured),
/// is [kUnparsed] — never guessed as either safe or dangerous.
const String kNoDischargeExpected = 'no_discharge_expected';
const String kUnparsed = 'unparsed';

/// Live water-release status, read from `water_release_status/current`.
class LiveWaterRelease {
  const LiveWaterRelease({
    required this.classification,
    required this.statementRaw,
  });

  final String classification; // kNoDischargeExpected | kUnparsed
  final String statementRaw;

  bool get isClear => classification == kNoDischargeExpected;
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
  );
}
