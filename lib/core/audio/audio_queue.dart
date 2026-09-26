import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/models.dart';
import '../state/mantra_player.dart';

/// The songs and chants lined up to play, and which one is on.
///
/// Pure bookkeeping, apart from the player, so it can be reasoned about
/// (and tested) without a device: only direct recordings go in, the
/// current one is always in range, and "next" at the end wraps to the
/// start the way a bhajan playlist is expected to.
class AudioQueue {
  const AudioQueue({this.items = const [], this.index = 0});

  static const empty = AudioQueue();

  final List<DevotionalMedia> items;
  final int index;

  /// Only what the app can play itself: a recording with a direct URL. A
  /// YouTube link or a search result is not a track.
  static bool isPlayable(DevotionalMedia m) => m.url != null && (m.playback.kind == 'audio' || isDirectAudio(m.url, m.sourceType));

  factory AudioQueue.of(List<DevotionalMedia> all, {DevotionalMedia? start}) {
    final items = all.where(isPlayable).toList();
    if (items.isEmpty) return empty;
    final at = start == null ? 0 : items.indexWhere((m) => m.url == start.url);
    return AudioQueue(items: items, index: at < 0 ? 0 : at);
  }

  bool get isEmpty => items.isEmpty;
  DevotionalMedia? get current => items.isEmpty ? null : items[index.clamp(0, items.length - 1)];
  bool get hasNext => items.length > 1;
  bool get hasPrevious => items.length > 1;
  List<DevotionalMedia> get upNext => items.isEmpty ? const [] : [...items.sublist(index + 1), ...items.sublist(0, index)];

  AudioQueue next() => items.isEmpty ? this : AudioQueue(items: items, index: (index + 1) % items.length);
  AudioQueue previous() => items.isEmpty ? this : AudioQueue(items: items, index: (index - 1 + items.length) % items.length);
  AudioQueue at(int i) => AudioQueue(items: items, index: i.clamp(0, items.isEmpty ? 0 : items.length - 1));
}

/// Plays the queue in the app: when a song ends the next one starts.
///
/// The player is created on first use, so screens that merely show the
/// mini bar cost nothing until somebody presses play.
class AudioQueueController extends ChangeNotifier {
  AudioQueueController({MantraPlayer? mantra}) : _mantra = mantra {
    _mantra?.addListener(_onMantra);
  }

  final MantraPlayer? _mantra;
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subs = [];
  AudioQueue _queue = AudioQueue.empty;
  bool _playing = false;
  bool _loading = false;
  Duration _position = Duration.zero;
  Duration? _duration;

  AudioQueue get queue => _queue;
  DevotionalMedia? get current => _queue.current;
  bool get hasQueue => !_queue.isEmpty;
  bool get isPlaying => _playing;
  bool get isLoading => _loading;
  Duration get position => _position;
  Duration? get duration => _duration;
  bool isCurrent(DevotionalMedia m) => current?.url != null && current!.url == m.url;

  /// Plays [items] (only the recordings among them) from [start].
  Future<void> playQueue(List<DevotionalMedia> items, {DevotionalMedia? start}) async {
    final q = AudioQueue.of(items, start: start);
    if (q.isEmpty) return;
    _queue = q;
    notifyListeners();
    await _mantra?.stop();
    await _loadCurrent(play: true);
  }

  Future<void> play() async {
    if (_queue.isEmpty) return;
    await _mantra?.stop();
    await _player?.play();
  }

  Future<void> pause() async => _player?.pause();

  Future<void> toggle() async => _playing ? pause() : play();

  Future<void> next() async {
    if (_queue.isEmpty) return;
    _queue = _queue.next();
    notifyListeners();
    await _loadCurrent(play: true);
  }

  Future<void> previous() async {
    if (_queue.isEmpty) return;
    // Early in a song, "previous" means the one before; later it means
    // "again from the start", as every music player does it.
    if (_position > const Duration(seconds: 4)) {
      await _player?.seek(Duration.zero);
      return;
    }
    _queue = _queue.previous();
    notifyListeners();
    await _loadCurrent(play: true);
  }

  Future<void> skipTo(int index) async {
    if (_queue.isEmpty) return;
    _queue = _queue.at(index);
    notifyListeners();
    await _loadCurrent(play: true);
  }

  Future<void> seek(Duration to) async => _player?.seek(to);

  Future<void> stop() async {
    await _player?.stop();
    _queue = AudioQueue.empty;
    _playing = false;
    _position = Duration.zero;
    _duration = null;
    notifyListeners();
  }

  AudioPlayer _ensurePlayer() {
    if (_player != null) return _player!;
    final p = AudioPlayer();
    _player = p;
    _subs.add(p.playerStateStream.listen((st) {
      _playing = st.playing && st.processingState != ProcessingState.completed && st.processingState != ProcessingState.idle;
      _loading = st.processingState == ProcessingState.loading || st.processingState == ProcessingState.buffering;
      if (st.processingState == ProcessingState.completed) {
        // The next one starts on its own, like any playlist.
        unawaited(next());
        return;
      }
      notifyListeners();
    }));
    _subs.add(p.positionStream.listen((d) {
      _position = d;
      notifyListeners();
    }));
    _subs.add(p.durationStream.listen((d) {
      _duration = d;
      notifyListeners();
    }));
    p.setVolume(_mantra?.muted == true ? 0 : 1);
    return p;
  }

  Future<void> _loadCurrent({required bool play}) async {
    final m = current;
    if (m?.url == null) return;
    final p = _ensurePlayer();
    try {
      _loading = true;
      notifyListeners();
      await p.setAudioSource(AudioSource.uri(Uri.parse(m!.url!)));
      if (play) await p.play();
    } catch (_) {
      _loading = false;
      _playing = false;
      notifyListeners();
    }
  }

  void _onMantra() {
    final m = _mantra;
    if (m == null) return;
    _player?.setVolume(m.muted ? 0 : 1);
    // A mantra chanted from a card pauses the song; one at a time.
    if (m.isPlaying && _playing) unawaited(pause());
  }

  @override
  void dispose() {
    _mantra?.removeListener(_onMantra);
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }
}
