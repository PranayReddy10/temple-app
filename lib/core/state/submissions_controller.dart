import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A community contribution: a correction to a temple record, or a temple we
/// do not have yet.
///
/// The submissions API is a later backend slice. Until it lands, a
/// submission is kept here and sent to the editors by email from the device,
/// so nothing a devotee typed at a temple gate is lost.
class Submission {
  const Submission({required this.id, required this.kind, required this.templeSlug, required this.templeName, required this.field, required this.text, required this.createdAt, this.sent = false});

  final String id;

  /// 'correction' or 'new_temple'.
  final String kind;
  final String? templeSlug;
  final String templeName;
  final String field;
  final String text;
  final DateTime createdAt;
  final bool sent;

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind, 'slug': templeSlug, 'temple': templeName, 'field': field, 'text': text, 'at': createdAt.toIso8601String(), 'sent': sent};

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: '${j['id']}',
        kind: '${j['kind']}',
        templeSlug: j['slug']?.toString(),
        templeName: '${j['temple']}',
        field: '${j['field']}',
        text: '${j['text']}',
        createdAt: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
        sent: j['sent'] == true,
      );

  Submission markSent() => Submission(id: id, kind: kind, templeSlug: templeSlug, templeName: templeName, field: field, text: text, createdAt: createdAt, sent: true);

  static const fields = ['Timings', 'Pujas and fees', 'Address or location', 'Contact details', 'History or significance', 'Photos', 'Facilities', 'Other'];
}

class SubmissionsController extends ChangeNotifier {
  SubmissionsController(this._prefs) {
    final raw = _prefs.getString('submissions');
    if (raw != null) {
      try {
        _items.addAll((jsonDecode(raw) as List).map((e) => Submission.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final List<Submission> _items = [];

  List<Submission> get all => List.unmodifiable(_items.reversed);

  Future<Submission> add({required String kind, String? templeSlug, required String templeName, required String field, required String text}) async {
    final s = Submission(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), kind: kind, templeSlug: templeSlug, templeName: templeName, field: field, text: text, createdAt: DateTime.now());
    _items.add(s);
    await _save();
    return s;
  }

  Future<void> markSent(String id) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i >= 0) _items[i] = _items[i].markSent();
    await _save();
  }

  Future<void> remove(String id) async {
    _items.removeWhere((s) => s.id == id);
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString('submissions', jsonEncode(_items.map((s) => s.toJson()).toList()));
    notifyListeners();
  }
}
