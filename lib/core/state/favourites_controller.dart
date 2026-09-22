import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_controller.dart';

/// Saved temples. Local first, mirrored to the account when signed in.
class FavouritesController extends ChangeNotifier {
  FavouritesController(this._prefs, this._auth) {
    _slugs.addAll(_prefs.getStringList('favourites') ?? const []);
  }

  final SharedPreferences _prefs;
  final AuthController _auth;
  final Set<String> _slugs = {};

  Set<String> get slugs => Set.unmodifiable(_slugs);
  bool contains(String slug) => _slugs.contains(slug);

  Future<void> toggle(String slug) async {
    final nowSaved = !_slugs.contains(slug);
    if (nowSaved) {
      _slugs.add(slug);
    } else {
      _slugs.remove(slug);
    }
    await _prefs.setStringList('favourites', _slugs.toList());
    notifyListeners();
    await _auth.syncSave(slug, nowSaved);
  }

  Future<void> mergeFromAccount() async {
    final remote = await _auth.savedTempleSlugs();
    if (remote.isEmpty) return;
    _slugs.addAll(remote);
    await _prefs.setStringList('favourites', _slugs.toList());
    notifyListeners();
  }
}
