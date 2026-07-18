/// Pure live-weather logic: the app-facing weather model and the mapping from a
/// stored Firestore `daily` record to it. No Firestore/Flutter dependency, so it
/// is unit-testable directly (mirrors tide_windows.dart).
library;

/// Live weather for one day, in the units the app displays: wind and gust in
/// **km/h**, rain in mm. Firestore stores wind in m/s (provider-native SI); we
/// convert on the way in so the UI and the row/no-row wind thresholds share one
/// unit.
class LiveWeather {
  const LiveWeather({
    required this.windKmh,
    required this.rainMm,
    this.gustKmh,
  });

  final double windKmh;
  final double? gustKmh;
  final double rainMm;
}

/// metres/second (stored, provider-native SI) → kilometres/hour (displayed).
double kmhFromMetresPerSecond(double metresPerSecond) => metresPerSecond * 3.6;

/// Builds [LiveWeather] from a Firestore `daily` map, or null when there's no
/// usable wind reading. Gust may be absent (One Call 4.0 daily omits it → null);
/// rain is absent on dry days → 0.
LiveWeather? liveWeatherFromDaily(Map<String, dynamic>? daily) {
  if (daily == null) return null;
  final windMs = (daily['wind_speed_ms'] as num?)?.toDouble();
  if (windMs == null) return null;
  final gustMs = (daily['wind_gust_ms'] as num?)?.toDouble();
  return LiveWeather(
    windKmh: kmhFromMetresPerSecond(windMs),
    gustKmh: gustMs == null ? null : kmhFromMetresPerSecond(gustMs),
    rainMm: (daily['rain_mm'] as num?)?.toDouble() ?? 0.0,
  );
}
