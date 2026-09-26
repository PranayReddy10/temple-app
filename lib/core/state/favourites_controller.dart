import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import 'auth_controller.dart';

/// A saved temple, with enough of the summary kept locally to render a card
/// offline and for temples that are not in the bundled sample set.
class SavedTemple {
  const SavedTemple({required this.slug, required this.name, this.city, this.state, this.deitySlug, this.deityName, this.photoUrl, required this.savedAt});

  final String slug;
  final String name;
  final String? city;
  final String? state;
  final String? deitySlug;
  final String? deityName;
  final String? photoUrl;
  final DateTime savedAt;

  TempleSummary toSummary({int? id}) => TempleSummary(
        id: id,
        slug: slug,
        name: name,
        deity: deitySlug == null ? null : DeityRef(slug: deitySlug!, name: deityName ?? deitySlug!),
        location: Location(city: city, state: state),
        trust: const Trust(level: TrustLevel.unverified),
        primaryPhoto: photoUrl == null ? null : Photo(medium: photoUrl),
      );

  Map<String, dynamic> toJson() => {'slug': slug, 'name': name, 'city': city, 'state': state, 'deity': deitySlug, 'deity_name': deityName, 'photo': photoUrl, 'at': savedAt.toIso8601String()};

  factory SavedTemple.fromJson(Map<String, dynamic> j) => SavedTemple(
        slug: '${j['slug']}',
        name: '${j['name'] ?? j['slug']}',
        city: j['city']?.toString(),
        state: j['state']?.toString(),
        deitySlug: j['deity']?.toString(),
        deityName: j['deity_name']?.toString(),
        photoUrl: j['photo']?.toString(),
        savedAt: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
      );

  factory SavedTemple.fromSummary(TempleSummary t) => SavedTemple(
        slug: t.slug,
        name: t.name,
        city: t.location.city,
        state: t.location.state,
        deitySlug: t.deity?.slug,
        deityName: t.deity?.name,
        photoUrl: t.primaryPhoto?.best,
        savedAt: DateTime.now(),
      );
}

/// Saved temples. Local first, mirrored to the account when signed in.
class FavouritesController extends ChangeNotifier {
  FavouritesController(this._prefs, this._auth) {
    final raw = _prefs.getString('favourites_v2');
    if (raw != null) {
      try {
        for (final e in jsonDecode(raw) as List) {
          final s = SavedTemple.fromJson(e as Map<String, dynamic>);
          _items[s.slug] = s;
        }
      } catch (_) {}
    } else {
      // Migrate the slug-only list from the first build.
      for (final slug in _prefs.getStringList('favourites') ?? const <String>[]) {
        _items[slug] = SavedTemple(slug: slug, name: slug, savedAt: DateTime.now());
      }
    }
  }

  final SharedPreferences _prefs;
  final AuthController _auth;
  final Map<String, SavedTemple> _items = {};

  /// Forgets everything kept on this device, for signing out: the next
  /// person to use the phone must not see, or sync into their own account,
  /// what the last one recorded.
  Future<void> clearAll() async {
    _items.clear();
    await _prefs.remove('favourites_v2');
    await _prefs.remove('favourites');
    notifyListeners();
  }

  List<SavedTemple> get items => _items.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  Set<String> get slugs => _items.keys.toSet();
  bool contains(String slug) => _items.containsKey(slug);

  Future<void> toggle(TempleSummary temple) async {
    final nowSaved = !_items.containsKey(temple.slug);
    if (nowSaved) {
      _items[temple.slug] = SavedTemple.fromSummary(temple);
    } else {
      _items.remove(temple.slug);
    }
    await _save();
    await _auth.syncSave(temple.slug, nowSaved);
  }

  Future<void> remove(String slug) async {
    _items.remove(slug);
    await _save();
    await _auth.syncSave(slug, false);
  }

  Future<void> mergeFromAccount() async {
    final remote = await _auth.savedTemples();
    if (remote.isEmpty) return;
    for (final t in remote) {
      _items.putIfAbsent(t.slug, () => SavedTemple.fromSummary(t));
    }
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString('favourites_v2', jsonEncode(_items.values.map((s) => s.toJson()).toList()));
    notifyListeners();
  }
}
