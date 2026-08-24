import 'package:cloud_firestore/cloud_firestore.dart';

import 'day_ratings.dart';

class FirestoreDayRatingRepository {
  /// Keyed by 'YYYY-MM-DD'.
  ///
  /// Firestore is reached inside the method rather than held in a field, so
  /// constructing this cannot fail when Firebase is not initialised — callers
  /// catch and carry on without live data.
  Future<Map<String, LiveDayRating>> loadRatings() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('day_ratings')
        .get();

    final ratings = <String, LiveDayRating>{};
    for (final document in snapshot.docs) {
      final rating = liveDayRatingFromDocument(_withDateTimes(document.data()));
      if (rating != null) ratings[document.id] = rating;
    }
    return ratings;
  }

  /// Unwrapping the Timestamps here is what keeps day_ratings.dart free of any
  /// Firestore dependency.
  Map<String, dynamic> _withDateTimes(Map<String, dynamic> data) => {
    ...data,
    'windows': [
      for (final raw in (data['windows'] as List?) ?? const [])
        {
          ...(raw as Map).cast<String, dynamic>(),
          'high_tide_at': (raw['high_tide_at'] as Timestamp).toDate(),
          'window_start': (raw['window_start'] as Timestamp?)?.toDate(),
          'window_end': (raw['window_end'] as Timestamp?)?.toDate(),
        },
    ],
  };
}
