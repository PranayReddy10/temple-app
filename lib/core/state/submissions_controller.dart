import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// A report or a suggestion filed with the editors through `/support`.
///
/// Filing needs no account, so a report written at a temple gate with no
/// signal is kept here and sent when the device is next online. The
/// reference the server returns is the handle to quote afterwards.
class Submission {
  const Submission({required this.id, required this.kind, this.templeSlug, this.templeId, required this.templeName, required this.field, required this.text, required this.createdAt, this.reference, this.status, this.statusLabel, this.replies = const [], this.resolution, this.reporterName, this.reporterEmail});

  final String id;

  /// 'correction' (a report about a temple) or 'new_temple' (a suggestion).
  final String kind;
  final String? templeSlug;
  final int? templeId;
  final String templeName;
  final String field;
  final String text;
  final DateTime createdAt;
  final String? reference;
  final String? status;
  final String? statusLabel;
  final List<SupportMessage> replies;
  final String? resolution;
  final String? reporterName;
  final String? reporterEmail;

  bool get sent => reference != null;

  /// The support category the server understands.
  String get category => kind == 'new_temple' ? 'suggestion' : 'wrong_information';
  String get subject => kind == 'new_temple' ? 'New temple: $templeName' : '$field at $templeName';

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind, 'slug': templeSlug, 'temple_id': templeId, 'temple': templeName, 'field': field, 'text': text, 'at': createdAt.toIso8601String(), 'ref': reference, 'status': status, 'status_label': statusLabel, 'resolution': resolution, 'name': reporterName, 'email': reporterEmail};

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: '${j['id']}',
        kind: '${j['kind']}',
        templeSlug: j['slug']?.toString(),
        templeId: (j['temple_id'] as num?)?.toInt(),
        templeName: '${j['temple']}',
        field: '${j['field']}',
        text: '${j['text']}',
        createdAt: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
        reference: j['ref']?.toString(),
        status: j['status']?.toString(),
        statusLabel: j['status_label']?.toString(),
        resolution: j['resolution']?.toString(),
        reporterName: j['name']?.toString(),
        reporterEmail: j['email']?.toString(),
      );

  Submission withTicket(SupportTicket t) => Submission(id: id, kind: kind, templeSlug: templeSlug, templeId: templeId, templeName: templeName, field: field, text: text, createdAt: createdAt, reference: t.reference, status: t.status, statusLabel: t.statusLabel, replies: t.messages, resolution: t.resolution, reporterName: reporterName, reporterEmail: reporterEmail);

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

  Future<void> Function(Submission s)? onCreated;

  List<Submission> get all => List.unmodifiable(_items.reversed);
  List<Submission> get pending => _items.where((s) => !s.sent).toList();

  Future<Submission> add({required String kind, String? templeSlug, int? templeId, required String templeName, required String field, required String text, String? reporterName, String? reporterEmail}) async {
    final s = Submission(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), kind: kind, templeSlug: templeSlug, templeId: templeId, templeName: templeName, field: field, text: text, createdAt: DateTime.now(), reporterName: reporterName, reporterEmail: reporterEmail);
    _items.add(s);
    await _save();
    await onCreated?.call(s);
    return s;
  }

  Future<void> setTicket(String id, SupportTicket t) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _items[i] = _items[i].withTicket(t);
    await _save();
  }

  /// Refreshes status and replies for the tickets we know by reference.
  Future<void> mergeTickets(List<SupportTicket> tickets) async {
    var changed = false;
    for (final t in tickets) {
      final i = _items.indexWhere((s) => s.reference == t.reference);
      if (i >= 0) {
        _items[i] = _items[i].withTicket(t);
        changed = true;
      }
    }
    if (changed) await _save();
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
