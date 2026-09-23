import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Plays a mantra inside the app, with one mute switch for the whole app.
///
/// A recording from the API (a `chant` with a direct audio URL) is played as
/// audio and looped. When there is none, the mantra is chanted by the
/// device's own Hindi voice, so every deity and every temple with a mantra
/// can be heard even with no signal. Mute silences both and is remembered.
class MantraPlayer extends ChangeNotifier {
  MantraPlayer(this._prefs) {
    _muted = _prefs.getBool('mantra_muted') ?? false;
    _audio.onPlayerComplete.listen((_) => _finished());
    _audio.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.stopped || s == PlayerState.completed) _finished();
    });
    _tts.setCompletionHandler(_finished);
    _tts.setCancelHandler(_finished);
    _tts.setErrorHandler((_) => _finished());
  }

  final SharedPreferences _prefs;
  final AudioPlayer _audio = AudioPlayer();
  final FlutterTts _tts = FlutterTts();

  bool _muted = false;
  String? _playingKey;
  bool _usingTts = false;
  int _repeatsLeft = 0;
  String? _ttsText;

  bool get muted => _muted;
  bool get isPlaying => _playingKey != null;
  bool isPlayingKey(String key) => _playingKey == key;

  /// Start, or stop if this key is already playing.
  Future<void> toggle({required String key, required String text, String? audioUrl, int repeats = 3}) async {
    if (_playingKey == key) {
      await stop();
      return;
    }
    await stop();
    _playingKey = key;
    notifyListeners();
    try {
      if (audioUrl != null && audioUrl.isNotEmpty) {
        _usingTts = false;
        await _audio.setReleaseMode(ReleaseMode.loop);
        await _audio.setVolume(_muted ? 0 : 1);
        await _audio.play(UrlSource(audioUrl));
      } else {
        _usingTts = true;
        _ttsText = text;
        _repeatsLeft = repeats;
        await _tts.setLanguage(_languageFor(text));
        await _tts.setSpeechRate(0.4);
        await _tts.setPitch(0.9);
        await _tts.setVolume(_muted ? 0 : 1);
        await _speakNext();
      }
    } catch (_) {
      _playingKey = null;
      notifyListeners();
    }
  }

  Future<void> _speakNext() async {
    if (_ttsText == null || _repeatsLeft <= 0) {
      _finished();
      return;
    }
    _repeatsLeft--;
    await _tts.speak(_ttsText!);
  }

  void _finished() {
    if (_usingTts && _playingKey != null && _repeatsLeft > 0) {
      // The completion handler fires per utterance; chant again.
      _speakNext();
      return;
    }
    if (_playingKey == null) return;
    _playingKey = null;
    _ttsText = null;
    notifyListeners();
  }

  Future<void> stop() async {
    if (_playingKey == null) return;
    _playingKey = null;
    _repeatsLeft = 0;
    _ttsText = null;
    try {
      await _audio.stop();
      await _tts.stop();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setMuted(bool value) async {
    _muted = value;
    await _prefs.setBool('mantra_muted', value);
    try {
      await _audio.setVolume(value ? 0 : 1);
      await _tts.setVolume(value ? 0 : 1);
      // A running chant keeps its old volume until the next utterance;
      // restart it so the switch is immediate.
      if (_usingTts && _playingKey != null) {
        await _tts.stop();
        if (!value) await _speakNext();
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> toggleMuted() => setMuted(!_muted);

  /// Devanagari, Telugu, Tamil and Kannada scripts each get their own voice;
  /// transliterated Latin text is chanted in Indian English.
  static String _languageFor(String text) {
    if (RegExp(r'[ఀ-౿]').hasMatch(text)) return 'te-IN';
    if (RegExp(r'[஀-௿]').hasMatch(text)) return 'ta-IN';
    if (RegExp(r'[ಀ-೿]').hasMatch(text)) return 'kn-IN';
    if (RegExp(r'[ऀ-ॿ]').hasMatch(text)) return 'hi-IN';
    return 'en-IN';
  }

  @override
  void dispose() {
    _audio.dispose();
    _tts.stop();
    super.dispose();
  }
}

/// Whether a media item is a recording the app can play directly.
bool isDirectAudio(String? url, String? sourceType) {
  if (url == null) return false;
  final lower = url.toLowerCase().split('?').first;
  return sourceType != 'external' && (lower.endsWith('.mp3') || lower.endsWith('.m4a') || lower.endsWith('.aac') || lower.endsWith('.ogg') || lower.endsWith('.wav'));
}
