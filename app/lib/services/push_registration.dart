import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;

/// Requests notification permission, obtains the device's FCM token, and
/// registers it with the backend — including across a rotation, which
/// [FirebaseMessaging.onTokenRefresh] fires without warning while the app is
/// open. A bare concrete class rather than an interface with a fake, the
/// same way [FirestoreTideRepository] is: it wraps a Firebase plugin
/// singleton that cannot run in a Dart-only test either way.
class PushRegistration {
  const PushRegistration({required this.endpoint});

  /// The register-device-token function, from `terraform output
  /// register_device_token_uri`.
  final Uri endpoint;

  Future<void> registerCurrentDevice() async {
    await FirebaseMessaging.instance.requestPermission();
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _register(token);
    FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => _register(token).catchError((_) {}),
    );
  }

  Future<void> _register(String token) async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    final response = await http.post(
      endpoint,
      headers: {
        'Authorization': 'Bearer $idToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'token': token}),
    );
    if (response.statusCode != 200) {
      throw StateError('register_device_token failed: ${response.statusCode}');
    }
  }
}
