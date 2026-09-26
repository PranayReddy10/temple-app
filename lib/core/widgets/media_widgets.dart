import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
import '../motifs/architecture.dart';
import '../motifs/motif.dart';
import '../state/mantra_player.dart';
import '../theme/day_theme.dart';
import 'package:provider/provider.dart';

import '../../features/media/in_app_browser.dart';
import '../../features/media/media_player_screen.dart';
import '../../features/media/now_playing_screen.dart';
import '../audio/audio_queue.dart';
import '../theme/palette.dart';
import 'app_image.dart';

/// Items that show as a video poster strip: anything that embeds or is a
/// video file, whatever type the editor filed it under.
bool isVideoLike(DevotionalMedia m) => m.type == 'video' || m.playback.needsEmbed || m.playback.kind == 'video';

IconData mediaIcon(String? type) => switch (type) {
      'video' => Icons.play_circle_fill_rounded,
      'chant' => Icons.self_improvement_rounded,
      'song' || 'audio' => Icons.music_note_rounded,
      _ => Icons.image_rounded,
    };

/// Plays inside the app. On the web build, where the in-app web view is not
/// available, a non-YouTube link opens in a new tab instead.
///
/// A recording plays in the app's own player, which keeps going when the
/// screen locks; [queue] (the list it was tapped in) lines up what comes
/// after, so a song is followed by the next one rather than silence.
Future<void> openMedia(BuildContext context, DevotionalMedia m, {DayTheme? day, List<DevotionalMedia>? queue}) async {
  if (m.url == null) return;
  if (AudioQueue.isPlayable(m)) {
    final ctl = context.read<AudioQueueController?>();
    if (ctl != null) {
      unawaited(ctl.playQueue(queue ?? [m], start: m));
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => NowPlayingScreen(day: day ?? DayTheme.today())));
      return;
    }
  }
  // Everything plays inside the app: a video in the embedded player, audio
  // in the app's own player, and a search or any other page in the in-app
  // browser. Only the web build, which has no web view, opens a new tab.
  final isYoutube = m.url!.contains('youtube.com') || m.url!.contains('youtu.be');
  final hasVideo = m.playback.youtubeId != null || YoutubePlayerController.convertUrlToId(m.url!) != null;
  if (isYoutube && !hasVideo) {
    await InAppBrowserScreen.open(context, m.url!, title: m.title);
    return;
  }
  if (kIsWeb && !isYoutube && !isDirectAudio(m.url, m.sourceType)) {
    await InAppBrowserScreen.open(context, m.url!, title: m.title);
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MediaPlayerScreen(media: m, day: day ?? DayTheme.today())));
}

/// A list row for a song, chant or video, with its rights line.
class MediaTile extends StatelessWidget {
  const MediaTile({super.key, required this.media, required this.day, this.queue});

  final DevotionalMedia media;
  final DayTheme day;

  /// The list this row sits in; what plays after it.
  final List<DevotionalMedia>? queue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        leading: MediaArt(media: media, day: day, size: 52),
        title: Text(media.title, style: const TextStyle(fontFamily: 'NotoSerif')),
        subtitle: Text(
          [media.description, media.artist, media.durationLabel, media.license].where((e) => e != null && e.isNotEmpty).join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall,
        ),
        trailing: Builder(builder: (context) {
          final ctl = context.watch<AudioQueueController?>();
          final playingThis = ctl != null && ctl.isCurrent(media) && ctl.isPlaying;
          return Icon(playingThis ? Icons.graphic_eq_rounded : Icons.play_circle_outline_rounded, size: 20, color: playingThis ? day.accent : null);
        }),
        onTap: media.url == null ? null : () => openMedia(context, media, day: day, queue: queue),
      ),
    );
  }
}

/// A square poster: the thumbnail when the API has one, otherwise a painted
/// tile in the deity's colour with the media-type icon.
class MediaArt extends StatelessWidget {
  const MediaArt({super.key, required this.media, required this.day, this.size = 120, this.radius = 14});

