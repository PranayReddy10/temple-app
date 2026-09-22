import 'dart:convert';

import 'package:flutter/foundation.dart';
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
  final Set<String> _saved = {};

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

  Future<void> logout() async {
    try {
      await api.post('auth/logout', const {});
    } catch (_) {
      // A dead token is as good as a revoked one for the client.
    }
    _devotee = null;
    api.token = null;
    _saved.clear();
    await _prefs.remove('devotee_token');
    await _prefs.remove('devotee');
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

  Future<void> updateProfile({String? name, String? locale}) async {
    final json = await api.patch('me', {if (name != null) 'name': name, if (locale != null) 'locale': locale});
    await _store(Devotee.fromJson(json['data'] as Map<String, dynamic>), api.token!);
  }

  /// Server-side saved temples, merged into the local favourites when online.
  Future<Set<String>> savedTempleSlugs() async {
    if (!isSignedIn) return {};
    try {
      final json = await api.get('me/saved-temples');
      _saved
        ..clear()
        ..addAll((json['data'] as List? ?? const []).map((e) => '${(e as Map)['slug']}'));
    } catch (_) {}
    return _saved;
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
