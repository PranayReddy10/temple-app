import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_queue.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/state/mantra_player.dart';
import '../../core/theme/day_theme.dart';
import '../../core/widgets/media_widgets.dart';

/// The full player for a song or chant: art, scrubber, previous / play /
/// next, and what comes after. What plays here keeps playing when the
/// screen is locked; the lock screen carries the same controls.
class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key, required this.day});

  final DayTheme day;

  static String fmt(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<AudioQueueController>();
    final m = ctl.current;
    if (m == null) {
      return Scaffold(appBar: AppBar(title: Text(s('now_playing'))), body: Center(child: Text(s('no_media'))));
    }
    final len = ctl.duration ?? Duration.zero;
    final pos = ctl.position > len && len > Duration.zero ? len : ctl.position;
    final upNext = ctl.queue.upNext;
    return Scaffold(
      appBar: AppBar(
        title: Text(s('now_playing')),
        actions: [
          Builder(builder: (context) {
            final muted = context.watch<MantraPlayer>().muted;
            return IconButton(tooltip: muted ? 'Unmute' : 'Mute', onPressed: () => context.read<MantraPlayer>().toggleMuted(), icon: Icon(muted ? Icons.volume_off_rounded : Icons.volume_up_rounded));
          }),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          Center(child: MediaArt(media: m, day: day, size: 240, radius: 32)),
          const SizedBox(height: 20),
          Text(m.title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'NotoSerif')),
          if (m.artist != null) Text(m.artist!, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 16),
          Slider(
            value: len.inMilliseconds == 0 ? 0 : (pos.inMilliseconds / len.inMilliseconds).clamp(0.0, 1.0),
            activeColor: day.accent,
            onChanged: len.inMilliseconds == 0 ? null : (v) => ctl.seek(Duration(milliseconds: (v * len.inMilliseconds).round())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(fmt(pos), style: theme.textTheme.labelSmall), Text(fmt(len), style: theme.textTheme.labelSmall)]),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(iconSize: 36, onPressed: ctl.queue.hasPrevious ? ctl.previous : null, icon: const Icon(Icons.skip_previous_rounded)),
              const SizedBox(width: 16),
              SizedBox(
                width: 72,
                height: 72,
                child: IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: day.accent, foregroundColor: day.onAccent()),
                  iconSize: 40,
                  onPressed: ctl.toggle,
                  icon: ctl.isLoading && !ctl.isPlaying ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)) : Icon(ctl.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                ),
              ),
              const SizedBox(width: 16),
              IconButton(iconSize: 36, onPressed: ctl.queue.hasNext ? ctl.next : null, icon: const Icon(Icons.skip_next_rounded)),
            ],
          ),
          const SizedBox(height: 6),
          Center(child: Text('Keeps playing with the screen locked; controls are on the lock screen too.', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))),
          if (m.description != null) ...[const SizedBox(height: 16), Text(m.description!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45))],
          const SizedBox(height: 8),
          Text(
            [if (m.credit != null) '© ${m.credit}', if (m.license != null) m.license!].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
          ),
          if (upNext.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(s('up_next'), style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif')),
            const SizedBox(height: 8),
            for (var i = 0; i < upNext.length; i++)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MediaArt(media: upNext[i], day: day, size: 44, radius: 10),
                title: Text(upNext[i].title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(upNext[i].artist ?? upNext[i].durationLabel ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.play_arrow_rounded, size: 20),
                onTap: () => ctl.skipTo((ctl.queue.index + 1 + i) % ctl.queue.items.length),
              ),
          ],
        ],
      ),
    );
  }
}

/// The bar above the tabs while something plays: title, play / pause, next.
/// Tapping it opens the full player. Hidden when nothing is queued.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final ctl = context.watch<AudioQueueController>();
    final m = ctl.current;
    if (m == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final day = DayTheme.today();
    final len = ctl.duration ?? Duration.zero;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => NowPlayingScreen(day: day))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: len.inMilliseconds == 0 ? null : (ctl.position.inMilliseconds / len.inMilliseconds).clamp(0.0, 1.0), minHeight: 2, color: day.accent, backgroundColor: Colors.transparent),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
              child: Row(
                children: [
                  MediaArt(media: m, day: day, size: 40, radius: 10),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelLarge?.copyWith(fontFamily: 'NotoSerif', letterSpacing: 0)),
                        Text(m.artist ?? (m.type == 'chant' ? 'Chant' : 'Bhajan'), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  IconButton(onPressed: ctl.toggle, icon: Icon(ctl.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, color: day.accent)),
                  IconButton(onPressed: ctl.queue.hasNext ? ctl.next : null, icon: const Icon(Icons.skip_next_rounded)),
                  IconButton(tooltip: 'Stop', onPressed: ctl.stop, icon: Icon(Icons.close_rounded, color: theme.colorScheme.outline, size: 20)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Play every recording in a list, from the first. Where a temple or a
/// weekday lists its songs.
class PlayAllButton extends StatelessWidget {
  const PlayAllButton({super.key, required this.media, required this.day});

  final List<DevotionalMedia> media;
  final DayTheme day;

  @override
  Widget build(BuildContext context) {
    final playable = media.where(AudioQueue.isPlayable).toList();
    if (playable.length < 2) return const SizedBox.shrink();
    return FilledButton.tonalIcon(
      onPressed: () {
        context.read<AudioQueueController>().playQueue(playable);
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => NowPlayingScreen(day: day)));
      },
      icon: const Icon(Icons.playlist_play_rounded),
      label: Text('${S.of(context)('play_all')} · ${playable.length}'),
    );
  }
}
