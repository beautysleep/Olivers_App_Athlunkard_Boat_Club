/// Reads live daily weather from Firestore (the `weather_forecasts` collection
/// written by the backend Cloud Function). Isolated behind this class so
/// Firestore is only touched here; the pure mapping lives in
/// weather_conditions.dart.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'daylight_conditions.dart';
import 'weather_conditions.dart';

class FirestoreWeatherRepository {
  /// Everything the app reads off a `weather_forecasts` day, keyed by
  /// 'YYYY-MM-DD'. Returned together from one pass over the collection rather
  /// than read twice. The `hourly` series is stored too but not read here —
  /// it's for the future decision engine.
  ///
  /// Firestore is accessed lazily inside this method (not in a field), so nothing
  /// breaks at construction if Firebase isn't initialised — callers wrap this in
  /// try/catch and fall back to mock data.
  Future<
    ({Map<String, LiveWeather> weather, Map<String, LiveDaylight> daylight})
  >
  loadDailyForecasts() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('weather_forecasts').get();

    final weather = <String, LiveWeather>{};
    final daylight = <String, LiveDaylight>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final daily = (data['daily'] as Map?)?.cast<String, dynamic>();
      final point = liveWeatherFromDaily(daily);
      if (point != null) weather[doc.id] = point;

      // Firestore hands back Timestamps; converting here keeps
      // daylight_conditions.dart free of any Firestore dependency.
      final day = liveDaylightFromDocument({
        'sunrise': (data['sunrise'] as Timestamp?)?.toDate(),
        'sunset': (data['sunset'] as Timestamp?)?.toDate(),
      });
      if (day != null) daylight[doc.id] = day;
    }
    return (weather: weather, daylight: daylight);
  }
}
