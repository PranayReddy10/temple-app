import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/day_theme.dart';

/// A member of the devotee's family, sharing the passport.
class FamilyMember {
  const FamilyMember({required this.id, required this.name, required this.relation, required this.colorIndex});

  final String id;
  final String name;
  final String relation;

  /// Index into the weekday palette, so each member has a deity colour.
  final int colorIndex;

  Color get color => DayTheme.all[colorIndex % 7].accent;
  String get initials => name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.isEmpty ? '' : w[0].toUpperCase()).join();

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'relation': relation, 'color': colorIndex};

  factory FamilyMember.fromJson(Map<String, dynamic> j) => FamilyMember(
        id: '${j['id']}',
        name: '${j['name']}',
        relation: '${j['relation'] ?? ''}',
        colorIndex: (j['color'] as num?)?.toInt() ?? 0,
      );

  FamilyMember copyWith({String? name, String? relation, int? colorIndex}) => FamilyMember(id: id, name: name ?? this.name, relation: relation ?? this.relation, colorIndex: colorIndex ?? this.colorIndex);
}

/// Family Passport: members kept on the device; check-ins can name who came.
class FamilyController extends ChangeNotifier {
  FamilyController(this._prefs) {
    final raw = _prefs.getString('family');
    if (raw != null) {
      try {
        _members.addAll((jsonDecode(raw) as List).map((e) => FamilyMember.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final List<FamilyMember> _members = [];

  static const relations = ['Spouse', 'Mother', 'Father', 'Son', 'Daughter', 'Brother', 'Sister', 'Grandparent', 'Grandchild', 'Friend', 'Other'];

  List<FamilyMember> get members => List.unmodifiable(_members);
  FamilyMember? byId(String id) => _members.where((m) => m.id == id).firstOrNull;

  Future<FamilyMember> add(String name, String relation) async {
    final m = FamilyMember(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), name: name, relation: relation, colorIndex: _members.length % 7);
    _members.add(m);
    await _save();
    return m;
  }

  Future<void> update(FamilyMember m) async {
    final i = _members.indexWhere((x) => x.id == m.id);
    if (i >= 0) _members[i] = m;
    await _save();
  }

  Future<void> remove(String id) async {
    _members.removeWhere((m) => m.id == id);
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString('family', jsonEncode(_members.map((m) => m.toJson()).toList()));
    notifyListeners();
  }
}
