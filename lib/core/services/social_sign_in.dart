import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../models/models.dart';
import '../platform.dart';
import '../state/auth_controller.dart';

/// Thrown when the person closed the provider's sheet: not an error to show.
class SignInCancelled implements Exception {
  const SignInCancelled();
}

/// Google and Apple sign-in on the device. Each yields an identity token the
/// server verifies against the provider before it signs anyone in.
class SocialSignIn {
  SocialSignIn._();

  static bool _googleReady = false;

  static bool googleAvailable(AppConfig c) => c.googleSignIn && AppPlatform.isMobile && (c.googleServerClientId ?? '').isNotEmpty;

  /// Apple sign-in is offered on iPhone and iPad, where Apple requires it
  /// alongside any other social sign-in.
  static bool appleAvailable(AppConfig c) => c.appleSignIn && AppPlatform.isIOS;

  static Future<void> google(AuthController auth, AppConfig config) async {
    final g = GoogleSignIn.instance;
    if (!_googleReady) {
      await g.initialize(
        clientId: AppPlatform.isIOS ? config.googleIosClientId : null,
        // The token is addressed to this id, which is what the server checks.
        serverClientId: config.googleServerClientId,
      );
      _googleReady = true;
    }
    final GoogleSignInAccount account;
    try {
      account = await g.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) throw const SignInCancelled();
      rethrow;
    }
    final token = account.authentication.idToken;
    if (token == null) throw StateError('Google did not return a sign-in token.');
    await auth.loginWithIdToken('google', {'id_token': token});
  }

  static Future<void> apple(AuthController auth) async {
    // A fresh nonce each time: Apple puts its hash in the token, and the
    // server checks it, so a token lifted from another sign-in is useless.
    final raw = _nonce();
    final AuthorizationCredentialAppleID credential;
    try {
      credential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: sha256.convert(utf8.encode(raw)).toString(),
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) throw const SignInCancelled();
      rethrow;
    }
    final token = credential.identityToken;
    if (token == null) throw StateError('Apple did not return a sign-in token.');
    // Apple gives the name once, on the very first sign-in, and never again.
    final name = [credential.givenName, credential.familyName].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
    await auth.loginWithIdToken('apple', {'identity_token': token, 'nonce': raw, if (name.isNotEmpty) 'name': name});
  }

  static String _nonce([int length = 32]) {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final r = Random.secure();
    return List.generate(length, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
