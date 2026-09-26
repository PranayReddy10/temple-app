import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import 'app_settings.dart';
import 'mantra_player.dart';

/// The app's few sounds: the bell as it opens, and a page turning in the
/// passport. All synthesised (see
/// tool/make_temple_bell.py and tool/make_temple_sounds.py).
///
/// Silent when "Temple sounds" is off or the app is muted, and silent
/// without complaint where there is no audio (tests, a web tab not yet
/// interacted with).
class SoundEffects {
  SoundEffects._();

  static const bell = 'temple_bell.wav';
  static const pageTurn = 'page_turn.wav';

  static final Map<String, ap.AudioPlayer> _players = {};

  static bool enabled(BuildContext context) {
    try {
      return context.read<AppSettings>().templeSounds && !context.read<MantraPlayer>().muted;
    } catch (_) {
      return false;
    }
  }

  static Future<void> play(BuildContext context, String sound, {double volume = 0.8}) async {
    if (!enabled(context)) return;
    try {
      final player = _players.putIfAbsent(sound, () => ap.AudioPlayer()..setReleaseMode(ap.ReleaseMode.stop));
      await player.stop();
      await player.play(ap.AssetSource('sounds/$sound'), volume: volume);
    } catch (_) {}
  }
}
