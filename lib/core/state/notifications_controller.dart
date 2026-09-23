import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../platform.dart';
import 'auth_controller.dart';

/// The notification inbox: messages the team sent from the admin panel.
///
/// Read state lives on the server for a signed-in devotee (so it follows them
/// between phones) and on the device for a guest.
class NotificationsController extends ChangeNotifier {
  NotificationsController(this._prefs, this._api, this._auth) {
    _localRead.addAll(_prefs.getStringList('notices_read') ?? const []);
    _auth.addListener(_onAuth);
    _signedIn = _auth.isSignedIn;
  }

  final SharedPreferences _prefs;
  final ApiClient _api;
  final AuthController _auth;
  final Set<String> _localRead = {};
  bool _signedIn = false;

  List<AppNotice> items = const [];
  bool loading = false;
  String? error;

  void _onAuth() {
    if (_auth.isSignedIn != _signedIn) {
      _signedIn = _auth.isSignedIn;
      load();
    }
  }

  bool isRead(AppNotice n) => n.isRead ?? _localRead.contains('${n.id}');
  int get unreadCount => items.where((n) => !isRead(n)).length;

  Future<void> load() async {
    loading = true;
    notifyListeners();
    try {
      final json = await _api.get('notifications', {'platform': AppPlatform.name});
      items = (json['data'] as List).map((e) => AppNotice.fromJson(e as Map<String, dynamic>)).toList();
      error = null;
    } catch (e) {
      error = '$e';
    }
    loading = false;
    notifyListeners();
  }

  Future<void> markRead(AppNotice n) async {
    if (isRead(n)) return;
    _localRead.add('${n.id}');
    items = [for (final i in items) i.id == n.id ? AppNotice(id: i.id, title: i.title, body: i.body, imageUrl: i.imageUrl, linkType: i.linkType, linkValue: i.linkValue, sentAt: i.sentAt, isRead: true) : i];
    notifyListeners();
    await _prefs.setStringList('notices_read', _localRead.toList());
    if (_auth.isSignedIn) {
      try {
        await _api.post('me/notifications/${n.id}/read', const {});
      } catch (_) {}
    }
  }

  Future<void> markAllRead() async {
    for (final n in items) {
      _localRead.add('${n.id}');
    }
    items = [for (final i in items) AppNotice(id: i.id, title: i.title, body: i.body, imageUrl: i.imageUrl, linkType: i.linkType, linkValue: i.linkValue, sentAt: i.sentAt, isRead: true)];
    notifyListeners();
    await _prefs.setStringList('notices_read', _localRead.toList());
    if (_auth.isSignedIn) {
      try {
        await _api.post('me/notifications/read-all', {'platform': AppPlatform.name});
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuth);
    super.dispose();
  }
}
