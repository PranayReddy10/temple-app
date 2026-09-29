import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// Each temple's cover photo, by slug, wherever the app has seen it.
///
/// A visit, a booking, a yatra stop or a review names a temple but does not
/// always carry its photo; the temple lists and pages do. Every answer that
/// includes a cover is remembered here (and kept across launches), so any
/// screen that names a temple can show its cover instead of a symbol.
class TempleCovers extends ChangeNotifier {
  TempleCovers._();

  static final TempleCovers instance = TempleCovers._();

  static const _key = 'temple_covers_v1';
  static const _max = 600;

  final Map<String, Photo> _bySlug = {};
  SharedPreferences? _prefs;
  Timer? _save;

  Photo? of(String? slug) => slug == null ? null : _bySlug[slug];

  /// Loads what earlier launches saw.
  void attach(SharedPreferences prefs) {
    _prefs = prefs;
    try {
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final map = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      map.forEach((slug, v) {
        final u = List<String?>.from(v as List);
        _bySlug[slug] = Photo(thumbnail: u.elementAtOrNull(0), medium: u.elementAtOrNull(1), original: u.elementAtOrNull(2));
      });
    } catch (_) {
      // A corrupt cache is only a cache.
    }
  }

  static void remember(String? slug, Photo? photo) {
    if (slug == null || slug.isEmpty || photo == null || photo.candidates.isEmpty) return;
    final self = instance;
    final old = self._bySlug[slug];
    if (old != null && old.medium == photo.medium && old.original == photo.original && old.thumbnail == photo.thumbnail) return;
    self._bySlug.remove(slug);
    self._bySlug[slug] = Photo(thumbnail: photo.thumbnail, medium: photo.medium, original: photo.original);
    while (self._bySlug.length > _max) {
      self._bySlug.remove(self._bySlug.keys.first);
    }
    self._scheduleSave();
    // Parsing can happen mid-build; tell listeners afterwards.
    scheduleMicrotask(self.notifyListeners);
  }

  /// Every temple in an API answer that carries its cover: a temple with
  /// `primary_photo` (lists, pages) or a nested one with `cover` (visits,
  /// bookings, yatra stops, reviews). Called on each successful response.
  static void harvest(Object? json, [int depth = 0]) {
    if (depth > 6) return;
    if (json is List) {
      for (final e in json) {
        harvest(e, depth + 1);
      }
      return;
    }
    if (json is! Map) return;
    final slug = json['slug'];
    if (slug is String && slug.isNotEmpty) {
      final primary = json['primary_photo'];
      final cover = json['cover'];
      if (primary is Map) {
        remember(slug, Photo.fromJson(Map<String, dynamic>.from(primary)));
      } else if (cover is Map) {
        String? s(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
        remember(slug, Photo(thumbnail: s(cover['thumbnail']), medium: s(cover['medium']), original: s(cover['original'])));
      }
    }
    for (final v in json.values) {
      if (v is Map || v is List) harvest(v, depth + 1);
    }
  }

  void _scheduleSave() {
    if (_prefs == null) return;
    _save?.cancel();
    _save = Timer(const Duration(seconds: 2), () {
      final out = {for (final e in _bySlug.entries) e.key: [e.value.thumbnail, e.value.medium, e.value.original]};
      _prefs?.setString(_key, jsonEncode(out));
    });
  }

  @visibleForTesting
  void clear() => _bySlug.clear();
}
