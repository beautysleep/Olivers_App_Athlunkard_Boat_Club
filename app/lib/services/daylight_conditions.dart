/// Daylight rides on the weather documents because OpenWeather returns
/// sunrise/sunset on its daily records — see functions/weather/README.md.
library;

class LiveDaylight {
  const LiveDaylight({required this.localSunrise, required this.localSunset});

  final DateTime localSunrise;
  final DateTime localSunset;
}

/// Null is a real case, not a defensive one: a day beyond OpenWeather's ~10-day
/// horizon has no daily record, so the backend writes both bounds as null.
LiveDaylight? liveDaylightFromDocument(Map<String, dynamic>? document) {
  if (document == null) return null;
  final sunrise = document['sunrise'] as DateTime?;
  final sunset = document['sunset'] as DateTime?;
  if (sunrise == null || sunset == null) return null;
  return LiveDaylight(
    localSunrise: sunrise.toLocal(),
    localSunset: sunset.toLocal(),
  );
}
