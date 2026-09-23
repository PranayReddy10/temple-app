import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A seva or puja the devotee booked through the temple's official route.
///
/// The app never takes payment. A booking here is the devotee's own record
/// (reference, date, people) so the details are at hand at the counter.
class SevaBooking {
  const SevaBooking({required this.id, required this.templeSlug, required this.templeName, required this.pujaName, required this.date, this.reference, this.people = 1, this.note, this.isOfficial = false});

  final String id;
  final String templeSlug;
  final String templeName;
  final String pujaName;
  final DateTime date;
  final String? reference;
  final int people;
  final String? note;
  final bool isOfficial;

  bool get isPast => date.isBefore(DateTime.now().subtract(const Duration(days: 1)));

  Map<String, dynamic> toJson() => {'id': id, 'slug': templeSlug, 'temple': templeName, 'puja': pujaName, 'date': date.toIso8601String(), 'ref': reference, 'people': people, 'note': note, 'official': isOfficial};

  factory SevaBooking.fromJson(Map<String, dynamic> j) => SevaBooking(
        id: '${j['id']}',
        templeSlug: '${j['slug']}',
        templeName: '${j['temple']}',
        pujaName: '${j['puja']}',
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        reference: j['ref']?.toString(),
        people: (j['people'] as num?)?.toInt() ?? 1,
        note: j['note']?.toString(),
        isOfficial: j['official'] == true,
      );
}

class BookingsController extends ChangeNotifier {
  BookingsController(this._prefs) {
    final raw = _prefs.getString('bookings');
    if (raw != null) {
      try {
        _items.addAll((jsonDecode(raw) as List).map((e) => SevaBooking.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final List<SevaBooking> _items = [];

  List<SevaBooking> get all => List.unmodifiable(_items..sort((a, b) => a.date.compareTo(b.date)));
  List<SevaBooking> get upcoming => all.where((b) => !b.isPast).toList();

  Future<void> add(SevaBooking b) async {
    _items.add(b);
    await _save();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((b) => b.id == id);
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString('bookings', jsonEncode(_items.map((b) => b.toJson()).toList()));
    notifyListeners();
  }
}
