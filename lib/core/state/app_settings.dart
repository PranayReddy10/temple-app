import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../brand.dart';

/// App-wide preferences: language, colour scheme, API server.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs, this.api) {
    _locale = Locale(_prefs.getString('locale') ?? 'en');
    _themeMode = ThemeMode.values[_prefs.getInt('theme_mode') ?? 0];
    api.baseUrl = _prefs.getString('api_base') ?? Brand.defaultApiBase;
    _doorAnimations = _prefs.getBool('door_animations') ?? true;
  }

  final SharedPreferences _prefs;
  final ApiClient api;

  late Locale _locale;
  late ThemeMode _themeMode;
  late bool _doorAnimations;

  Locale get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get doorAnimations => _doorAnimations;
  String get apiBase => api.baseUrl;

  static const supportedLocales = [Locale('en'), Locale('te'), Locale('hi')];

  Future<void> setLocale(Locale l) async {
    _locale = l;
    await _prefs.setString('locale', l.languageCode);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    _themeMode = m;
    await _prefs.setInt('theme_mode', m.index);
    notifyListeners();
  }

  Future<void> setDoorAnimations(bool v) async {
    _doorAnimations = v;
    await _prefs.setBool('door_animations', v);
    notifyListeners();
  }

  Future<void> setApiBase(String url) async {
    api.baseUrl = url;
    await _prefs.setString('api_base', api.baseUrl);
    notifyListeners();
  }
}
