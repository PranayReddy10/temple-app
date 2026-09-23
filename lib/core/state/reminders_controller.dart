import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// A festival or program the devotee asked to be reminded about.
///
/// Reminders live on the device and surface on Home as the date approaches.
/// Push notifications need the backend's notification service, which is a
/// later slice; until then "Add to calendar" hands the date to the phone's
/// calendar so it can ring.
class Reminder {
  const Reminder({required this.key, required this.title, required this.startsOn, this.templeSlug, this.templeName, this.endsOn});

  final String key;
  final String title;
  final DateTime startsOn;
  final DateTime? endsOn;
  final String? templeSlug;
  final String? templeName;

  int get daysAway => DateTime(startsOn.year, startsOn.month, startsOn.day).difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays;
  bool get isPast => (endsOn ?? startsOn).isBefore(DateTime.now().subtract(const Duration(days: 1)));

  Map<String, dynamic> toJson() => {'key': key, 'title': title, 'starts': startsOn.toIso8601String(), 'ends': endsOn?.toIso8601String(), 'slug': templeSlug, 'temple': templeName};

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        key: '${j['key']}',
        title: '${j['title']}',
        startsOn: DateTime.tryParse('${j['starts']}') ?? DateTime.now(),
        endsOn: j['ends'] == null ? null : DateTime.tryParse('${j['ends']}'),
        templeSlug: j['slug']?.toString(),
        templeName: j['temple']?.toString(),
      );

  static String keyFor(TempleEvent e) => '${e.templeSlug ?? ''}|${e.title}|${e.startsOn ?? ''}';
}

class RemindersController extends ChangeNotifier {
  RemindersController(this._prefs) {
    final raw = _prefs.getString('reminders');
    if (raw != null) {
      try {
        for (final e in jsonDecode(raw) as List) {
          final r = Reminder.fromJson(e as Map<String, dynamic>);
          _items[r.key] = r;
        }
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final Map<String, Reminder> _items = {};

  List<Reminder> get upcoming => _items.values.where((r) => !r.isPast).toList()..sort((a, b) => a.startsOn.compareTo(b.startsOn));
  bool has(TempleEvent e) => _items.containsKey(Reminder.keyFor(e));

  Future<void> toggle(TempleEvent e) async {
    final k = Reminder.keyFor(e);
    if (_items.containsKey(k)) {
      _items.remove(k);
    } else {
      final start = DateTime.tryParse(e.startsOn ?? '');
      if (start == null) return;
      _items[k] = Reminder(key: k, title: e.title, startsOn: start, endsOn: DateTime.tryParse(e.endsOn ?? ''), templeSlug: e.templeSlug, templeName: e.templeName);
    }
    await _prefs.setString('reminders', jsonEncode(_items.values.map((r) => r.toJson()).toList()));
    notifyListeners();
  }

  /// A Google Calendar template link, which every phone calendar can import.
  static Uri calendarLink(TempleEvent e) {
    String d(String? iso, {int addDays = 0}) {
      final dt = (DateTime.tryParse(iso ?? '') ?? DateTime.now()).add(Duration(days: addDays));
      return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}';
    }

    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': [e.title, e.templeName].whereType<String>().join(' · '),
      'dates': '${d(e.startsOn)}/${d(e.endsOn ?? e.startsOn, addDays: 1)}',
      'details': e.description ?? '',
      'location': [e.templeName, e.templeCity].whereType<String>().join(', '),
    });
  }
}
