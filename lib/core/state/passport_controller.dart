import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// One recorded visit to a temple. A temple may be visited many times; the
/// stamp is earned on the first.
/// How a visit was confirmed. GPS means the device was within range of the
/// temple's coordinates; QR means a temple-issued code was scanned. Manual
/// is the devotee's word, and the passport says so.
enum Verification { manual, gps, qr }

class Visit {
  const Visit({required this.templeSlug, required this.templeName, required this.deitySlug, required this.visitedAt, this.note, this.photoPath, this.city, this.state, this.verification = Verification.manual, this.members = const []});

  final String templeSlug;
  final String templeName;
  final String? deitySlug;
  final DateTime visitedAt;
  final String? note;
  final String? photoPath;
  final String? city;
  final String? state;
  final Verification verification;

  /// Family member ids who came along.
  final List<String> members;

  Map<String, dynamic> toJson() => {
        'slug': templeSlug,
        'name': templeName,
        'deity': deitySlug,
        'at': visitedAt.toIso8601String(),
        'note': note,
        'photo': photoPath,
        'city': city,
        'state': state,
        'verification': verification.name,
        'members': members,
      };

  factory Visit.fromJson(Map<String, dynamic> j) => Visit(
        templeSlug: '${j['slug']}',
        templeName: '${j['name']}',
        deitySlug: j['deity']?.toString(),
        visitedAt: DateTime.tryParse('${j['at']}') ?? DateTime.now(),
        note: j['note']?.toString(),
        photoPath: j['photo']?.toString(),
        city: j['city']?.toString(),
        state: j['state']?.toString(),
        verification: Verification.values.firstWhere((v) => v.name == j['verification'], orElse: () => Verification.manual),
        members: (j['members'] as List? ?? const []).map((e) => '$e').toList(),
      );

  Visit copyWith({String? note, String? photoPath}) => Visit(
        templeSlug: templeSlug,
        templeName: templeName,
        deitySlug: deitySlug,
        visitedAt: visitedAt,
        note: note ?? this.note,
        photoPath: photoPath ?? this.photoPath,
        city: city,
        state: state,
        verification: verification,
        members: members,
      );
}

/// A pilgrimage circuit the Passport tracks completion against.
class Collection {
  const Collection({required this.slug, required this.name, required this.categorySlug, required this.target, required this.description});

  final String slug;
  final String name;
  final String categorySlug;
  final int target;
  final String description;

  static const List<Collection> all = [
    Collection(slug: 'jyotirlinga', name: 'Dwadasha Jyotirlinga', categorySlug: 'jyotirlinga', target: 12, description: 'The twelve columns of light.'),
    Collection(slug: 'char-dham', name: 'Char Dham', categorySlug: 'char-dham', target: 4, description: 'Badrinath, Dwarka, Puri, Rameswaram.'),
    Collection(slug: 'chota-char-dham', name: 'Chota Char Dham', categorySlug: 'chota-char-dham', target: 4, description: 'The Himalayan four.'),
    Collection(slug: 'shakti-peetha', name: 'Shakti Peethas', categorySlug: 'shakti-peetha', target: 18, description: 'Seats of the goddess.'),
    Collection(slug: 'sapta-puri', name: 'Sapta Puri', categorySlug: 'sapta-puri', target: 7, description: 'The seven cities of liberation.'),
    Collection(slug: 'divya-desam', name: 'Divya Desam', categorySlug: 'divya-desam', target: 108, description: 'Sung by the Alvars.'),
  ];
}

class Achievement {
  const Achievement({required this.slug, required this.title, required this.description, required this.test});

  final String slug;
  final String title;
  final String description;
  final bool Function(PassportController) test;

