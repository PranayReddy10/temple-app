import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

/// One recorded visit to a temple. A temple may be visited many times; the
/// stamp is earned on the first.
/// How a visit was confirmed. GPS means the device was within range of the
/// temple's coordinates; QR means a temple-issued code was scanned. Manual
/// is the devotee's word, and the passport says so. Staff means the temple's
/// own staff marked it at the counter, after scanning the devotee's passport.
enum Verification { manual, gps, qr, staff }

/// One of up to three photos kept with a visit as a memory. Never in the
/// passport book and never shown to anyone else: only the one photo in the
/// passport is. [path] is the device copy; [remoteId] and [url] are set once
/// the account has it.
class MemoryPhoto {
  const MemoryPhoto({this.path, this.remoteId, this.url});

  final String? path;
  final int? remoteId;
  final String? url;

  Map<String, dynamic> toJson() => {'path': path, 'remote_id': remoteId, 'url': url};

  factory MemoryPhoto.fromJson(Map<String, dynamic> j) => MemoryPhoto(path: j['path']?.toString(), remoteId: (j['remote_id'] as num?)?.toInt(), url: j['url']?.toString());

  MemoryPhoto withRemote(int id, String? remoteUrl) => MemoryPhoto(path: path, remoteId: id, url: remoteUrl ?? url);
}

class Visit {
  Visit({required this.templeSlug, required this.templeName, required this.deitySlug, required this.visitedAt, this.note, this.photoPath, this.city, this.state, this.verification = Verification.manual, this.members = const [], String? localKey, this.remoteId, this.remoteVerified, this.remotePhoto, this.latitude, this.longitude, this.templeId, this.qrCode, this.memoryPhotos = const []})
      : localKey = localKey ?? '$templeSlug@${visitedAt.microsecondsSinceEpoch}';

  /// Stable device-side identity, used to match the server's copy.
  final String localKey;

  /// Set once `/temples/{slug}/visits` has accepted it.
  final int? remoteId;

  /// The server's verdict: only a GPS or QR check-in within its radius
  /// counts as a stamp there. Null until synced.
  final bool? remoteVerified;
  final VisitPhoto? remotePhoto;
  final double? latitude;
  final double? longitude;
  final int? templeId;

  /// The temple code scanned for a QR check-in, sent so the server can
  /// check its signature.
  final String? qrCode;

