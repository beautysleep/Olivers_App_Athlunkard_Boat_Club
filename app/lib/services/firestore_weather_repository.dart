/// Reads live daily weather from Firestore (the `weather_forecasts` collection
/// written by the backend Cloud Function). Isolated behind this class so
/// Firestore is only touched here; the pure mapping lives in
/// weather_conditions.dart.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

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
  Future<({Map<String, LiveWeather> weather})> loadDailyForecasts() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('weather_forecasts').get();

    final weather = <String, LiveWeather>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final daily = (data['daily'] as Map?)?.cast<String, dynamic>();
      final point = liveWeatherFromDaily(daily);
      if (point != null) weather[doc.id] = point;
    }
    return (weather: weather);
  }
}
