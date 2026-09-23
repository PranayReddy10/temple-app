import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../brand.dart';
import '../models/models.dart';

/// App-wide preferences: language, colour scheme, API server.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs, this.api) {
    _locale = Locale(_prefs.getString('locale') ?? 'en');
    _themeMode = ThemeMode.values[_prefs.getInt('theme_mode') ?? 0];
    api.baseUrl = _prefs.getString('api_base') ?? Brand.defaultApiBase;
    api.language = _locale.languageCode;
    _doorAnimations = _prefs.getBool('door_animations') ?? true;
    final langs = _prefs.getString('languages');
    if (langs != null) {
      try {
        _languages = (jsonDecode(langs) as List).map((e) => LanguageInfo.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {}
    }
  }

  /// What the server says it can serve. Null until `/languages` answers;
  /// the bundled five are always offered for the interface.
  List<LanguageInfo>? _languages;
  List<LanguageInfo>? get serverLanguages => _languages;

  /// Whether the API serves content in [code] today.
  bool contentAvailable(String code) => _languages?.where((l) => l.code == code).firstOrNull?.isAvailable ?? true;

  Future<void> loadLanguages(ApiClient client) async {
    final json = await client.get('languages');
    final data = json['data'] as Map<String, dynamic>;
    _languages = (data['languages'] as List).map((e) => LanguageInfo.fromJson(e as Map<String, dynamic>)).toList();
    await _prefs.setString('languages', jsonEncode((data['languages'] as List)));
    notifyListeners();
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

  static const supportedLocales = [Locale('en'), Locale('te'), Locale('hi'), Locale('ta'), Locale('kn')];

  Future<void> setLocale(Locale l) async {
    _locale = l;
    api.language = l.languageCode;
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
