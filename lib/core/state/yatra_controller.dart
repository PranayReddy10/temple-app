import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One stop on a yatra: a temple by slug, with its display name kept so the
/// plan is readable offline.
class YatraStop {
  const YatraStop({required this.slug, required this.name, this.city, this.deitySlug, this.lat, this.lng, this.done = false});

  final String slug;
  final String name;
  final String? city;
  final String? deitySlug;
  final double? lat;
  final double? lng;
  final bool done;

  YatraStop copyWith({bool? done}) => YatraStop(slug: slug, name: name, city: city, deitySlug: deitySlug, lat: lat, lng: lng, done: done ?? this.done);

  Map<String, dynamic> toJson() => {'slug': slug, 'name': name, 'city': city, 'deity': deitySlug, 'lat': lat, 'lng': lng, 'done': done};

  factory YatraStop.fromJson(Map<String, dynamic> j) => YatraStop(
        slug: '${j['slug']}',
        name: '${j['name']}',
        city: j['city']?.toString(),
        deitySlug: j['deity']?.toString(),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        done: j['done'] == true,
      );
}

class YatraDay {
  YatraDay({required this.title, List<YatraStop>? stops}) : stops = stops ?? [];

  String title;
  final List<YatraStop> stops;

  Map<String, dynamic> toJson() => {'title': title, 'stops': stops.map((s) => s.toJson()).toList()};

  factory YatraDay.fromJson(Map<String, dynamic> j) => YatraDay(
        title: '${j['title']}',
        stops: (j['stops'] as List? ?? const []).map((e) => YatraStop.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class Yatra {
  Yatra({required this.id, required this.name, required this.createdAt, this.startDate, List<YatraDay>? days, this.deitySlug, this.active = false})
      : days = days ?? [YatraDay(title: 'Day 1')];

  final String id;
  String name;
  final DateTime createdAt;
  DateTime? startDate;
  final List<YatraDay> days;
  String? deitySlug;
  bool active;

  int get stopCount => days.fold(0, (n, d) => n + d.stops.length);
  int get doneCount => days.fold(0, (n, d) => n + d.stops.where((s) => s.done).length);
  bool get isComplete => stopCount > 0 && doneCount == stopCount;
  double get progress => stopCount == 0 ? 0 : doneCount / stopCount;
  Iterable<YatraStop> get allStops => days.expand((d) => d.stops);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created': createdAt.toIso8601String(),
        'start': startDate?.toIso8601String(),
        'days': days.map((d) => d.toJson()).toList(),
        'deity': deitySlug,
        'active': active,
      };

  factory Yatra.fromJson(Map<String, dynamic> j) => Yatra(
        id: '${j['id']}',
        name: '${j['name']}',
        createdAt: DateTime.tryParse('${j['created']}') ?? DateTime.now(),
        startDate: j['start'] == null ? null : DateTime.tryParse('${j['start']}'),
        days: (j['days'] as List? ?? const []).map((e) => YatraDay.fromJson(e as Map<String, dynamic>)).toList(),
        deitySlug: j['deity']?.toString(),
        active: j['active'] == true,
      );
}

class YatraController extends ChangeNotifier {
  YatraController(this._prefs) {
    final raw = _prefs.getString('yatras');
    if (raw != null) {
      try {
        _yatras.addAll((jsonDecode(raw) as List).map((e) => Yatra.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final List<Yatra> _yatras = [];

  List<Yatra> get yatras => List.unmodifiable(_yatras);
  Yatra? get active => _yatras.where((y) => y.active).firstOrNull;
  Yatra? byId(String id) => _yatras.where((y) => y.id == id).firstOrNull;

  Future<Yatra> create(String name, {String? deitySlug, DateTime? startDate}) async {
    final y = Yatra(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), name: name, createdAt: DateTime.now(), deitySlug: deitySlug, startDate: startDate);
    _yatras.add(y);
    await save();
    return y;
  }

  Future<void> delete(Yatra y) async {
    _yatras.remove(y);
    await save();
  }

  Future<void> addStop(Yatra y, int dayIndex, YatraStop stop) async {
    if (y.allStops.any((s) => s.slug == stop.slug)) return;
    y.days[dayIndex].stops.add(stop);
    await save();
  }

  Future<void> removeStop(Yatra y, YatraStop stop) async {
    for (final d in y.days) {
      d.stops.removeWhere((s) => s.slug == stop.slug);
    }
    await save();
  }

  Future<void> toggleDone(Yatra y, YatraStop stop) async {
    for (final d in y.days) {
      final i = d.stops.indexWhere((s) => s.slug == stop.slug);
      if (i >= 0) d.stops[i] = stop.copyWith(done: !stop.done);
    }
    await save();
  }

  Future<void> reorder(Yatra y, int dayIndex, int oldIndex, int newIndex) async {
    final stops = y.days[dayIndex].stops;
    if (newIndex > oldIndex) newIndex -= 1;
    final s = stops.removeAt(oldIndex);
    stops.insert(newIndex, s);
    await save();
  }

  Future<void> addDay(Yatra y) async {
    y.days.add(YatraDay(title: 'Day ${y.days.length + 1}'));
    await save();
  }

  Future<void> removeDay(Yatra y, int index) async {
    if (y.days.length <= 1) return;
    y.days.removeAt(index);
    for (var i = 0; i < y.days.length; i++) {
      y.days[i].title = 'Day ${i + 1}';
    }
    await save();
  }

  Future<void> setActive(Yatra y, bool value) async {
    for (final other in _yatras) {
      other.active = false;
    }
    y.active = value;
    await save();
  }

  Future<void> save() async {
    await _prefs.setString('yatras', jsonEncode(_yatras.map((y) => y.toJson()).toList()));
    notifyListeners();
  }
}
