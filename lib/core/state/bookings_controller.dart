import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/booking_repository.dart';
import '../models/models.dart';
import 'auth_controller.dart';

/// A seva or puja the devotee booked outside the app (the temple's own
/// website, or its counter) and noted here so the reference is at hand.
///
/// Kept alongside the bookings made in the app: a temple that has not
/// switched on booking in the app still takes bookings, and the devotee
/// still wants them in one place.
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

/// The devotee's seva bookings: the ones made in the app, from the server
/// and remembered on the device so the code shows at a counter with no
/// signal; and the notes they kept of bookings made elsewhere.
class BookingsController extends ChangeNotifier {
  BookingsController(this._prefs, {ApiClient? api, AuthController? auth})
      : _repo = api == null ? null : BookingRepository(api),
        _auth = auth {
    final raw = _prefs.getString('bookings');
    if (raw != null) {
      try {
        _items.addAll((jsonDecode(raw) as List).map((e) => SevaBooking.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    final booked = _prefs.getString('puja_bookings');
    if (booked != null) {
      try {
        _booked.addAll((jsonDecode(booked) as List).map((e) => PujaBooking.fromJson(Map<String, dynamic>.from(e as Map))));
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final BookingRepository? _repo;
  final AuthController? _auth;
  final List<SevaBooking> _items = [];
  final List<PujaBooking> _booked = [];
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;
  bool get canSync => _repo != null && (_auth?.isSignedIn ?? false);

  /// Forgets everything kept on this device, for signing out: the next
  /// person to use the phone must not see, or sync into their own account,
  /// what the last one recorded.
  Future<void> clearAll() async {
    _items.clear();
    _booked.clear();
    await _prefs.remove('bookings');
    await _prefs.remove('puja_bookings');
    notifyListeners();
  }

  // --- Booked in the app ---

  /// Soonest first; over ones after.
  List<PujaBooking> get booked {
    final list = List<PujaBooking>.from(_booked);
    list.sort((a, b) {
      if (a.isPast != b.isPast) return a.isPast ? 1 : -1;
      return a.isPast ? b.bookedFor.compareTo(a.bookedFor) : a.bookedFor.compareTo(b.bookedFor);
    });
    return List.unmodifiable(list);
  }

  List<PujaBooking> get upcomingBooked => booked.where((b) => !b.isPast).toList();

  PujaBooking? byReference(String reference) => _booked.where((b) => b.reference == reference).firstOrNull;

  /// The bookings from the server, when signed in. The remembered list
  /// stands in until then, and stays when the server cannot be reached.
  Future<void> refresh() async {
    if (!canSync) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final list = await _repo!.mine();
      _booked
        ..clear()
        ..addAll(list);
      await _saveBooked();
    } on ApiException catch (e) {
      _error = e.isUnauthenticated ? null : e.message;
    } catch (_) {
      _error = 'Could not reach the server. Showing what was last saved.';
    }
    _loading = false;
    notifyListeners();
  }

  /// A booking just made, or one that changed: kept at once, before any
  /// refresh, so the code is on the device the moment it exists.
  Future<void> put(PujaBooking booking) async {
    _booked.removeWhere((b) => b.reference == booking.reference);
    _booked.add(booking);
    await _saveBooked();
  }

  /// Asks the server how a booking stands now (a payment still confirming).
  Future<PujaBooking?> reload(String reference) async {
    if (_repo == null) return null;
    try {
      final b = await _repo.show(reference);
      await put(b);
      return b;
    } catch (_) {
      return null;
    }
  }

  Future<PujaBooking> cancel(String reference, {String? reason}) async {
    final b = await _repo!.cancel(reference, reason: reason);
    await put(b);
    return b;
  }

  Future<void> _saveBooked() async {
    await _prefs.setString('puja_bookings', jsonEncode(_booked.map((b) => b.toJson()).toList()));
    notifyListeners();
  }

  // --- Noted from elsewhere ---

  List<SevaBooking> get all => List.unmodifiable(_items..sort((a, b) => a.date.compareTo(b.date)));
  List<SevaBooking> get upcoming => all.where((b) => !b.isPast).toList();

  /// Everything ahead, booked here or noted: the number on the Profile tile.
  int get upcomingCount => upcoming.length + upcomingBooked.length;

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
