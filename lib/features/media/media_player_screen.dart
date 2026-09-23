import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../../core/state/mantra_player.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/media_widgets.dart';

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
      // The embed's origin must be a real https site. Left at the package
      // default of www.youtube.com, YouTube answers "video unavailable" for
      // a great many videos; the API's own host is a site we control.
      final origin = _httpsOrigin(context.read<ApiClient>().baseUrl);
      _yt = YoutubePlayerController.fromVideoId(
        videoId: _videoId!,
        autoPlay: true,
        params: YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true, mute: _mantra.muted, origin: origin, playsInline: true),
      );
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
        ..loadRequest(Uri.parse(widget.media.playback.embedUrl ?? url));
    }
  }

  /// The app-wide mute switch reaches whichever player is running.
  void _applyMute() {
    if (_yt != null) _mantra.muted ? _yt!.mute() : _yt!.unMute();
    _audio?.setVolume(_mantra.muted ? 0 : 1);
  }

  static String _httpsOrigin(String base) {
    final u = Uri.tryParse(base);
    if (u == null || u.host.isEmpty || u.host == 'localhost' || u.host == '127.0.0.1') return 'https://www.youtube.com';
    return Uri(scheme: 'https', host: u.host, port: u.hasPort && u.port != 80 && u.port != 443 ? u.port : null).toString();
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
              Text(m.url == null ? 'This item has no link yet.' : 'This link opens in your browser on this platform.', textAlign: TextAlign.center),
              if (m.url != null) ...[const SizedBox(height: 12), FilledButton.icon(onPressed: () => launchUrl(Uri.parse(m.url!), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded), label: const Text('Open'))],
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
          if (m.url != null)
            IconButton(tooltip: 'Open outside the app', onPressed: () => launchUrl(Uri.parse(m.url!), mode: LaunchMode.externalApplication), icon: const Icon(Icons.open_in_new_rounded)),
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
/// around; the video still plays in the YouTube app.
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
          FilledButton.icon(onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication), icon: const Icon(Icons.play_circle_outline_rounded), label: const Text('Watch on YouTube')),
        ],
      ),
    );
  }
}
