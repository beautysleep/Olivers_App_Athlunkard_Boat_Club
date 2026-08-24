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

double kmhFromMetresPerSecond(double metresPerSecond) => metresPerSecond * 3.6;

/// One Call 4.0 omits gust on daily records, and omits rain entirely on dry
/// days — hence the nullable gust and the fall back to zero rain.
LiveWeather? liveWeatherFromDaily(Map<String, dynamic>? daily) {
  if (daily == null) return null;
  final windMetresPerSecond = (daily['wind_speed_ms'] as num?)?.toDouble();
  if (windMetresPerSecond == null) return null;
  final gustMetresPerSecond = (daily['wind_gust_ms'] as num?)?.toDouble();
  return LiveWeather(
    windKmh: kmhFromMetresPerSecond(windMetresPerSecond),
    gustKmh: gustMetresPerSecond == null
        ? null
        : kmhFromMetresPerSecond(gustMetresPerSecond),
    rainMm: (daily['rain_mm'] as num?)?.toDouble() ?? 0.0,
  );
}
