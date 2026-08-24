import 'package:cloud_firestore/cloud_firestore.dart';

import 'water_release_conditions.dart';

class FirestoreWaterReleaseRepository {
  /// One fixed document, not one per day: the release signal is global.
  ///
  /// Firestore is reached inside the method rather than held in a field, so
  /// constructing this cannot fail when Firebase is not initialised — callers
  /// catch and carry on without live data.
  Future<LiveWaterRelease?> loadStatus() async {
    final document = await FirebaseFirestore.instance
        .collection('water_release_status')
        .doc('current')
        .get();
    return liveWaterReleaseFromDocument(document.data());
  }
}
