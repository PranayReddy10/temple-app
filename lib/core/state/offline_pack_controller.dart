import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/temple_repository.dart';
import 'yatra_controller.dart';

/// Offline trip packs: the full profile of every temple on a yatra, kept on
/// the device so the pages open with no signal on the road.
class OfflinePackController extends ChangeNotifier {
  OfflinePackController(this._prefs, this._repo) {
    final raw = _prefs.getString('offline_packs');
    if (raw != null) {
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in m.entries) {
          _packs[e.key] = (e.value as List).map((x) => '$x').toList();
        }
      } catch (_) {}
    }
    final store = _prefs.getString('offline_temples');
    if (store != null) {
      try {
        final m = jsonDecode(store) as Map<String, dynamic>;
        for (final e in m.entries) {
          _repo.packed[e.key] = e.value as Map<String, dynamic>;
        }
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final TempleRepository _repo;
  final Map<String, List<String>> _packs = {};
  final Set<String> _downloading = {};

  /// Forgets every pack, for signing out: packs belong to the last
  /// person's trips, which sign-out removes, and were fetched with their
  /// account, their reviews and follows included.
  Future<void> clearAll() async {
    _packs.clear();
    _downloading.clear();
    _repo.clearPersonal();
    await _prefs.remove('offline_packs');
    await _prefs.remove('offline_temples');
    notifyListeners();
  }

  bool hasPack(String yatraId) => _packs.containsKey(yatraId);
  bool isDownloading(String yatraId) => _downloading.contains(yatraId);
  int packedTemples(String yatraId) => (_packs[yatraId] ?? const []).where(_repo.packed.containsKey).length;
  int get totalPacked => _repo.packed.length;

  /// Fetches and stores every stop's full profile. Returns how many failed.
  Future<int> download(Yatra y) async {
    _downloading.add(y.id);
    notifyListeners();
    var failed = 0;
    final slugs = <String>[];
    try {
      for (final stop in y.allStops) {
        slugs.add(stop.slug);
        final ok = await _repo.fetchRaw(stop.slug);
        if (!ok) failed++;
      }
      _packs[y.id] = slugs;
      await _persist();
    } finally {
      _downloading.remove(y.id);
      notifyListeners();
    }
    return failed;
  }

  Future<void> remove(String yatraId) async {
    final slugs = _packs.remove(yatraId) ?? const [];
    final stillNeeded = _packs.values.expand((e) => e).toSet();
    for (final s in slugs) {
      if (!stillNeeded.contains(s)) _repo.packed.remove(s);
    }
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _prefs.setString('offline_packs', jsonEncode(_packs));
    await _prefs.setString('offline_temples', jsonEncode(_repo.packed));
  }
}
