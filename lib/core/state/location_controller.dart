import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/temple_repository.dart';

/// Where the devotee is, once they have allowed it, for "12 km away" on every
/// temple and seva drive.
///
/// Asked for once; after that the last position is remembered and refreshed
/// quietly on launch, so distances show at once and without a prompt. Never
/// asks on its own — only [request] shows the permission dialog.
class LocationController extends ChangeNotifier {
  LocationController(this._prefs) {
    final lat = _prefs.getDouble('loc_lat');
    final lng = _prefs.getDouble('loc_lng');
    if (lat != null && lng != null) {
      _lat = lat;
      _lng = lng;
    }
  }

  final SharedPreferences _prefs;
  double? _lat;
  double? _lng;
  bool _locating = false;

  bool get known => _lat != null && _lng != null;
  bool get locating => _locating;
  double? get latitude => _lat;
  double? get longitude => _lng;

  /// A position found elsewhere (Home's "near you", search) is shared here.
  Future<void> set(double lat, double lng) async {
    _lat = lat;
    _lng = lng;
    notifyListeners();
    await _prefs.setDouble('loc_lat', lat);
    await _prefs.setDouble('loc_lng', lng);
  }

  /// On launch: a fresher fix if permission was already given, silently.
  Future<void> refreshIfAllowed() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low)).timeout(const Duration(seconds: 10));
      await set(pos.latitude, pos.longitude);
    } catch (_) {
      // The remembered position still serves.
    }
  }

  /// Asks for permission if need be. False when refused or unavailable.
  Future<bool> request() async {
    _locating = true;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return false;
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium)).timeout(const Duration(seconds: 15));
      await set(pos.latitude, pos.longitude);
      return true;
    } catch (_) {
      return false;
    } finally {
      _locating = false;
      notifyListeners();
    }
  }

  /// Straight-line kilometres to a place, when both ends are known.
  double? kmTo(double? lat, double? lng) {
    if (!known || lat == null || lng == null) return null;
    return TempleRepository.distanceKm(_lat!, _lng!, lat, lng);
  }

  /// "Here", "650 m away", "12 km away", "1,240 km away".
  String? labelTo(double? lat, double? lng) {
    final km = kmTo(lat, lng);
    return km == null ? null : formatKm(km);
  }

  static String formatKm(double km) {
    if (km < 0.1) return 'You are here';
    if (km < 1) return '${(km * 1000).round()} m away';
    if (km < 10) return '${km.toStringAsFixed(1)} km away';
    return '${NumberFormat.decimalPattern('en_IN').format(km.round())} km away';
  }
}
