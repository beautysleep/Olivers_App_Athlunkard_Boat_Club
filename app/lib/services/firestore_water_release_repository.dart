/// Reads live water-release status from Firestore (the single
/// `water_release_status/current` document written by the backend Cloud
/// Function). Isolated behind this class so Firestore is only touched here;
/// the pure mapping lives in water_release_conditions.dart.
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'water_release_conditions.dart';

class FirestoreWaterReleaseRepository {
  /// The current water-release status, or null if there's no usable document
  /// yet. Unlike tide/weather, this reads a single fixed document — the
  /// signal is global, not per-day, so there's nothing to key by date.
  ///
  /// Firestore is accessed lazily inside this method (not in a field), so
  /// nothing breaks at construction if Firebase isn't initialised — callers
  /// wrap this in try/catch and fall back to mock data.
  Future<LiveWaterRelease?> loadStatus() async {
    final doc = await FirebaseFirestore.instance
        .collection('water_release_status')
        .doc('current')
        .get();
    return liveWaterReleaseFromDoc(doc.data());
  }
}
