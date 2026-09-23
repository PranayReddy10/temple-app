import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/models/models.dart';
import '../../core/state/mantra_player.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/media_widgets.dart';
import 'in_app_browser.dart';

/// Plays a song, chant or video inside the app.
///
/// A YouTube link plays in the official embedded player, a direct audio
/// file in the app's own player, and any other page in an in-app web view,
/// so a devotee never loses the app to a browser. "Open outside" stays in
/// the menu for anyone who wants it.
class MediaPlayerScreen extends StatefulWidget {
  const MediaPlayerScreen({super.key, required this.media, required this.day});

  final DevotionalMedia media;
  final DayTheme day;

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

/// Where the YouTube player is loaded from. See [_MediaPlayerScreenState.initState].
const String embedHost = 'https://www.youtube-nocookie.com';

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  YoutubePlayerController? _yt;
  WebViewController? _web;
  ap.AudioPlayer? _audio;
  Duration _pos = Duration.zero;
  Duration _len = Duration.zero;
  bool _playing = false;
  YoutubeError _ytError = YoutubeError.none;
  StreamSubscription<YoutubePlayerValue>? _ytSub;
  StreamSubscription<dynamic>? _s1, _s2, _s3;

  String? get _videoId => widget.media.playback.youtubeId ?? (widget.media.url == null ? null : YoutubePlayerController.convertUrlToId(widget.media.url!));
  late final MantraPlayer _mantra = context.read<MantraPlayer>();

  @override
  void initState() {
    super.initState();
    _mantra.addListener(_applyMute);
    final url = widget.media.url;
    if (url == null) return;
    final kind = widget.media.playback.kind;
    if (_videoId != null) {
      // youtube_player_iframe uses `origin` three ways: as the page's base
      // URL (the Referer YouTube checks), as the player's origin, and as the
      // host the iframe is loaded from. So it must be a YouTube embed host:
      // our API host answered /embed/<id> with a 404, and without a real
      // https referrer YouTube refuses to play (error 152/153).
      // youtube-nocookie.com satisfies all three.
      _yt = YoutubePlayerController.fromVideoId(
        videoId: _videoId!,
        autoPlay: true,
        params: YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true, mute: _mantra.muted, origin: embedHost, playsInline: true),
      );
      // The package opens the YouTube app or the browser when the title or
      // logo is tapped. Its navigation handling is replaced so that a related
      // video plays here and any other link opens in the in-app browser.
      if (!kIsWeb) {
        // The package offers no hook for this; its web view is the only way
        // in. Re-check on a youtube_player_iframe upgrade.
        // ignore: invalid_use_of_internal_member
        _yt!.webViewController.setNavigationDelegate(NavigationDelegate(onNavigationRequest: (r) {
          final u = Uri.tryParse(r.url);
          if (u == null) return NavigationDecision.prevent;
          if (!r.isMainFrame || u.scheme == 'about' || u.scheme == 'data' || u.host == Uri.parse(embedHost).host) return NavigationDecision.navigate;
          final id = u.queryParameters['v'] ?? YoutubePlayerController.convertUrlToId(r.url);
          if (id != null) {
            _yt!.loadVideoById(videoId: id);
          } else if (InAppBrowserScreenState.isWebUri(u) && mounted) {
            InAppBrowserScreen.open(context, r.url);
          }
          return NavigationDecision.prevent;
        }));
      }
      _ytSub = _yt!.stream.listen((v) {
        if (v.error != _ytError && mounted) setState(() => _ytError = v.error);
      });
    } else if (kind == 'audio' || (kind != 'video' && kind != 'vimeo' && isDirectAudio(url, widget.media.sourceType))) {
      _audio = ap.AudioPlayer();
      _s1 = _audio!.onPositionChanged.listen((d) => setState(() => _pos = d));
      _s2 = _audio!.onDurationChanged.listen((d) => setState(() => _len = d));
      _s3 = _audio!.onPlayerStateChanged.listen((s) => setState(() => _playing = s == ap.PlayerState.playing));
      _audio!.setVolume(_mantra.muted ? 0 : 1);
      _audio!.play(ap.UrlSource(url));
    } else if (!kIsWeb) {
      // A Vimeo or other page, or a video file: the in-app web view plays
      // it where it is published.
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Palette.ebony)
        ..setNavigationDelegate(NavigationDelegate(onNavigationRequest: (r) => InAppBrowserScreenState.isWebUri(Uri.tryParse(r.url)) ? NavigationDecision.navigate : NavigationDecision.prevent))
        ..loadRequest(Uri.parse(widget.media.playback.embedUrl ?? url));
    }
  }

  /// The app-wide mute switch reaches whichever player is running.
  void _applyMute() {
    if (_yt != null) _mantra.muted ? _yt!.mute() : _yt!.unMute();
    _audio?.setVolume(_mantra.muted ? 0 : 1);
  }

  @override
  void dispose() {
    _mantra.removeListener(_applyMute);
    _ytSub?.cancel();
    _yt?.close();
    _s1?.cancel();
    _s2?.cancel();
    _s3?.cancel();
    _audio?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final m = widget.media;
    final day = widget.day;
    Widget body;
    if (_yt != null) {
      body = YoutubePlayerScaffold(
        controller: _yt!,
        aspectRatio: 16 / 9,
        builder: (context, player) => ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            player,
            if (_ytError != YoutubeError.none) _Unavailable(error: _ytError, url: m.url!),
            _Details(media: m, day: day),
          ],
        ),
      );
    } else if (_audio != null) {
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Center(child: MediaArt(media: m, day: day, size: 220, radius: 28)),
          const SizedBox(height: 20),
          Slider(
            value: _len.inMilliseconds == 0 ? 0 : (_pos.inMilliseconds / _len.inMilliseconds).clamp(0.0, 1.0),
            onChanged: (v) => _audio!.seek(Duration(milliseconds: (v * _len.inMilliseconds).round())),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(_fmt(_pos), style: theme.textTheme.labelSmall), Text(_fmt(_len), style: theme.textTheme.labelSmall)],
          ),
          Center(
            child: IconButton.filled(
              iconSize: 44,
              onPressed: () => _playing ? _audio!.pause() : _audio!.resume(),
              icon: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
            ),
          ),
          _Details(media: m, day: day),
        ],
      );
    } else if (_web != null) {
      body = Column(
        children: [
          Expanded(child: WebViewWidget(controller: _web!)),
          _Details(media: m, day: day, compact: true),
        ],
      );
    } else {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MediaArt(media: m, day: day, size: 160, radius: 24),
              const SizedBox(height: 16),
              Text(m.url == null ? 'This item has no link yet.' : 'This one plays on its own page.', textAlign: TextAlign.center),
              if (m.url != null) ...[const SizedBox(height: 12), FilledButton.icon(onPressed: () => InAppBrowserScreen.open(context, m.url!, title: m.title), icon: const Icon(Icons.play_arrow_rounded), label: const Text('Play'))],
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          Builder(builder: (context) {
            final muted = context.watch<MantraPlayer>().muted;
            return IconButton(tooltip: muted ? 'Unmute' : 'Mute', onPressed: () => context.read<MantraPlayer>().toggleMuted(), icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded));
          }),
        ],
      ),
      body: body,
    );
  }

  static String _fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}

