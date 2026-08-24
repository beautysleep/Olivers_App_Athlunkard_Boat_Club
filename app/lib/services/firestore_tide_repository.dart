import 'package:cloud_firestore/cloud_firestore.dart';

import 'tide_windows.dart';

class FirestoreTideRepository {
  /// Keyed by 'YYYY-MM-DD'. Both of a day's high waters are kept; which of them
  /// can actually be rowed is [offerableHighTides]' decision, not this one's.
  ///
  /// Firestore is reached inside the method rather than held in a field, so
  /// constructing this cannot fail when Firebase is not initialised — callers
  /// catch and carry on without live data.
  Future<Map<String, List<LiveHighTide>>> loadHighTides() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('tide_predictions')
        .get();

    final highTidesByDay = <String, List<LiveHighTide>>{};
    for (final document in snapshot.docs) {
      final extremes = (document.data()['extremes'] as List?) ?? const [];
      final highs = <LiveHighTide>[];
      for (final raw in extremes) {
        final extreme = (raw as Map).cast<String, dynamic>();
        if (extreme['kind'] != 'High') continue;
        final timeUtc = extreme['time_utc'];
        final heightMetres = (extreme['height_m'] as num?)?.toDouble();
        if (timeUtc is! Timestamp || heightMetres == null) continue;
        highs.add(
          LiveHighTide(
            localTime: timeUtc.toDate().toLocal(),
            heightMetres: heightMetres,
          ),
        );
      }
      if (highs.isNotEmpty) {
        highs.sort((a, b) => a.localTime.compareTo(b.localTime));
        highTidesByDay[document.id] = highs;
      }
    }
    return highTidesByDay;
  }
}
