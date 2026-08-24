/// Pure daylight logic: the app-facing model and the mapping from a stored
/// `weather_forecasts` day document to it. No Firestore/Flutter dependency, so
/// it is unit-testable directly (mirrors weather_conditions.dart).
///
/// Daylight rides on the weather documents because OpenWeather already returns
/// sunrise/sunset on its daily records — see functions/weather/README.md. It is
/// modelled separately from [LiveWeather] because it feeds a different
/// decision: which high tides are offerable, not how windy the day is.
library;

/// Live daylight bounds for one day, in local time.
class LiveDaylight {
  const LiveDaylight({required this.sunrise, required this.sunset});

  final DateTime sunrise;
  final DateTime sunset;
}

/// Builds [LiveDaylight] from a `weather_forecasts` day document, or null when
/// the day has no usable daylight — which is a real case, not a defensive one:
/// a day beyond OpenWeather's ~10-day horizon has no daily record, so the
/// backend writes both bounds as null.
///
/// The document's `sunrise`/`sunset` are expected as [DateTime]; the repository
/// converts Firestore Timestamps before calling, so this file stays free of any
/// Firestore dependency (same split as the tide service).
LiveDaylight? liveDaylightFromDocument(Map<String, dynamic>? doc) {
  if (doc == null) return null;
  final sunrise = doc['sunrise'] as DateTime?;
  final sunset = doc['sunset'] as DateTime?;
  if (sunrise == null || sunset == null) return null;
  return LiveDaylight(sunrise: sunrise.toLocal(), sunset: sunset.toLocal());
}
