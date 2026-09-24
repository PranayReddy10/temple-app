import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../platform.dart';

/// What the admin panel says the app may do: maintenance, updates, sign-in
/// methods, push, ads and payments.
///
/// The last answer is kept, so an offline launch still honours maintenance
/// and a required update, and nothing waits on the network to draw.
class AppConfigController extends ChangeNotifier {
  AppConfigController(this._prefs, this._api) {
    final raw = _prefs.getString('app_config');
    if (raw != null) {
      try {
        config = AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final ApiClient _api;

  AppConfig config = AppConfig.fallback;
  bool loaded = false;

  Future<void> load() async {
    try {
      final json = await _api.get('app/config', {'platform': AppPlatform.name, 'version': AppPlatform.version});
      final data = json['data'] as Map<String, dynamic>;
      config = AppConfig.fromJson(data);
      await _prefs.setString('app_config', jsonEncode(data));
    } catch (_) {
      // Offline, or an older server without the endpoint: keep the last answer.
    }
    loaded = true;
    notifyListeners();
  }

  /// An optional update is offered once per version, not on every launch.
  bool get shouldOfferUpdate => config.updateAvailable && !config.updateRequired && _prefs.getString('update_dismissed') != config.latestVersion;

  Future<void> dismissUpdate() async {
    if (config.latestVersion != null) await _prefs.setString('update_dismissed', config.latestVersion!);
    notifyListeners();
  }
}
