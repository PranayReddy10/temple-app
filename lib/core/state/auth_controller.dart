import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';

/// Devotee session against `/api/v1/auth` and `/api/v1/me`.
class AuthController extends ChangeNotifier {
  AuthController(this._prefs, this.api) {
    final token = _prefs.getString('devotee_token');
    final raw = _prefs.getString('devotee');
    if (token != null && raw != null) {
      api.token = token;
      try {
        _devotee = Devotee.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final ApiClient api;

  Devotee? _devotee;
  bool _busy = false;

  Devotee? get devotee => _devotee;
  bool get isSignedIn => _devotee != null;
  bool get busy => _busy;

  Future<void> _store(Devotee d, String token) async {
    _devotee = d;
    api.token = token;
    await _prefs.setString('devotee_token', token);
    await _prefs.setString('devotee', jsonEncode(d.toJson()));
    notifyListeners();
  }

  Future<void> register({required String name, String? email, String? phone, required String password, String locale = 'en'}) async {
    _busy = true;
    notifyListeners();
    try {
      final json = await api.post('auth/register', {
        'name': name,
        if (email != null && email.isNotEmpty) 'email': email,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'password': password,
        'password_confirmation': password,
        'locale': locale,
      });
      final data = json['data'] as Map<String, dynamic>;
      await _store(Devotee.fromJson(data['devotee'] as Map<String, dynamic>), data['token'] as String);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> login({required String identifier, required String password}) async {
    _busy = true;
    notifyListeners();
    try {
      final json = await api.post('auth/login', {'identifier': identifier, 'password': password});
      final data = json['data'] as Map<String, dynamic>;
      await _store(Devotee.fromJson(data['devotee'] as Map<String, dynamic>), data['token'] as String);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// "Continue with Google" / "Sign in with Apple": the provider's identity
  /// token, obtained on the device, exchanged for our own. The server
  /// verifies it; nothing here is trusted on the device's word.
  Future<void> loginWithIdToken(String provider, Map<String, dynamic> body) async {
    _busy = true;
    notifyListeners();
    try {
      final json = await api.post('auth/$provider', body);
      final data = json['data'] as Map<String, dynamic>;
      await _store(Devotee.fromJson(data['devotee'] as Map<String, dynamic>), data['token'] as String);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Forgot password, step one: the server emails a 6-digit code. Answers
  /// the same whether or not the email has an account.
  Future<void> forgotPassword(String email) async {
    await api.post('auth/password/forgot', {'email': email});
  }

  /// Step two: the code and a new password, which also signs them in.
  Future<void> resetPassword({required String email, required String code, required String password}) async {
    _busy = true;
    notifyListeners();
    try {
      final json = await api.post('auth/password/reset', {'email': email, 'code': code, 'password': password, 'password_confirmation': password});
      final data = json['data'] as Map<String, dynamic>;
      await _store(Devotee.fromJson(data['devotee'] as Map<String, dynamic>), data['token'] as String);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Called when something the account holds changed on the server (a plan
  /// bought, for one), so entitlements are fresh without signing in again.
  Future<void> reload() => refresh();

  /// What else must be forgotten when somebody signs out: the passport,
  /// photos, memories, trips and the rest, registered from main.dart.
  final List<Future<void> Function()> _signOutHooks = [];

  void onSignOut(Future<void> Function() hook) => _signOutHooks.add(hook);

  /// Signs out and leaves nothing of the account behind on the device.
  ///
  /// Dropping the token alone left the last person's visits, photos and
  /// memories on screen, and the next account to sign in would have synced
  /// them in as its own.
  Future<void> logout() async {
    try {
      await api.post('auth/logout', const {});
    } catch (_) {
      // A dead token is as good as a revoked one for the client.
    }
    _devotee = null;
    api.token = null;
    await _prefs.remove('devotee_token');
    await _prefs.remove('devotee');
    // The profile photo picked on this phone is shown before the account's
    // own, so left behind it became the next account's photo.
    await _prefs.remove('avatar_path');
    for (final hook in _signOutHooks) {
      try {
        await hook();
      } catch (_) {}
    }
    // Decoded images outlive the records that showed them: the old profile
    // photo would otherwise still be drawn from memory.
    try {
      PaintingBinding.instance.imageCache
        ..clear()
        ..clearLiveImages();
    } catch (_) {
      // No binding (a unit test): no image cache to clear.
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    if (!isSignedIn) return;
    try {
      final json = await api.get('me');
      final d = Devotee.fromJson(json['data'] as Map<String, dynamic>);
      await _store(d, api.token!);
    } on ApiException catch (e) {
      if (e.isUnauthenticated) await logout();
    } catch (_) {}
  }

  /// What the devotee's passport QR carries. Stored with the profile, so it
  /// shows offline; an account signed in before codes existed fetches it.
  Future<String?> passportUrl() async {
    if (!isSignedIn) return null;
    if (_devotee!.passportUrl != null) return _devotee!.passportUrl;
    await refresh();
    return _devotee?.passportUrl;
  }

  /// A new code: every copy of the old one already shown or screenshotted
  /// stops opening this passport.
  Future<String?> resetPassportCode() async {
    await api.post('me/passport/qr/reset', const {});
    await refresh();
    return _devotee?.passportUrl;
  }

  Future<void> updateProfile({String? name, String? email, String? phone, String? locale, int? homeStateId, bool clearHomeState = false, String? dateOfBirth, bool clearDateOfBirth = false, String? gender, bool clearGender = false}) async {
    final json = await api.patch('me', {
      if (name != null) 'name': name,
      if (email != null) 'email': email.isEmpty ? null : email,
      if (phone != null) 'phone': phone.isEmpty ? null : phone,
      if (locale != null) 'locale': locale,
      if (homeStateId != null) 'home_state_id': homeStateId,
      if (clearHomeState) 'home_state_id': null,
      if (dateOfBirth != null) 'date_of_birth': dateOfBirth,
      if (clearDateOfBirth) 'date_of_birth': null,
      if (gender != null) 'gender': gender,
      if (clearGender) 'gender': null,
    });
    await _store(Devotee.fromJson(json['data'] as Map<String, dynamic>), api.token!);
  }

  /// Server-side saved temples, merged into the local favourites when online.
  Future<List<TempleSummary>> savedTemples() async {
    if (!isSignedIn) return const [];
    try {
      final json = await api.get('me/saved-temples');
      return (json['data'] as List? ?? const []).map((e) => TempleSummary.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Uploads a profile photo to `/me/avatar`; the account's avatar URL
  /// comes back on the devotee. Falls back to keeping it on the device when
  /// signed out or offline.
  Future<bool> uploadAvatar(String path) async {
    await setLocalAvatar(path);
    if (!isSignedIn) return false;
    try {
      final json = await api.upload('me/avatar', files: {'avatar': path});
      await _store(Devotee.fromJson(json['data'] as Map<String, dynamic>), api.token!);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> removeAvatar() async {
    await setLocalAvatar(null);
    if (!isSignedIn) return;
    try {
      final json = await api.delete('me/avatar');
      await _store(Devotee.fromJson(json['data'] as Map<String, dynamic>), api.token!);
    } catch (_) {}
  }

  /// A locally chosen avatar, kept until it reaches the account.
  String? get localAvatarPath => _prefs.getString('avatar_path');

  Future<void> setLocalAvatar(String? path) async {
    if (path == null) {
      await _prefs.remove('avatar_path');
    } else {
      await _prefs.setString('avatar_path', path);
    }
    notifyListeners();
  }

  Future<void> syncSave(String slug, bool saved) async {
    if (!isSignedIn) return;
    try {
      if (saved) {
        await api.put('me/saved-temples/$slug');
      } else {
        await api.delete('me/saved-temples/$slug');
      }
    } catch (_) {
      // Local state is the source of truth until the next sync.
    }
  }
}
