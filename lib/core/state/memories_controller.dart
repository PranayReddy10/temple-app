import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// A devotee's own writing about a visit. Private by default, kept on the
/// device, and mirrored to `/me/memories` when signed in.
class MemoryEntry {
  const MemoryEntry({required this.localId, this.remoteId, this.title, required this.body, required this.happenedOn, this.templeSlug, this.templeName, this.templeId, this.visitKey, this.isPrivate = true, required this.updatedAt});

  final String localId;
  final int? remoteId;
  final String? title;
  final String body;
  final DateTime happenedOn;
  final String? templeSlug;
  final String? templeName;
  final int? templeId;
  final String? visitKey;
  final bool isPrivate;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {'id': localId, 'remote_id': remoteId, 'title': title, 'body': body, 'on': happenedOn.toIso8601String(), 'slug': templeSlug, 'temple': templeName, 'temple_id': templeId, 'visit': visitKey, 'private': isPrivate, 'updated': updatedAt.toIso8601String()};

  factory MemoryEntry.fromJson(Map<String, dynamic> j) => MemoryEntry(
        localId: '${j['id']}',
        remoteId: (j['remote_id'] as num?)?.toInt(),
        title: j['title']?.toString(),
        body: '${j['body'] ?? ''}',
        happenedOn: DateTime.tryParse('${j['on']}') ?? DateTime.now(),
        templeSlug: j['slug']?.toString(),
        templeName: j['temple']?.toString(),
        templeId: (j['temple_id'] as num?)?.toInt(),
        visitKey: j['visit']?.toString(),
        isPrivate: j['private'] == null ? true : j['private'] == true,
        updatedAt: DateTime.tryParse('${j['updated']}') ?? DateTime.now(),
      );

  MemoryEntry copyWith({int? remoteId, String? title, String? body, DateTime? happenedOn, bool? isPrivate}) => MemoryEntry(
        localId: localId,
        remoteId: remoteId ?? this.remoteId,
        title: title ?? this.title,
        body: body ?? this.body,
        happenedOn: happenedOn ?? this.happenedOn,
        templeSlug: templeSlug,
        templeName: templeName,
        templeId: templeId,
        visitKey: visitKey,
        isPrivate: isPrivate ?? this.isPrivate,
        updatedAt: DateTime.now(),
      );
}

class MemoriesController extends ChangeNotifier {
  MemoriesController(this._prefs) {
    final raw = _prefs.getString('memories');
    if (raw != null) {
      try {
        _items.addAll((jsonDecode(raw) as List).map((e) => MemoryEntry.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final List<MemoryEntry> _items = [];

  Future<void> Function(MemoryEntry m)? onCreated;
  Future<void> Function(MemoryEntry m)? onUpdated;
  Future<void> Function(int remoteId)? onDeleted;

  List<MemoryEntry> get all => List.unmodifiable([..._items]..sort((a, b) => b.happenedOn.compareTo(a.happenedOn)));
  MemoryEntry? byLocalId(String id) => _items.where((m) => m.localId == id).firstOrNull;

  Future<MemoryEntry> add({String? title, required String body, required DateTime happenedOn, String? templeSlug, String? templeName, int? templeId, String? visitKey, bool isPrivate = true}) async {
    final m = MemoryEntry(localId: DateTime.now().microsecondsSinceEpoch.toRadixString(36), title: title, body: body, happenedOn: happenedOn, templeSlug: templeSlug, templeName: templeName, templeId: templeId, visitKey: visitKey, isPrivate: isPrivate, updatedAt: DateTime.now());
    _items.add(m);
    await _save();
    await onCreated?.call(m);
    return m;
  }

  Future<void> update(MemoryEntry m) async {
    final i = _items.indexWhere((x) => x.localId == m.localId);
    if (i < 0) return;
    _items[i] = m;
    await _save();
    await onUpdated?.call(m);
  }

  Future<void> remove(MemoryEntry m) async {
    _items.removeWhere((x) => x.localId == m.localId);
    await _save();
    if (m.remoteId != null) await onDeleted?.call(m.remoteId!);
  }

  Future<void> setRemoteId(String localId, int remoteId) async {
    final i = _items.indexWhere((x) => x.localId == localId);
    if (i < 0) return;
    _items[i] = _items[i].copyWith(remoteId: remoteId);
    await _save();
  }

  Future<void> mergeRemote(List<RemoteMemory> remote) async {
    var changed = false;
    for (final r in remote) {
      if (_items.any((m) => m.remoteId == r.id)) continue;
      _items.add(MemoryEntry(
        localId: 'remote-${r.id}',
        remoteId: r.id,
        title: r.title,
        body: r.body,
        happenedOn: DateTime.tryParse(r.happenedOn ?? '') ?? DateTime.now(),
        templeSlug: r.templeSlug,
        templeName: r.templeName,
        templeId: r.templeId,
        isPrivate: r.isPrivate,
        updatedAt: DateTime.now(),
      ));
      changed = true;
    }
    if (changed) await _save();
  }

  Future<void> _save() async {
    await _prefs.setString('memories', jsonEncode(_items.map((m) => m.toJson()).toList()));
    notifyListeners();
  }
}
