import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'firebase_start.dart';

/// Usage reporting to Google Analytics for Firebase.
///
/// Off until the admin panel turns it on and gives the Firebase ids (App →
/// Analytics & SEO), so a build never reports anywhere by itself. Events
/// logged before the config has arrived are held and sent once it has, or
/// dropped if analytics turns out to be off. Nothing personal is sent: no
/// names, emails or phone numbers, only what was looked at and done.
class Analytics {
  Analytics._();

  static final Analytics instance = Analytics._();

  FirebaseAnalytics? _ga;
  bool _decided = false;
  final List<(String, Map<String, Object>?)> _held = [];

  bool get isOn => _ga != null;

  /// Called whenever /app/config has been read.
  Future<void> start(AppConfig c) async {
    final ids = c.analyticsFirebase;
    if (!c.analyticsEnabled || ids == null) {
      // Turned off in the admin panel: stop collecting on this device too.
      if (_ga != null) {
        try {
          await _ga!.setAnalyticsCollectionEnabled(false);
        } catch (_) {}
      }
      _ga = null;
      _decided = true;
      _held.clear();
      return;
    }
    if (_ga != null) return;
    if (!await startFirebase(ids)) {
      _decided = true;
      _held.clear();
      return;
    }
    try {
      final ga = FirebaseAnalytics.instance;
      await ga.setAnalyticsCollectionEnabled(true);
      _ga = ga;
    } catch (e) {
      debugPrint('Analytics unavailable: $e');
    }
    _decided = true;
    final held = List.of(_held);
    _held.clear();
    for (final (name, params) in held) {
      _send(name, params);
    }
  }

  /// A screen was opened. [name] is short and stable: "temple", "search".
  void screen(String name, {String? item}) => _log('screen_view', {
        'screen_name': name,
        'screen_class': name,
        if (item != null) 'item_id': item,
      });

  /// Any other event; names and keys follow GA's rules (a–z, 0–9, _).
  void event(String name, [Map<String, Object?>? params]) => _log(
      name,
      params == null
          ? null
          : {
              for (final e in params.entries)
                if (e.value != null) e.key: e.value!
            });

  void login(String method) => event('login', {'method': method});

  void signUp(String method) => event('sign_up', {'method': method});

  void search(String term) {
    if (term.trim().isEmpty) return;
    event('search', {'search_term': term.trim()});
  }

  void viewTemple(String slug, {String? name}) => event('view_item', {
        'item_id': slug,
        if (name != null) 'item_name': name,
        'item_category': 'temple',
      });

  /// A payment was started, for a seva booking ("seva") or a plan ("plan").
  void beginCheckout(String kind, {String? item, num? value, String currency = 'INR', String? gateway}) => event('begin_checkout', {
        'item_category': kind,
        'item_id': item,
        'value': value,
        'currency': value == null ? null : currency,
        'payment_type': gateway,
      });

  /// A payment went through.
  void purchase(String kind, {String? item, num? value, String currency = 'INR', String? transactionId}) => event('purchase', {
        'item_category': kind,
        'item_id': item,
        'value': value,
        'currency': value == null ? null : currency,
        'transaction_id': transactionId,
      });

  void _log(String name, Map<String, Object>? params) {
    if (_ga != null) return _send(name, params);
    // Not decided yet: hold a few, the config is on its way.
    if (!_decided && _held.length < 30) _held.add((name, params));
  }

  void _send(String name, Map<String, Object>? params) {
    final ga = _ga;
    if (ga == null) return;
    final future = name == 'screen_view'
        ? ga.logScreenView(
            screenName: params?['screen_name'] as String?,
            screenClass: params?['screen_class'] as String?,
            parameters: params == null
                ? null
                : (Map.of(params)
                  ..remove('screen_name')
                  ..remove('screen_class')))
        : ga.logEvent(name: name, parameters: params);
    future.catchError((Object e) => debugPrint('Analytics: $e'));
  }
}
