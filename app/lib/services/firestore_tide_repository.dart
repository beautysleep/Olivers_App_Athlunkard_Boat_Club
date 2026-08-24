/// Reads live tide predictions from Firestore (the `tide_predictions`
/// collection written by the backend Cloud Function). Isolated behind this
/// class so Firestore is only touched here; the pure tide-window logic lives in
/// tide_windows.dart.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'tide_windows.dart';

class FirestoreTideRepository {
  /// All High-water events per local day, keyed by 'YYYY-MM-DD' and sorted by
  /// time. A day usually has two — both are kept (the offerable-session filter
  /// is applied later); we no longer collapse to a single highest.
  ///
  /// Firestore is accessed lazily inside this method (not in a field), so
  /// nothing breaks at construction if Firebase isn't initialised — callers
  /// wrap this in try/catch and fall back to mock data.
  Future<Map<String, List<LiveHighTide>>> loadHighTides() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('tide_predictions').get();

    final result = <String, List<LiveHighTide>>{};
    for (final doc in snapshot.docs) {
      final extremes = (doc.data()['extremes'] as List?) ?? const [];
      final highs = <LiveHighTide>[];
      for (final raw in extremes) {
        final e = (raw as Map).cast<String, dynamic>();
        if (e['kind'] != 'High') continue;
        final ts = e['time_utc'];
        final height = (e['height_m'] as num?)?.toDouble();
        if (ts is! Timestamp || height == null) continue;
        highs.add(LiveHighTide(localTime: ts.toDate().toLocal(), heightMetres: height));
      }
      if (highs.isNotEmpty) {
        highs.sort((a, b) => a.localTime.compareTo(b.localTime));
        result[doc.id] = highs;
      }
    }
    return result;
  }
}
