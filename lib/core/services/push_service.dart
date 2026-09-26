import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../platform.dart';
import '../state/app_config_controller.dart';
import '../state/auth_controller.dart';
import '../state/notifications_controller.dart';
import '../../features/notifications/notice_links.dart';

/// Push notifications through Firebase Cloud Messaging.
///
/// Firebase is started from the public ids the server sends in /app/config,
/// so switching projects or turning push on is done in the admin panel, not
/// by shipping a build. The device subscribes to the topics the admin panel
/// sends to — "all", its platform, and "state-{id}" for its home state — and
/// registers its token so one devotee can be reached directly.
class PushService {
  PushService({required this.prefs, required this.api, required this.auth, required this.config, required this.inbox});

  final SharedPreferences prefs;
  final ApiClient api;
  final AuthController auth;
  final AppConfigController config;
  final NotificationsController inbox;

  bool _started = false;
  String? _token;
  final List<StreamSubscription<dynamic>> _subs = [];

  /// Safe to call on every launch and after sign-in; does nothing when push
  /// is off in the admin panel or unavailable on this platform.
  Future<void> start() async {
    final c = config.config;
    if (!c.pushEnabled || c.firebase == null || !AppPlatform.isMobile) return;
    try {
      if (!_started) {
        final f = c.firebase!;
        if (Firebase.apps.isEmpty) {
          await Firebase.initializeApp(
            options: FirebaseOptions(
              apiKey: f['api_key'] ?? '',
              appId: f['app_id'] ?? '',
              messagingSenderId: f['messaging_sender_id'] ?? '',
              projectId: f['project_id'] ?? '',
              iosBundleId: f['ios_bundle_id'],
            ),
          );
        }
        final m = FirebaseMessaging.instance;
        await m.requestPermission();
        await m.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);
        _subs.add(FirebaseMessaging.onMessage.listen(_onForeground));
        _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_onOpened));
        _subs.add(m.onTokenRefresh.listen(_register));
        final initial = await m.getInitialMessage();
        if (initial != null) _onOpened(initial);
        _started = true;
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _register(token);
      await _topics();
    } catch (e) {
      // No Play services, permission refused, or ids wrong in the admin
      // panel: the inbox still works.
      debugPrint('Push unavailable: $e');
    }
  }

  Future<void> _register(String token) async {
    _token = token;
    try {
      await api.post('devices', {'token': token, 'platform': AppPlatform.name, 'app_version': AppPlatform.version, 'locale': api.language});
    } catch (_) {}
  }

  /// Called before signing out, so the next person on this phone does not
  /// receive the previous one's messages.
  Future<void> forget() async {
    if (_token == null) return;
    try {
      await api.post('devices/forget', {'token': _token});
    } catch (_) {}
  }

  Future<void> _topics() async {
    final m = FirebaseMessaging.instance;
    await m.subscribeToTopic('all');
    await m.subscribeToTopic(AppPlatform.name);
    final previous = prefs.getString('push_state_topic');
    final stateId = auth.devotee?.homeStateId;
    final next = stateId == null ? null : 'state-$stateId';
    if (previous != null && previous != next) await m.unsubscribeFromTopic(previous);
    if (next != null && next != previous) await m.subscribeToTopic(next);
    if (next == null) {
      await prefs.remove('push_state_topic');
    } else {
      await prefs.setString('push_state_topic', next);
    }
  }

  /// A saved temple's followers are reached through its topic.
  Future<void> followTemple(int? templeId, bool follow) async {
    if (!_started || templeId == null) return;
    try {
      follow ? await FirebaseMessaging.instance.subscribeToTopic('temple-$templeId') : await FirebaseMessaging.instance.unsubscribeFromTopic('temple-$templeId');
    } catch (_) {}
  }

  void _onForeground(RemoteMessage message) {
    inbox.load();
    final n = message.notification;
    if (n == null) return;
    rootMessengerKey.currentState?.showSnackBar(SnackBar(
      content: Text(n.title == null ? (n.body ?? '') : '${n.title}\n${n.body ?? ''}'),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: 'Open', onPressed: () => _onOpened(message)),
      persist: false,
    ));
  }

  void _onOpened(RemoteMessage message) {
    final d = message.data;
    final notice = AppNotice(
      id: int.tryParse('${d['notification_id']}') ?? 0,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      linkType: '${d['link_type'] ?? 'none'}',
      linkValue: d['link_value']?.toString(),
    );
    if (notice.id != 0) {
      final known = inbox.items.where((i) => i.id == notice.id).firstOrNull;
      inbox.markRead(known ?? notice);
    }
    // Wait for the first frame when launched from a notification.
    WidgetsBinding.instance.addPostFrameCallback((_) => openNoticeLink(notice));
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
  }
}
