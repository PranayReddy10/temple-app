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
  DayTheme? _todayOverride;
  final List<DayTheme> _previews = [];
  List<DevotionalDay> _today = const [];
  bool _offline = false;
  bool _loaded = false;

  /// The theme the app is currently wearing: the top preview, else today.
  DayTheme get theme => _previews.isNotEmpty ? _previews.last : _theme;

  /// Today's theme regardless of any preview. Home always shows this.
  DayTheme get todayTheme => _theme;

  /// How many previews are stacked; 0 means the app wears today.
  int get previewDepth => _previews.length;

  /// Devotional media published for today (songs, chants, videos).
  List<DevotionalMedia> get todayMedia => [for (final d in _today) ...d.media];
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
      if (hex != null) {
        final parsed = _parseHex(hex);
        if (parsed != null && parsed != _theme.accent) {
          _todayOverride = DayTheme.today().withAccent(parsed);
          _theme = _todayOverride!;
        }
      }
    } catch (_) {
      _today = const [];
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> refresh() => _load();

  /// Push a temporary identity (a weekday page, a temple's deity). Nested
  /// screens stack, so popping a temple opened from Wednesday's page returns
  /// to Wednesday, not to today.
  void preview(DayTheme t) {
    _previews.add(t);
    notifyListeners();
  }

  void endPreview() {
    if (_previews.isNotEmpty) _previews.removeLast();
    notifyListeners();
  }

  /// Re-evaluates today, for a midnight rollover while the app is open.
  void refreshToday() {
    final t = DateTime.now().weekday % 7;
    if (_theme.weekday != t) {
      _theme = DayTheme.today();
      _todayOverride = null;
      _load();
    }
  }

  static Color? _parseHex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }
}
