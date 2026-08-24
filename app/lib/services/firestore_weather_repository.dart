import 'package:cloud_firestore/cloud_firestore.dart';

import 'daylight_conditions.dart';
import 'weather_conditions.dart';

class FirestoreWeatherRepository {
  /// Keyed by 'YYYY-MM-DD'. Weather and daylight come back together because
  /// they share one pass over the collection. The stored `hourly` series is
  /// deliberately not read yet — it is the decision engine's input.
  ///
  /// Firestore is reached inside the method rather than held in a field, so
  /// constructing this cannot fail when Firebase is not initialised — callers
  /// catch and carry on without live data.
  Future<
    ({Map<String, LiveWeather> weather, Map<String, LiveDaylight> daylight})
  >
  loadDailyForecasts() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('weather_forecasts')
        .get();

    final weather = <String, LiveWeather>{};
    final daylight = <String, LiveDaylight>{};
    for (final document in snapshot.docs) {
      final data = document.data();
      final daily = (data['daily'] as Map?)?.cast<String, dynamic>();
      final dayWeather = liveWeatherFromDaily(daily);
      if (dayWeather != null) weather[document.id] = dayWeather;

      // Unwrapping the Timestamps here is what keeps daylight_conditions.dart
      // free of any Firestore dependency.
      final dayDaylight = liveDaylightFromDocument({
        'sunrise': (data['sunrise'] as Timestamp?)?.toDate(),
        'sunset': (data['sunset'] as Timestamp?)?.toDate(),
      });
      if (dayDaylight != null) daylight[document.id] = dayDaylight;
    }
    return (weather: weather, daylight: daylight);
  }
}
