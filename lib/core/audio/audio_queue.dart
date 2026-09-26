import 'dart:async';

import 'package:audio_service/audio_service.dart';
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

/// Plays the queue, in the app and out of it.
///
/// Like a music app: the song keeps playing when the phone is locked or
/// another app is in front, the lock screen and the notification carry the
/// title, the art and play / pause / next / previous, and when a song ends
/// the next one starts. The device's media buttons and a car's controls
/// reach it through the same handler.
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
  _TempleAudioHandler? _handler;
  bool _serviceTried = false;

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
    await _ensureService();
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
    _handler?.sync();
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
      _handler?.sync();
      notifyListeners();
    }));
    _subs.add(p.positionStream.listen((d) {
      _position = d;
      notifyListeners();
    }));
    _subs.add(p.durationStream.listen((d) {
      _duration = d;
      _handler?.sync();
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
      await p.setAudioSource(AudioSource.uri(Uri.parse(m!.url!), tag: _handler?.itemFor(m)));
      _handler?.sync();
      if (play) await p.play();
    } catch (_) {
      _loading = false;
      _playing = false;
      notifyListeners();
    }
  }

  /// Registers with the system's media session once, so the lock screen and
  /// the notification show and control what is playing. Skipped on the web
  /// and wherever it cannot start; playback itself does not depend on it.
  Future<void> _ensureService() async {
    if (_serviceTried || kIsWeb) return;
    _serviceTried = true;
    try {
      _handler = await AudioService.init(
        builder: () => _TempleAudioHandler(this),
        config: const AudioServiceConfig(
          androidNotificationChannelId: 'app.templepassport.audio',
          androidNotificationChannelName: 'Bhajans and chants',
          androidNotificationOngoing: true,
          androidStopForegroundOnPause: true,
        ),
      );
    } catch (e) {
      debugPrint('Media session unavailable: $e');
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

/// What the lock screen, the notification and the car see, and what their
/// buttons do. Everything delegates to the controller; this only mirrors it.
class _TempleAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  _TempleAudioHandler(this._ctl) {
    _ctl.addListener(sync);
    sync();
  }

  final AudioQueueController _ctl;

  MediaItem itemFor(DevotionalMedia m) => MediaItem(
        id: m.url ?? m.title,
        title: m.title,
        artist: m.artist,
        album: m.type == 'chant' ? 'Chants' : 'Bhajans',
        artUri: m.posterUrl == null ? null : Uri.tryParse(m.posterUrl!),
        duration: _ctl.isCurrent(m) ? _ctl.duration : null,
      );

  void sync() {
    final q = _ctl.queue;
    queue.add(q.items.map(itemFor).toList());
    final c = _ctl.current;
    mediaItem.add(c == null ? null : itemFor(c));
    playbackState.add(playbackState.value.copyWith(
      controls: [
        if (q.hasPrevious) MediaControl.skipToPrevious,
        _ctl.isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.stop,
        if (q.hasNext) MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek, MediaAction.seekForward, MediaAction.seekBackward},
      androidCompactActionIndices: const [0, 1, 3],
      processingState: q.isEmpty
          ? AudioProcessingState.idle
          : _ctl.isLoading
              ? AudioProcessingState.buffering
              : AudioProcessingState.ready,
      playing: _ctl.isPlaying,
      updatePosition: _ctl.position,
      queueIndex: q.index,
    ));
  }

  @override
  Future<void> play() => _ctl.play();

  @override
  Future<void> pause() => _ctl.pause();

  @override
  Future<void> stop() => _ctl.stop();

  @override
  Future<void> seek(Duration position) => _ctl.seek(position);

  @override
  Future<void> skipToNext() => _ctl.next();

  @override
  Future<void> skipToPrevious() => _ctl.previous();

  @override
  Future<void> skipToQueueItem(int index) => _ctl.skipTo(index);
}