  static final List<Achievement> all = [
    Achievement(slug: 'first-step', title: 'First Step', description: 'Your first temple stamp.', test: (p) => p.stampCount >= 1),
    Achievement(slug: 'panchayatana', title: 'Panchayatana', description: 'Five temples stamped.', test: (p) => p.stampCount >= 5),
    Achievement(slug: 'ekadasha', title: 'Ekadasha', description: 'Eleven temples stamped.', test: (p) => p.stampCount >= 11),
    Achievement(slug: 'week-of-devotion', title: 'Week of Devotion', description: 'Visited a temple of every weekday deity.', test: (p) => p.deitiesVisited.length >= 7),
    Achievement(slug: 'trishul', title: 'Trishul', description: 'Three Shiva temples.', test: (p) => p.visitsByDeity('shiva') >= 3),
    Achievement(slug: 'three-states', title: 'Desha Yatri', description: 'Temples in three states.', test: (p) => p.statesVisited.length >= 3),
    Achievement(slug: 'memory-keeper', title: 'Memory Keeper', description: 'Saved a photo with a visit.', test: (p) => p.visits.any((v) => v.photoPath != null)),
    Achievement(slug: 'pramana', title: 'Pramana', description: 'A visit verified by GPS or temple QR.', test: (p) => p.verifiedCount >= 1),
    Achievement(slug: 'kutumba', title: 'Kutumba', description: 'A visit shared with family.', test: (p) => p.visits.any((v) => v.members.isNotEmpty)),
  ];
}

class PassportController extends ChangeNotifier {
  PassportController(this._prefs) {
    final raw = _prefs.getString('visits');
    if (raw != null) {
      try {
        _visits.addAll((jsonDecode(raw) as List).map((e) => Visit.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final List<Visit> _visits = [];

  List<Visit> get visits => List.unmodifiable(_visits.reversed);

  /// Unique temples, first visit only: the stamp book.
  List<Visit> get stamps {
    final seen = <String>{};
    return [for (final v in _visits) if (seen.add(v.templeSlug)) v];
  }

  int get stampCount => stamps.length;
  bool hasVisited(String slug) => _visits.any((v) => v.templeSlug == slug);
  Visit? firstVisit(String slug) => _visits.where((v) => v.templeSlug == slug).firstOrNull;
  Set<String> get deitiesVisited => {for (final v in _visits) if (v.deitySlug != null) v.deitySlug!};
  Set<String> get statesVisited => {for (final v in _visits) if (v.state != null) v.state!};
  int visitsByDeity(String deity) => stamps.where((v) => v.deitySlug == deity).length;

  List<Achievement> get earned => Achievement.all.where((a) => a.test(this)).toList();

  Future<void> checkIn(TempleSummary temple, {String? note, String? photoPath, Verification verification = Verification.manual, List<String> members = const []}) async {
    _visits.add(Visit(
      templeSlug: temple.slug,
      templeName: temple.name,
      deitySlug: temple.deity?.slug,
      visitedAt: DateTime.now(),
      note: note,
      photoPath: photoPath,
      city: temple.location.city,
      state: temple.location.state,
      verification: verification,
      members: members,
    ));
    await _save();
  }

  int get verifiedCount => _visits.where((v) => v.verification != Verification.manual).length;

  /// Stamps that a given family member shared.
  List<Visit> stampsFor(String memberId) {
    final seen = <String>{};
    return [for (final v in _visits) if (v.members.contains(memberId) && seen.add(v.templeSlug)) v];
  }

  /// Circuit stamps, resolved with the caller's category lookup.
  int circuitProgress(Collection c, List<String> Function(String slug) categoriesOf) =>
      stamps.where((v) => categoriesOf(v.templeSlug).contains(c.categorySlug)).length;

  Future<void> attachPhoto(Visit visit, String path) async {
    final i = _visits.indexOf(visit);
    if (i < 0) return;
    _visits[i] = visit.copyWith(photoPath: path);
    await _save();
  }

  Future<void> remove(Visit visit) async {
    _visits.remove(visit);
    await _save();
  }

  Future<void> _save() async {
    await _prefs.setString('visits', jsonEncode(_visits.map((v) => v.toJson()).toList()));
    notifyListeners();
  }
}
