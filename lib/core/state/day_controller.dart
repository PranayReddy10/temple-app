import 'package:flutter/material.dart';

import '../api/temple_repository.dart';
import '../models/models.dart';
import '../theme/day_theme.dart';

/// Which day's deity the app is themed for.
///
/// Defaults to today. The Days screen can preview any weekday, and a temple
/// profile temporarily takes its own deity's identity, so the theme is a
/// value in state rather than a function of the clock.
class DayController extends ChangeNotifier {
  DayController(this._repo) {
    _theme = DayTheme.today();
    _load();
  }

  final TempleRepository _repo;
  late DayTheme _theme;
  List<DevotionalDay> _today = const [];
  bool _offline = false;
  bool _loaded = false;

  DayTheme get theme => _theme;
  List<DevotionalDay> get today => _today;
  bool get offline => _offline;
  bool get loaded => _loaded;

  Future<void> _load() async {
    try {
      final r = await _repo.today();
      _today = r.data;
      _offline = r.isOffline;
      // Prefer the server's colour for the lead deity so editors can tune it.
      final lead = _today.firstOrNull;
      final hex = lead?.accentColor;
      if (hex != null && _theme.weekday == DateTime.now().weekday % 7) {
        final parsed = _parseHex(hex);
        if (parsed != null && parsed != _theme.accent) _theme = _theme.withAccent(parsed);
      }
    } catch (_) {
      _today = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() => _load();

  void preview(DayTheme t) {
    _theme = t;
    notifyListeners();
  }

  void resetToToday() {
    _theme = DayTheme.today();
    notifyListeners();
  }

  static Color? _parseHex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }
}
