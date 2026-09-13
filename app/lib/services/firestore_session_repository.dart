import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models/session.dart';
import '../models/user_profile.dart';
import 'session_documents.dart';
import 'session_repository.dart';

class FirestoreSessionRepository implements SessionRepository {
  const FirestoreSessionRepository();

  @override
  Future<List<Session>> loadSessions(
    UserProfile? Function(String id) findAccount,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('sessions')
        .get();
    final sessions = <Session>[];
    for (final document in snapshot.docs) {
      final session = sessionFromDocument(
        document.id,
        _withLocalDateTimes(document.data()),
        findAccount,
      );
      if (session != null) sessions.add(session);
    }
    return sessions;
  }

  /// cloud_firestore decodes a Firestore timestamp as [Timestamp], not
  /// [DateTime] — [sessionFromDocument]'s `as DateTime?` cast would throw
  /// against one rather than returning null, so the boundary conversion
  /// happens here, the same way FirestoreTideRepository converts tide
  /// extremes before handing them off. [sessionFromDocument] itself stays
  /// untouched and pure.
  Map<String, dynamic> _withLocalDateTimes(Map<String, dynamic> document) => {
    ...document,
    for (final key in const ['meeting_time', 'high_tide_time'])
      if (document[key] is Timestamp)
        key: (document[key] as Timestamp).toDate().toLocal(),
  };

  @override
  Future<String> proposeSession({
    required DateTime meetingTime,
    required DateTime highTideTime,
    required Conditions conditionRating,
    // Not sent: the server fixes the minimum crew at 4 (variable headcount
    // by boat type is out of v1 scope). Kept on the interface only for
    // symmetry with Session.minimumCrew's own default.
    int minimumCrew = 4,
  }) async {
    final response = await _post(Uri.parse(proposeSessionEndpoint), {
      'meeting_time': meetingTime.toUtc().toIso8601String(),
      'high_tide_time': highTideTime.toUtc().toIso8601String(),
      'condition_rating': conditionRating.name,
    });
    if (response.statusCode != 200) {
      throw StateError('propose_session failed: ${response.statusCode}');
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['id'] as String;
  }

  @override
  Future<void> respondToSession(
    String sessionId, {
    required bool accept,
  }) async {
    final response = await _post(Uri.parse(respondToSessionEndpoint), {
      'session_id': sessionId,
      'accept': accept,
    });
    if (response.statusCode != 200) {
      throw StateError('respond_to_session failed: ${response.statusCode}');
    }
  }

  @override
  Future<void> cancelSession(
    String sessionId, {
    required bool pivotToLand,
  }) async {
    final response = await _post(Uri.parse(cancelSessionEndpoint), {
      'session_id': sessionId,
      'pivot_to_land': pivotToLand,
    });
    if (response.statusCode != 200) {
      throw StateError('cancel_session failed: ${response.statusCode}');
    }
  }

  Future<http.Response> _post(Uri endpoint, Map<String, dynamic> body) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return http.post(
      endpoint,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
  }
}
