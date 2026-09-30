import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Starts Firebase once, from the public ids the server sends in /app/config.
///
/// Push and analytics both need it; whichever asks first starts it, and the
/// other finds it running. Returns false when the ids are wrong or Firebase
/// is unavailable here, so callers can carry on without it.
Future<bool> startFirebase(Map<String, String> f) => _starting ??= _start(f).then((ok) {
      // A failed start may succeed later with corrected ids.
      if (!ok) _starting = null;
      return ok;
    });

Future<bool>? _starting;

Future<bool> _start(Map<String, String> f) async {
  if (Firebase.apps.isNotEmpty) return true;
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: f['api_key'] ?? '',
        appId: f['app_id'] ?? '',
        messagingSenderId: f['messaging_sender_id'] ?? '',
        projectId: f['project_id'] ?? '',
        iosBundleId: f['ios_bundle_id'],
        // Web only: the Google Analytics stream the web app reports to.
        measurementId: f['measurement_id'],
        authDomain: f['auth_domain'],
      ),
    );
    return true;
  } catch (e) {
    debugPrint('Firebase unavailable: $e');
    return false;
  }
}