  final DevotionalMedia media;
  final DayTheme day;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final painted = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [day.accent, Color.lerp(day.accent, Palette.deep, 0.55)!]),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(opacity: 0.18, child: CustomPaint(painter: LatticePainter(color: Colors.white, cell: size / 4))),
          Positioned(right: -size * 0.15, bottom: -size * 0.15, child: Opacity(opacity: 0.25, child: MotifIcon(day.motif, size: size * 0.8, color: Colors.white))),
          Center(child: Icon(mediaIcon(media.type), color: Colors.white, size: size * 0.42)),
        ],
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: size,
        height: size,
        child: media.posterUrl == null
            ? painted
            : Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(media.posterUrl!, placeholder: painted, decodeWidth: 400),
                  Center(child: Icon(mediaIcon(media.type), color: Colors.white, size: size * 0.36, shadows: const [Shadow(blurRadius: 8, color: Colors.black54)])),
                ],
              ),
      ),
    );
  }
}

/// Poster card for horizontal strips (Home, temple overview).
class MediaCard extends StatelessWidget {
  const MediaCard({super.key, required this.media, required this.day, this.width = 150});

  final DevotionalMedia media;
  final DayTheme day;
  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: media.url == null ? null : () => openMedia(context, media, day: day),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaArt(media: media, day: day, size: width, radius: 16),
            const SizedBox(height: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(child: Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(fontFamily: 'NotoSerif', letterSpacing: 0))),
                  Text(
                    media.artist ?? media.durationLabel ?? _typeLabel(context, media.type),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _typeLabel(BuildContext context, String? type) => switch (type) {
        'video' => S.of(context)('videos'),
        'chant' => S.of(context)('chants'),
        _ => S.of(context)('songs'),
      };
}

/// Media grouped into chants, songs and videos, each under its own heading.
class MediaSections extends StatelessWidget {
  const MediaSections({super.key, required this.media, required this.day, this.padding = const EdgeInsets.symmetric(horizontal: 20)});

  final List<DevotionalMedia> media;
  final DayTheme day;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final groups = <String, List<DevotionalMedia>>{
      s('chants'): media.where((m) => m.type == 'chant').toList(),
      s('songs'): media.where((m) => m.type == 'song' || m.type == 'audio').toList(),
      s('videos'): media.where((m) => m.type == 'video').toList(),
      'Photos': media.where((m) => m.type == 'photo').toList(),
    }..removeWhere((_, v) => v.isEmpty);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final g in groups.entries) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
              child: Row(
                children: [
                  Icon(mediaIcon(g.value.first.type), size: 18, color: day.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(g.key, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif'))),
                  if (context.read<AudioQueueController?>() != null) PlayAllButton(media: g.value, day: day),
                ],
              ),
            ),
            for (final m in g.value) MediaTile(media: m, day: day, queue: g.value),
          ],
          const SizedBox(height: 8),
          Text(s('media_note'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
      ),
    );
  }
}

/// Full-screen photo viewer with pinch zoom, caption and credit.
class PhotoViewer extends StatefulWidget {
  const PhotoViewer({super.key, required this.photos, this.initial = 0, this.deitySlug});

  final List<Photo> photos;
  final int initial;
  final String? deitySlug;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _c = PageController(initialPage: widget.initial);
  late int _i = widget.initial;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photos[_i];
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('${_i + 1} / ${widget.photos.length}')),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _c,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (_, i) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: AppImage(
                    // The medium rendition: an original can be tens of
                    // megabytes and never finish on a temple-town network.
                    widget.photos[i].medium ?? widget.photos[i].best ?? '',
                    fit: BoxFit.contain,
                    placeholder: Center(child: MotifIcon(DayTheme.forDeity(widget.deitySlug).motif, size: 120, color: Palette.gold)),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            color: Colors.black,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (p.caption != null) Text(p.caption!, style: const TextStyle(color: Palette.sandal, fontFamily: 'NotoSerif', fontSize: 16)),
                if (p.credit != null || p.license != null)
                  Text([if (p.credit != null) '© ${p.credit}', if (p.license != null) p.license!].join(' · '), style: TextStyle(color: Palette.sandal.withValues(alpha: 0.7), fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