  /// Up to [maxMemoryPhotos] photos kept with the visit, outside the passport.
  final List<MemoryPhoto> memoryPhotos;
  static const maxMemoryPhotos = 3;

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
        'key': localKey,
        'remote_id': remoteId,
        'remote_verified': remoteVerified,
        'remote_photo': remotePhoto == null ? null : {'id': remotePhoto!.id, 'original_url': remotePhoto!.originalUrl, 'stamp_url': remotePhoto!.stampUrl, 'status': {'value': remotePhoto!.status, 'label': remotePhoto!.statusLabel}, 'moderation_note': remotePhoto!.moderationNote, 'is_public': remotePhoto!.isPublic},
        'lat': latitude,
        'lng': longitude,
        'temple_id': templeId,
        'qr': qrCode,
        'memories': memoryPhotos.map((m) => m.toJson()).toList(),
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
        localKey: j['key']?.toString(),
        remoteId: (j['remote_id'] as num?)?.toInt(),
        remoteVerified: j['remote_verified'] as bool?,
        remotePhoto: j['remote_photo'] is Map ? VisitPhoto.fromJson(Map<String, dynamic>.from(j['remote_photo'] as Map)) : null,
        latitude: (j['lat'] as num?)?.toDouble(),
        longitude: (j['lng'] as num?)?.toDouble(),
        templeId: (j['temple_id'] as num?)?.toInt(),
        qrCode: j['qr']?.toString(),
        memoryPhotos: (j['memories'] as List? ?? const []).whereType<Map>().map((e) => MemoryPhoto.fromJson(Map<String, dynamic>.from(e))).toList(),
      );

  /// Whether the passport may call this a stamp: the server's verdict once
  /// synced, the device's verification before that.
  bool get isVerified => remoteVerified ?? (verification != Verification.manual);

  Visit copyWith({String? note, String? photoPath, int? remoteId, bool? remoteVerified, VisitPhoto? remotePhoto, Verification? verification, List<MemoryPhoto>? memoryPhotos}) => Visit(
        templeSlug: templeSlug,
        templeName: templeName,
        deitySlug: deitySlug,
        visitedAt: visitedAt,
        note: note ?? this.note,
        photoPath: photoPath ?? this.photoPath,
        city: city,
        state: state,
        verification: verification ?? this.verification,
        members: members,
        localKey: localKey,
        remoteId: remoteId ?? this.remoteId,
        remoteVerified: remoteVerified ?? this.remoteVerified,
        remotePhoto: remotePhoto ?? this.remotePhoto,
        latitude: latitude,
        longitude: longitude,
        templeId: templeId,
        qrCode: qrCode,
        memoryPhotos: memoryPhotos ?? this.memoryPhotos,
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

  /// Called after a visit is recorded, so the sync layer can queue it.
  Future<void> Function(Visit visit)? onVisitCreated;

  /// `GET /me/passport`, when signed in and reachable.
  PassportSummary? summary;

  List<Visit> get visits => List.unmodifiable(_visits.reversed);
  Visit? byKey(String key) => _visits.where((v) => v.localKey == key).firstOrNull;
  List<Visit> get unsynced => _visits.where((v) => v.remoteId == null).toList();

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

  Future<Visit> checkIn(TempleSummary temple, {String? note, String? photoPath, Verification verification = Verification.manual, List<String> members = const [], double? latitude, double? longitude, String? qrCode}) async {
    final v = Visit(
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
      latitude: latitude,
      longitude: longitude,
      templeId: temple.id,
      qrCode: qrCode,
    );
    _visits.add(v);
    await _save();
    await onVisitCreated?.call(v);
    return v;
  }

  int get verifiedStamps => stamps.where((v) => v.isVerified).length;

  Future<void> setRemote(String localKey, RemoteVisit remote) async {
    final i = _visits.indexWhere((v) => v.localKey == localKey);
    if (i < 0) return;
    _visits[i] = _visits[i].copyWith(remoteId: remote.id, remoteVerified: remote.isVerified);
    await _save();
  }

  Future<void> setRemotePhoto(String localKey, VisitPhoto photo) async {
    final i = _visits.indexWhere((v) => v.localKey == localKey);
    if (i < 0) return;
    _visits[i] = _visits[i].copyWith(remotePhoto: photo);
    await _save();
  }

  /// Brings in visits recorded on other devices or before this one was
  /// signed in. Matched by remote id, then by temple and day.
  Future<void> mergeRemote(List<RemoteVisit> remote, {String? Function(String slug)? deityOf}) async {
    var changed = false;
    for (final r in remote) {
      final byId = _visits.indexWhere((v) => v.remoteId == r.id);
      if (byId >= 0) {
        final method = _method(r.method);
        // A visit the temple's staff confirmed at the counter says so.
        final upgrade = method == Verification.staff && _visits[byId].verification != Verification.staff;
        if (_visits[byId].remoteVerified != r.isVerified || upgrade) {
          _visits[byId] = _visits[byId].copyWith(remoteVerified: r.isVerified, verification: upgrade ? Verification.staff : null);
          changed = true;
        }
        continue;
      }
      final day = r.visitedOn;
      final byDay = _visits.indexWhere((v) => v.remoteId == null && v.templeSlug == r.templeSlug && day != null && v.visitedAt.toIso8601String().startsWith(day));
      if (byDay >= 0) {
        _visits[byDay] = _visits[byDay].copyWith(remoteId: r.id, remoteVerified: r.isVerified, verification: _method(r.method) == Verification.staff ? Verification.staff : null);
        changed = true;
        continue;
      }
      final when = DateTime.tryParse('${r.visitedOn ?? ''}T${r.visitedAt ?? '12:00'}:00') ?? DateTime.now();
      _visits.add(Visit(
        templeSlug: r.templeSlug,
        templeName: r.templeName,
        deitySlug: deityOf?.call(r.templeSlug),
        visitedAt: when,
        note: r.note,
        city: r.city,
        verification: _method(r.method),
        localKey: 'remote-${r.id}',
        remoteId: r.id,
        remoteVerified: r.isVerified,
        remotePhoto: r.photos.where((p) => !p.isMemory).firstOrNull,
        templeId: r.templeId,
      ));
      changed = true;
    }
    _visits.sort((a, b) => a.visitedAt.compareTo(b.visitedAt));
    if (changed) await _save();
  }

  static Verification _method(String? m) => switch (m) { 'gps' => Verification.gps, 'qr' => Verification.qr, 'staff' => Verification.staff, _ => Verification.manual };

  /// Memory photos the account holds for visits on this device, from
  /// `GET /me/photos`: ones taken on another device appear here too.
  Future<void> mergeMemoryPhotos(List<VisitPhoto> photos) async {
    var changed = false;
    for (final p in photos.where((p) => p.isMemory && p.visitId != null)) {
      final i = _visits.indexWhere((v) => v.remoteId == p.visitId);
      if (i < 0) continue;
      final v = _visits[i];
      if (v.memoryPhotos.any((m) => m.remoteId == p.id)) continue;
      if (v.memoryPhotos.length >= Visit.maxMemoryPhotos) continue;
      _visits[i] = v.copyWith(memoryPhotos: [...v.memoryPhotos, MemoryPhoto(remoteId: p.id, url: p.originalUrl)]);
      changed = true;
    }
    if (changed) await _save();
  }

  /// Keeps a memory photo with the visit. The picked file is copied by the
  /// caller into the app's own storage first: a picker's cache copy can be
  /// cleared by the system at any time.
  Future<Visit?> addMemoryPhoto(Visit visit, String path) async {
    final i = _visits.indexWhere((v) => v.localKey == visit.localKey);
    if (i < 0 || _visits[i].memoryPhotos.length >= Visit.maxMemoryPhotos) return null;
    _visits[i] = _visits[i].copyWith(memoryPhotos: [..._visits[i].memoryPhotos, MemoryPhoto(path: path)]);
    await _save();
    return _visits[i];
  }

  Future<MemoryPhoto?> removeMemoryPhoto(Visit visit, int index) async {
    final i = _visits.indexWhere((v) => v.localKey == visit.localKey);
    if (i < 0 || index < 0 || index >= _visits[i].memoryPhotos.length) return null;
    final list = [..._visits[i].memoryPhotos];
    final removed = list.removeAt(index);
    _visits[i] = _visits[i].copyWith(memoryPhotos: list);
    await _save();
    return removed;
  }

  Future<void> setMemoryRemote(String localKey, String path, VisitPhoto photo) async {
    final i = _visits.indexWhere((v) => v.localKey == localKey);
    if (i < 0) return;
    _visits[i] = _visits[i].copyWith(memoryPhotos: [for (final m in _visits[i].memoryPhotos) m.path == path && m.remoteId == null ? m.withRemote(photo.id, photo.originalUrl) : m]);
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
    final i = _visits.indexWhere((v) => v.localKey == visit.localKey);
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
