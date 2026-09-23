import 'dart:async';

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

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
  StreamSubscription<dynamic>? _s1, _s2, _s3;

  String? get _videoId => widget.media.url == null ? null : YoutubePlayerController.convertUrlToId(widget.media.url!);

  @override
  void initState() {
    super.initState();
    final url = widget.media.url;
    if (url == null) return;
    if (_videoId != null) {
      _yt = YoutubePlayerController.fromVideoId(videoId: _videoId!, autoPlay: true, params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true));
    } else if (isDirectAudio(url, widget.media.sourceType)) {
      _audio = ap.AudioPlayer();
      _s1 = _audio!.onPositionChanged.listen((d) => setState(() => _pos = d));
      _s2 = _audio!.onDurationChanged.listen((d) => setState(() => _len = d));
      _s3 = _audio!.onPlayerStateChanged.listen((s) => setState(() => _playing = s == ap.PlayerState.playing));
      _audio!.play(ap.UrlSource(url));
    } else if (!kIsWeb) {
      _web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Palette.ebony)
        ..loadRequest(Uri.parse(url));
    }
  }

  @override
  void dispose() {
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
          children: [player, _Details(media: m, day: day)],
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
