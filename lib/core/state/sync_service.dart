import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../data/sample_data.dart';
import '../models/models.dart';
import 'app_settings.dart';
import 'auth_controller.dart';
import 'memories_controller.dart';
import 'passport_controller.dart';
import 'submissions_controller.dart';
import 'yatra_controller.dart';

/// One queued write to the API.
class SyncOp {
  SyncOp({required this.id, required this.type, required this.payload, this.attempts = 0, this.lastError});

  final String id;
  final String type;
  final Map<String, dynamic> payload;
  int attempts;
  String? lastError;

  Map<String, dynamic> toJson() => {'id': id, 'type': type, 'payload': payload, 'attempts': attempts, 'error': lastError};

  factory SyncOp.fromJson(Map<String, dynamic> j) => SyncOp(id: '${j['id']}', type: '${j['type']}', payload: Map<String, dynamic>.from(j['payload'] as Map), attempts: (j['attempts'] as num?)?.toInt() ?? 0, lastError: j['error']?.toString());
}

/// The bridge between what the device recorded and what the account holds.
///
/// Every write goes through an outbox: a visit recorded at a temple gate
/// with no signal is queued, and sent the next time the app is online and
/// signed in. Reads pull the account's visits, trips, memories and tickets
/// and merge them into the device's own, matching by server id so nothing
/// is doubled. Neither direction ever deletes a device record on its own.
class SyncService extends ChangeNotifier {
  SyncService({required SharedPreferences prefs, required this.api, required this.auth, required this.settings, required this.passport, required this.yatras, required this.memories, required this.submissions})
      : _prefs = prefs {
    final raw = _prefs.getString('outbox');
    if (raw != null) {
      try {
        _outbox.addAll((jsonDecode(raw) as List).map((e) => SyncOp.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    passport.onVisitCreated = _queueVisit;
    yatras.onChanged = (y) => enqueue('yatra_push', {'local_id': y.id});
    yatras.onDeleted = (id) => enqueue('yatra_delete', {'remote_id': id});
    memories.onCreated = (m) => enqueue('memory_create', {'local_id': m.localId});
    memories.onUpdated = (m) => m.remoteId == null ? Future.value() : enqueue('memory_update', {'local_id': m.localId});
    memories.onDeleted = (id) => enqueue('memory_delete', {'remote_id': id});
    submissions.onCreated = (s) => enqueue('support_create', {'local_id': s.id});
    auth.addListener(_onAuthChanged);
    _wasSignedIn = auth.isSignedIn;
  }

  final SharedPreferences _prefs;
  final ApiClient api;
  final AuthController auth;
  final AppSettings settings;
  final PassportController passport;
  final YatraController yatras;
  final MemoriesController memories;
  final SubmissionsController submissions;

  final List<SyncOp> _outbox = [];
  bool _flushing = false;
  Future<void>? _inflight;
  bool _wasSignedIn = false;
  DateTime? lastPulledAt;
  String? lastError;
  List<VisitPhoto> remotePhotos = const [];

  int get pendingCount => _outbox.length;
  bool get isFlushing => _flushing;
  List<SyncOp> get outbox => List.unmodifiable(_outbox);

  void _onAuthChanged() {
    if (auth.isSignedIn && !_wasSignedIn) {
      // Signing in: everything recorded as a guest now belongs to the account.
      for (final v in passport.unsynced) {
        if (!_outbox.any((o) => o.type == 'visit_create' && o.payload['key'] == v.localKey)) _queueVisit(v);
      }
      for (final y in yatras.yatras.where((y) => y.remoteId == null)) {
        enqueue('yatra_push', {'local_id': y.id});
      }
      for (final m in memories.all.where((m) => m.remoteId == null)) {
        enqueue('memory_create', {'local_id': m.localId});
      }
      sync();
    }
    _wasSignedIn = auth.isSignedIn;
  }

  Future<void> _queueVisit(Visit v) => enqueue('visit_create', {'key': v.localKey});

  Future<void> queuePhoto(Visit v, {required String photoPath, String? stampPath, String? caption}) =>
      enqueue('photo_upload', {'key': v.localKey, 'photo': photoPath, if (stampPath != null) 'stamp': stampPath, if (caption != null) 'caption': caption});

  Future<void> enqueue(String type, Map<String, dynamic> payload) async {
    // One pending push per trip or memory is enough; later edits ride it.
    if (type == 'yatra_push' || type == 'memory_update') {
      _outbox.removeWhere((o) => o.type == type && o.payload['local_id'] == payload['local_id']);
    }
    _outbox.add(SyncOp(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), type: type, payload: payload));
    await _persist();
    // Fire and forget: the caller is a tap handler, not a sync screen.
    unawaited(flush());
  }

  /// Flush the outbox, then pull the account. Safe to call often.
  Future<void> sync() async {
    await flush();
    await pull();
  }

  /// Sends queued writes in order. Stops at the first network failure and
  /// keeps the rest; drops an op the server rejected outright (a 4xx that is
  /// not auth or throttling) after recording why. A call while a flush is
  /// already running joins it rather than starting a second.
  Future<void> flush() => _inflight ??= _flush().whenComplete(() => _inflight = null);

  Future<void> _flush() async {
    _flushing = true;
    notifyListeners();
    try {
      var i = 0;
      while (i < _outbox.length) {
        final op = _outbox[i];
        final needsAuth = op.type != 'support_create';
        if (needsAuth && !auth.isSignedIn) {
          i++;
          continue;
        }
        try {
          final done = await _execute(op);
          if (done) {
            _outbox.removeAt(i);
          } else {
            i++; // Deferred: waiting on another op.
          }
          lastError = null;
        } on ApiException catch (e) {
          op.attempts++;
          op.lastError = e.message;
          if (e.isUnauthenticated || e.statusCode == 429 || (e.statusCode ?? 500) >= 500) {
            lastError = e.message;
            break;
          }
          // The server will never accept this one; keep the device record.
          _outbox.removeAt(i);
          lastError = '${op.type}: ${e.message}';
        } catch (e) {
          op.attempts++;
          op.lastError = '$e';
          lastError = 'Offline';
          break;
        }
        await _persist();
      }
      await _persist();
    } finally {
      _flushing = false;
      notifyListeners();
    }
  }

  Future<bool> _execute(SyncOp op) async {
    switch (op.type) {
      case 'visit_create':
        final v = passport.byKey('${op.payload['key']}');
        if (v == null || v.remoteId != null) return true;
        final json = await api.post('temples/${v.templeSlug}/visits', {
          'method': v.verification.name,
          'visited_on': v.visitedAt.toIso8601String().substring(0, 10),
          'visited_at': '${v.visitedAt.hour.toString().padLeft(2, '0')}:${v.visitedAt.minute.toString().padLeft(2, '0')}',
          if (v.latitude != null) 'latitude': v.latitude,
          if (v.longitude != null) 'longitude': v.longitude,
          if (v.note != null) 'note': v.note,
          'is_public': true,
        });
        await passport.setRemote(v.localKey, RemoteVisit.fromJson(json['data'] as Map<String, dynamic>));
        return true;
      case 'photo_upload':
        final v = passport.byKey('${op.payload['key']}');
        if (v == null || v.remotePhoto != null) return true;
        if (v.remoteId == null) return false; // wait for the visit
        final photo = '${op.payload['photo']}';
        if (!File(photo).existsSync()) return true;
        final stamp = op.payload['stamp']?.toString();
        final json = await api.upload('temples/${v.templeSlug}/photos', files: {'photo': photo, if (stamp != null && File(stamp).existsSync()) 'stamp': stamp}, fields: {'visit_id': '${v.remoteId}', if (op.payload['caption'] != null) 'caption': '${op.payload['caption']}', 'is_public': '0'});
        await passport.setRemotePhoto(v.localKey, VisitPhoto.fromJson(json['data'] as Map<String, dynamic>));
        return true;
      case 'memory_create':
        final m = memories.byLocalId('${op.payload['local_id']}');
        if (m == null || m.remoteId != null) return true;
        final visit = m.visitKey == null ? null : passport.byKey(m.visitKey!);
        final json = await api.post('me/memories', {
          if (m.title != null) 'title': m.title,
          'body': m.body,
          'happened_on': m.happenedOn.toIso8601String().substring(0, 10),
          if (m.templeId != null) 'temple_id': m.templeId,
          if (visit?.remoteId != null) 'devotee_visit_id': visit!.remoteId,
          'is_private': m.isPrivate,
        });
        await memories.setRemoteId(m.localId, RemoteMemory.fromJson(json['data'] as Map<String, dynamic>).id);
        return true;
      case 'memory_update':
        final m = memories.byLocalId('${op.payload['local_id']}');
        if (m == null || m.remoteId == null) return true;
        await api.patch('me/memories/${m.remoteId}', {'title': m.title, 'body': m.body, 'happened_on': m.happenedOn.toIso8601String().substring(0, 10), 'is_private': m.isPrivate});
        return true;
      case 'memory_delete':
        await api.delete('me/memories/${op.payload['remote_id']}');
        return true;
      case 'yatra_push':
        final y = yatras.byId('${op.payload['local_id']}');
        if (y == null) return true;
        final body = {
          'title': y.name,
          'status': y.serverStatus,
          if (y.startDate != null) 'starts_on': y.startDate!.toIso8601String().substring(0, 10),
          if (y.startDate != null) 'ends_on': y.startDate!.add(Duration(days: y.days.length - 1)).toIso8601String().substring(0, 10),
        };
        if (y.remoteId == null) {
          final json = await api.post('me/yatras', body);
          await yatras.setRemoteId(y.id, RemoteYatra.fromJson(json['data'] as Map<String, dynamic>).id);
        } else {
          await api.patch('me/yatras/${y.remoteId}', body);
        }
        final id = y.remoteId!;
        final remote = RemoteYatra.fromJson((await api.get('me/yatras/$id'))['data'] as Map<String, dynamic>);
        final localSlugs = <String>{};
        for (var d = 0; d < y.days.length; d++) {
          for (final st in y.days[d].stops) {
            localSlugs.add(st.slug);
            await api.put('me/yatras/$id/temples/${st.slug}', {'day_number': d + 1});
          }
        }
        for (final rs in remote.stops) {
          if (rs.templeSlug != null && !localSlugs.contains(rs.templeSlug)) await api.delete('me/yatras/$id/temples/${rs.templeSlug}');
        }
        return true;
      case 'yatra_delete':
        await api.delete('me/yatras/${op.payload['remote_id']}');
        return true;
      case 'support_create':
        final s = submissions.all.where((x) => x.id == '${op.payload['local_id']}').firstOrNull;
        if (s == null || s.sent) return true;
        final json = await api.post('support', {
          'kind': s.kind == 'correction' && s.templeId != null ? 'report' : 'support',
          'category': s.category,
          'subject': s.subject,
          'body': s.text,
          if (!auth.isSignedIn) 'name': s.reporterName ?? 'Devotee',
          if (!auth.isSignedIn && s.reporterEmail != null) 'email': s.reporterEmail,
          if (s.templeId != null) 'about_type': 'temple',
          if (s.templeId != null) 'about_id': s.templeId,
        });
        await submissions.setTicket(s.id, SupportTicket.fromJson(json['data'] as Map<String, dynamic>));
        return true;
      default:
        return true;
    }
  }

  /// Pulls the account into the device. Quiet on failure: the device copy
  /// is always usable on its own.
  Future<void> pull() async {
    try {
      await settings.loadLanguages(api);
    } catch (_) {}
    if (!auth.isSignedIn) return;
    try {
      final results = await Future.wait<Map<String, dynamic>>([
        api.get('me/passport'),
        api.get('me/visits'),
        api.get('me/yatras'),
        api.get('me/memories'),
        api.get('me/photos'),
        api.get('me/support'),
      ]);
      passport.summary = PassportSummary.fromJson(results[0]['data'] as Map<String, dynamic>);
      await passport.mergeRemote((results[1]['data'] as List).map((e) => RemoteVisit.fromJson(e as Map<String, dynamic>)).toList(), deityOf: (slug) => SampleData.bySlug(slug)?.deity?.slug);
      await yatras.mergeRemote((results[2]['data'] as List).map((e) => RemoteYatra.fromJson(e as Map<String, dynamic>)).toList());
      await memories.mergeRemote((results[3]['data'] as List).map((e) => RemoteMemory.fromJson(e as Map<String, dynamic>)).toList());
      remotePhotos = (results[4]['data'] as List).map((e) => VisitPhoto.fromJson(e as Map<String, dynamic>)).toList();
      await submissions.mergeTickets((results[5]['data'] as List).map((e) => SupportTicket.fromJson(e as Map<String, dynamic>)).toList());
      lastPulledAt = DateTime.now();
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
      if (e.isUnauthenticated) await auth.logout();
    } catch (e) {
      lastError = 'Offline';
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString('outbox', jsonEncode(_outbox.map((o) => o.toJson()).toList()));
    notifyListeners();
  }

  @override
  void dispose() {
    auth.removeListener(_onAuthChanged);
    super.dispose();
  }
}