class _Details extends StatelessWidget {
  const _Details({required this.media, required this.day, this.compact = false});

  final DevotionalMedia media;
  final DayTheme day;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 10 : 18, 20, compact ? 10 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(media.title, style: theme.textTheme.titleLarge),
          if (media.artist != null) Text(media.artist!, style: theme.textTheme.bodyMedium),
          if (!compact && media.description != null) ...[const SizedBox(height: 8), Text(media.description!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45))],
          const SizedBox(height: 8),
          Text(
            [if (media.credit != null) '© ${media.credit}', if (media.license != null) media.license!, if (media.sourceType == 'external') 'Played where it is officially published'].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}

/// Shown under the player when YouTube refuses to play the video here.
/// Most often the owner has disabled embedding, which no player can get
/// around; its YouTube page still plays it, here in the app.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.error, required this.url});

  final YoutubeError error;
  final String url;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final why = switch (error) {
      YoutubeError.notEmbeddable || YoutubeError.sameAsNotEmbeddable => 'Its owner has not allowed it to play inside other apps.',
      YoutubeError.videoNotFound => 'It has been removed or made private.',
      YoutubeError.invalidParam => 'The link does not point at a video.',
      _ => 'YouTube could not play it here.',
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Palette.kumkum.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.kumkum.withValues(alpha: 0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This video cannot play inside the app', style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(why, style: theme.textTheme.bodySmall),
          const SizedBox(height: 10),
          FilledButton.icon(onPressed: () => InAppBrowserScreen.open(context, url), icon: const Icon(Icons.play_circle_outline_rounded), label: const Text('Watch on its YouTube page')),
        ],
      ),
    );
  }
}
