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
  const Submission({required this.id, required this.kind, this.templeSlug, this.templeId, required this.templeName, required this.field, required this.text, required this.createdAt, this.reference, this.status, this.statusLabel, this.replies = const [], this.resolution, this.reporterName, this.reporterEmail, this.customCategory, this.customSubject, this.isOpen = true, this.sendError});

  final String id;

  /// 'correction' (a report about a temple), 'new_temple' (a suggestion),
  /// or 'support' (a request about the app or the account).
  final String kind;

  /// For a support request: the category chosen and the subject typed.
  final String? customCategory;
  final String? customSubject;
  final bool isOpen;
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

  /// Why the server refused it, when it did. Kept so the screen can say so
  /// and offer to send again, rather than showing "waiting" for ever.
  final String? sendError;

  bool get sent => reference != null;

  /// The support category the server understands.
  String get category => customCategory ?? (kind == 'new_temple' ? 'suggestion' : 'wrong_information');
  String get subject => customSubject ?? (kind == 'new_temple' ? 'New temple: $templeName' : '$field at $templeName');
  bool get answered => replies.any((m) => m.fromStaff) || resolution != null;

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind, 'slug': templeSlug, 'temple_id': templeId, 'temple': templeName, 'field': field, 'text': text, 'at': createdAt.toIso8601String(), 'ref': reference, 'status': status, 'status_label': statusLabel, 'resolution': resolution, 'name': reporterName, 'email': reporterEmail, 'category': customCategory, 'subject': customSubject, 'open': isOpen, 'send_error': sendError, 'replies': replies.map((m) => {'body': m.body, 'from_staff': m.fromStaff, 'author': m.author, 'created_at': m.createdAt}).toList()};

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
        customCategory: j['category']?.toString(),
        customSubject: j['subject']?.toString(),
        isOpen: j['open'] == null ? true : j['open'] == true,
        sendError: j['send_error']?.toString(),
        replies: (j['replies'] as List? ?? const []).map((e) => SupportMessage.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      );

  Submission withError(String? error) => Submission(id: id, kind: kind, templeSlug: templeSlug, templeId: templeId, templeName: templeName, field: field, text: text, createdAt: createdAt, reference: reference, status: status, statusLabel: statusLabel, replies: replies, resolution: resolution, reporterName: reporterName, reporterEmail: reporterEmail, customCategory: customCategory, customSubject: customSubject, isOpen: isOpen, sendError: error);

  Submission withTicket(SupportTicket t) => Submission(id: id, kind: kind, templeSlug: templeSlug, templeId: templeId, templeName: templeName, field: field, text: text, createdAt: createdAt, reference: t.reference, status: t.status, statusLabel: t.statusLabel, replies: t.messages, resolution: t.resolution, reporterName: reporterName, reporterEmail: reporterEmail, customCategory: customCategory, customSubject: customSubject, isOpen: t.isOpen);

  /// A ticket filed elsewhere (another device, or the web), seen for the
  /// first time on this one.
  factory Submission.fromTicket(SupportTicket t) => Submission(
        id: 'ticket-${t.reference}',
        kind: t.kind == 'report' ? 'correction' : 'support',
        templeName: t.aboutLabel ?? '',
        field: t.categoryLabel ?? '',
        text: t.body,
        createdAt: DateTime.tryParse(t.createdAt ?? '') ?? DateTime.now(),
        reference: t.reference,
        status: t.status,
        statusLabel: t.statusLabel,
        replies: t.messages,
        resolution: t.resolution,
        customCategory: t.category,
        customSubject: t.subject,
        isOpen: t.isOpen,
      );

  static const categories = <(String, String, String)>[
    ('wrong_information', 'Wrong information', 'Timings, address, phone number or anything else that is out of date.'),
    ('inappropriate_content', 'Inappropriate content', 'A photo or text that does not belong on this listing.'),
    ('duplicate', 'Duplicate listing', 'This temple already appears somewhere else.'),
    ('account', 'Account or sign-in', 'Signing in, your profile, or your passport.'),
    ('booking', 'Puja or booking', 'A seva or puja booking link that does not work.'),
    ('app_problem', 'Something is broken', 'The app crashed, froze or showed an error.'),
    ('suggestion', 'Suggestion', 'Something you would like the app to do.'),
    ('other', 'Something else', 'Anything that does not fit the others.'),
  ];

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

  /// Forgets everything kept on this device, for signing out: the next
  /// person to use the phone must not see, or sync into their own account,
  /// what the last one recorded.
  Future<void> clearAll() async {
    _items.clear();
    await _prefs.remove('submissions');
    notifyListeners();
  }

  Future<void> Function(Submission s)? onCreated;
  Future<void> Function(Submission s, String body)? onReplied;

  List<Submission> get all => List.unmodifiable(_items.reversed);
  Submission? byId(String id) => _items.where((s) => s.id == id).firstOrNull;
  List<Submission> get pending => _items.where((s) => !s.sent).toList();

  Future<Submission> add({required String kind, String? templeSlug, int? templeId, required String templeName, required String field, required String text, String? reporterName, String? reporterEmail, String? category, String? subject}) async {
    final s = Submission(id: DateTime.now().microsecondsSinceEpoch.toRadixString(36), kind: kind, templeSlug: templeSlug, templeId: templeId, templeName: templeName, field: field, text: text, createdAt: DateTime.now(), reporterName: reporterName, reporterEmail: reporterEmail, customCategory: category, customSubject: subject);
    _items.add(s);
    await _save();
    await onCreated?.call(s);
    return s;
  }

  /// Records why sending failed, or clears it before another attempt.
  Future<void> setError(String id, String? error) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _items[i] = _items[i].withError(error);
    await _save();
  }

  Future<void> setTicket(String id, SupportTicket t) async {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _items[i] = _items[i].withTicket(t);
    await _save();
  }

  /// Refreshes status and replies for the tickets we know by reference, and
  /// brings in tickets filed elsewhere.
  Future<void> mergeTickets(List<SupportTicket> tickets) async {
    var changed = false;
    for (final t in tickets) {
      final i = _items.indexWhere((s) => s.reference == t.reference);
      if (i >= 0) {
        _items[i] = _items[i].withTicket(t);
      } else {
        _items.add(Submission.fromTicket(t));
      }
      changed = true;
    }
    if (changed) await _save();
  }

  /// A reply from the devotee: shown at once, sent through the outbox.
  Future<void> reply(Submission s, String body, {String author = 'You'}) async {
    final i = _items.indexWhere((x) => x.id == s.id);
    if (i < 0) return;
    final msg = SupportMessage(body: body, fromStaff: false, author: author, createdAt: DateTime.now().toIso8601String());
    _items[i] = Submission(id: s.id, kind: s.kind, templeSlug: s.templeSlug, templeId: s.templeId, templeName: s.templeName, field: s.field, text: s.text, createdAt: s.createdAt, reference: s.reference, status: s.status, statusLabel: s.statusLabel, replies: [...s.replies, msg], resolution: s.resolution, reporterName: s.reporterName, reporterEmail: s.reporterEmail, customCategory: s.customCategory, customSubject: s.customSubject, isOpen: true);
    await _save();
    await onReplied?.call(_items[i], body);
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
