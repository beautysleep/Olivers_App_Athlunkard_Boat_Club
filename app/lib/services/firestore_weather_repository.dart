/// Reads live daily weather from Firestore (the `weather_forecasts` collection
/// written by the backend Cloud Function). Isolated behind this class so
/// Firestore is only touched here; the pure mapping lives in
/// weather_conditions.dart.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'weather_conditions.dart';

class FirestoreWeatherRepository {
  /// Live daily weather per local day, keyed by 'YYYY-MM-DD'. The `hourly` series
  /// is stored too but not read here — it's for the future decision engine.
  ///
  /// Firestore is accessed lazily inside this method (not in a field), so nothing
  /// breaks at construction if Firebase isn't initialised — callers wrap this in
  /// try/catch and fall back to mock data.
  Future<Map<String, LiveWeather>> loadDailyWeather() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('weather_forecasts').get();

    final result = <String, LiveWeather>{};
    for (final doc in snapshot.docs) {
      final daily = (doc.data()['daily'] as Map?)?.cast<String, dynamic>();
      final weather = liveWeatherFromDaily(daily);
      if (weather != null) result[doc.id] = weather;
    }
    return result;
  }
}
