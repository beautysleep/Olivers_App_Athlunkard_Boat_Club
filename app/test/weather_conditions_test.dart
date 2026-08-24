import 'package:flutter_test/flutter_test.dart';

import 'package:athlunkard_boat_club/services/weather_conditions.dart';

void main() {
  group('kmhFromMetresPerSecond', () {
    test('converts m/s to km/h', () {
      expect(kmhFromMetresPerSecond(5.0), closeTo(18.0, 1e-9));
    });
  });

  group('liveWeatherFromDaily', () {
    test('maps fields and converts wind + gust to km/h', () {
      final w = liveWeatherFromDaily({
        'wind_speed_ms': 5.0,
        'wind_gust_ms': 10.0,
        'rain_mm': 1.2,
      });
      expect(w, isNotNull);
      expect(w!.windKmh, closeTo(18.0, 1e-9));
      expect(w.gustKmh, closeTo(36.0, 1e-9));
      expect(w.rainMm, 1.2);
    });

    test('absent gust stays null (4.0 daily omits it)', () {
      final w = liveWeatherFromDaily({
        'wind_speed_ms': 4.0,
        'wind_gust_ms': null,
      });
      expect(w!.gustKmh, isNull);
    });

    test('absent rain defaults to 0 (dry day)', () {
      final w = liveWeatherFromDaily({'wind_speed_ms': 4.0});
      expect(w!.rainMm, 0.0);
    });

    test('null daily map returns null', () {
      expect(liveWeatherFromDaily(null), isNull);
    });

    test('missing wind returns null (nothing usable)', () {
      expect(liveWeatherFromDaily({'rain_mm': 1.0}), isNull);
    });
  });
}
