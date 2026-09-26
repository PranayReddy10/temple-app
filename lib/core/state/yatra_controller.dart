import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/temple_repository.dart';
import '../models/models.dart';

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

  /// Road-free estimate: great-circle distance between consecutive stops.
  double get distanceKm => YatraPlanner.pathKm(stops);

  Map<String, dynamic> toJson() => {'title': title, 'stops': stops.map((s) => s.toJson()).toList()};

  factory YatraDay.fromJson(Map<String, dynamic> j) => YatraDay(
        title: '${j['title']}',
        stops: (j['stops'] as List? ?? const []).map((e) => YatraStop.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class Yatra {
  Yatra({required this.id, required this.name, required this.createdAt, this.startDate, List<YatraDay>? days, this.deitySlug, this.active = false, this.remoteId})
      : days = days ?? [YatraDay(title: 'Day 1')];

  final String id;

  /// Set once `/me/yatras` holds it.
  int? remoteId;
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
  double get distanceKm => days.fold(0.0, (n, d) => n + d.distanceKm) + YatraPlanner.betweenDaysKm(days);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'created': createdAt.toIso8601String(),
        'start': startDate?.toIso8601String(),
        'days': days.map((d) => d.toJson()).toList(),
        'deity': deitySlug,
        'active': active,
        'remote_id': remoteId,
      };

  /// The server's status word for this trip.
  String get serverStatus => isComplete ? 'completed' : active ? 'in_progress' : 'planning';

  factory Yatra.fromJson(Map<String, dynamic> j) => Yatra(
        id: '${j['id']}',
        name: '${j['name']}',
        createdAt: DateTime.tryParse('${j['created']}') ?? DateTime.now(),
        startDate: j['start'] == null ? null : DateTime.tryParse('${j['start']}'),
        days: (j['days'] as List? ?? const []).map((e) => YatraDay.fromJson(e as Map<String, dynamic>)).toList(),
        deitySlug: j['deity']?.toString(),
        active: j['active'] == true,
        remoteId: (j['remote_id'] as num?)?.toInt(),
      );
}

/// Route planning helpers. Straight-line distances only: they are honest
/// about being estimates and need no map service on the road.
class YatraPlanner {
  YatraPlanner._();

  static double pathKm(List<YatraStop> stops) {
    var km = 0.0;
    for (var i = 1; i < stops.length; i++) {
      km += _km(stops[i - 1], stops[i]);
    }
    return km;
  }

  static double betweenDaysKm(List<YatraDay> days) {
    var km = 0.0;
    YatraStop? last;
    for (final d in days) {
      if (d.stops.isEmpty) continue;
      if (last != null) km += _km(last, d.stops.first);
      last = d.stops.last;
    }
    return km;
  }

  static double _km(YatraStop a, YatraStop b) {
    if (a.lat == null || a.lng == null || b.lat == null || b.lng == null) return 0;
    return TempleRepository.distanceKm(a.lat!, a.lng!, b.lat!, b.lng!);
  }

  /// Nearest-neighbour order from [start] (or the first stop), then a
  /// 2-opt pass to untangle crossings. Stops without coordinates keep their
  /// relative order at the end.
  static List<YatraStop> optimise(List<YatraStop> stops, {YatraStop? start}) {
    final located = stops.where((s) => s.lat != null && s.lng != null).toList();
    final unlocated = stops.where((s) => s.lat == null || s.lng == null).toList();
    if (located.length < 3) return [...located, ...unlocated];
    final route = <YatraStop>[];
    final remaining = [...located];
    var current = start != null && remaining.contains(start) ? start : remaining.first;
    remaining.remove(current);
    route.add(current);
    while (remaining.isNotEmpty) {
      remaining.sort((a, b) => _km(current, a).compareTo(_km(current, b)));
      current = remaining.removeAt(0);
      route.add(current);
    }
    // 2-opt.
    var improved = true;
    while (improved) {
      improved = false;
      for (var i = 1; i < route.length - 1; i++) {
        for (var j = i + 1; j < route.length; j++) {
          final before = _km(route[i - 1], route[i]) + (j + 1 < route.length ? _km(route[j], route[j + 1]) : 0);
          final after = _km(route[i - 1], route[j]) + (j + 1 < route.length ? _km(route[i], route[j + 1]) : 0);
          if (after + 0.01 < before) {
            route.replaceRange(i, j + 1, route.sublist(i, j + 1).reversed.toList());
            improved = true;
          }
        }
      }
    }
    return [...route, ...unlocated];
  }

  /// Splits an ordered route into days, starting a new day when the day's
  /// distance would pass [maxKmPerDay] or it already holds [maxStopsPerDay].
  static List<List<YatraStop>> splitIntoDays(List<YatraStop> ordered, {double maxKmPerDay = 250, int maxStopsPerDay = 3}) {
    final days = <List<YatraStop>>[];
    var day = <YatraStop>[];
    var km = 0.0;
    for (final s in ordered) {
      final add = day.isEmpty ? 0.0 : _km(day.last, s);
      if (day.isNotEmpty && (day.length >= maxStopsPerDay || km + add > maxKmPerDay)) {
        days.add(day);
        day = [];
        km = 0;
      }
      if (day.isNotEmpty) km += add;
      day.add(s);
    }
    if (day.isNotEmpty) days.add(day);
    return days;
  }
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

  /// Forgets everything kept on this device, for signing out: the next
  /// person to use the phone must not see, or sync into their own account,
  /// what the last one recorded.
  Future<void> clearAll() async {
    _yatras.clear();
    await _prefs.remove('yatras');
    notifyListeners();
  }

  /// Sync hooks: a trip changed (create, edit, stops), a trip was deleted.
  Future<void> Function(Yatra y)? onChanged;
  Future<void> Function(int remoteId)? onDeleted;

  List<Yatra> get yatras => List.unmodifiable(_yatras);
  Yatra? get active => _yatras.where((y) => y.active).firstOrNull;
  Yatra? byId(String id) => _yatras.where((y) => y.id == id).firstOrNull;

  Future<Yatra> create(String name, {String? deitySlug, DateTime? startDate}) async {
    final y = Yatra(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), name: name, createdAt: DateTime.now(), deitySlug: deitySlug, startDate: startDate);
    _yatras.add(y);
    await save(changed: y);
    return y;
  }

  Future<void> delete(Yatra y) async {
    _yatras.remove(y);
    await save();
    if (y.remoteId != null) await onDeleted?.call(y.remoteId!);
  }

  Future<void> setRemoteId(String localId, int remoteId) async {
    byId(localId)?.remoteId = remoteId;
    await _persist();
  }

  /// Imports trips the account has that this device does not, and lets the
  /// server mark stops done where it has recorded the visit.
  Future<void> mergeRemote(List<RemoteYatra> remote) async {
    var changed = false;
    for (final r in remote) {
      final local = _yatras.where((y) => y.remoteId == r.id).firstOrNull;
      if (local != null) {
        for (final d in local.days) {
          for (var i = 0; i < d.stops.length; i++) {
            final rs = r.stops.where((x) => x.templeSlug == d.stops[i].slug).firstOrNull;
            if (rs != null && rs.isVisited && !d.stops[i].done) {
              d.stops[i] = d.stops[i].copyWith(done: true);
              changed = true;
            }
          }
        }
        continue;
      }
      final dayCount = r.stops.isEmpty ? 1 : r.stops.map((x) => x.dayNumber).reduce((a, b) => a > b ? a : b);
      final days = [for (var d = 1; d <= dayCount; d++) YatraDay(title: 'Day $d')];
      for (final st in r.stops..sort((a, b) => a.dayNumber != b.dayNumber ? a.dayNumber.compareTo(b.dayNumber) : a.sortOrder.compareTo(b.sortOrder))) {
        if (st.templeSlug == null) continue;
        days[(st.dayNumber - 1).clamp(0, dayCount - 1)].stops.add(YatraStop(slug: st.templeSlug!, name: st.templeName ?? st.templeSlug!, city: st.city, done: st.isVisited));
      }
      _yatras.add(Yatra(
        id: 'remote-${r.id}',
        name: r.title,
        createdAt: DateTime.now(),
        startDate: r.startsOn == null ? null : DateTime.tryParse(r.startsOn!),
        days: days,
        active: r.status == 'in_progress',
        remoteId: r.id,
      ));
      changed = true;
    }
    if (changed) await _persist();
  }

  Future<void> addStop(Yatra y, int dayIndex, YatraStop stop) async {
    if (y.allStops.any((s) => s.slug == stop.slug)) return;
    y.days[dayIndex].stops.add(stop);
    await save(changed: y);
  }

  Future<void> removeStop(Yatra y, YatraStop stop) async {
    for (final d in y.days) {
      d.stops.removeWhere((s) => s.slug == stop.slug);
    }
    await save(changed: y);
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
    await save(changed: y);
  }

  Future<void> addDay(Yatra y) async {
    y.days.add(YatraDay(title: 'Day ${y.days.length + 1}'));
    await save(changed: y);
  }

  Future<void> removeDay(Yatra y, int index) async {
    if (y.days.length <= 1) return;
    y.days.removeAt(index);
    for (var i = 0; i < y.days.length; i++) {
      y.days[i].title = 'Day ${i + 1}';
    }
    await save(changed: y);
  }

  /// Reorders every stop into the shortest straight-line route, keeping the
  /// current day boundaries by count.
  Future<void> optimise(Yatra y) async {
    final all = y.allStops.toList();
    final ordered = YatraPlanner.optimise(all);
    final counts = y.days.map((d) => d.stops.length).toList();
    var i = 0;
    for (var d = 0; d < y.days.length; d++) {
      y.days[d].stops
        ..clear()
        ..addAll(ordered.skip(i).take(counts[d]));
      i += counts[d];
    }
    await save(changed: y);
  }

  /// Re-plans the whole yatra: optimal order, then split into days.
  Future<void> autoPlan(Yatra y, {double maxKmPerDay = 250, int maxStopsPerDay = 3}) async {
    final ordered = YatraPlanner.optimise(y.allStops.toList());
    final split = YatraPlanner.splitIntoDays(ordered, maxKmPerDay: maxKmPerDay, maxStopsPerDay: maxStopsPerDay);
    y.days.clear();
    for (var i = 0; i < split.length; i++) {
      y.days.add(YatraDay(title: 'Day ${i + 1}', stops: split[i]));
    }
    if (y.days.isEmpty) y.days.add(YatraDay(title: 'Day 1'));
    await save(changed: y);
  }

  Future<void> setActive(Yatra y, bool value) async {
    for (final other in _yatras) {
      other.active = false;
    }
    y.active = value;
    await save(changed: y);
  }

  Future<void> save({Yatra? changed}) async {
    await _persist();
    if (changed != null) await onChanged?.call(changed);
  }

  Future<void> _persist() async {
    await _prefs.setString('yatras', jsonEncode(_yatras.map((y) => y.toJson()).toList()));
    notifyListeners();
  }
}
