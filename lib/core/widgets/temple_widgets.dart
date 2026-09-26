import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../l10n/strings.dart';
import '../api/api_client.dart';
import '../models/models.dart';
import '../state/mantra_player.dart';
import 'app_image.dart';
import '../../features/media/media_player_screen.dart';
import '../motifs/architecture.dart';
import '../motifs/motif.dart';
import '../theme/day_theme.dart';
import '../theme/palette.dart';

/// A gopuram skyline as a header background, tinted by [color].
class GopuramBand extends StatelessWidget {
  const GopuramBand({super.key, required this.color, this.height = 96, this.opacity = 0.16, this.tiers = 5});

  final Color color;
  final double height;
  final double opacity;
  final int tiers;

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: GopuramPainter(color: color, opacity: opacity, tiers: tiers)),
        ),
      );
}

class KolamDivider extends StatelessWidget {
  const KolamDivider({super.key, this.color, this.height = 28, this.dense = false});

  final Color? color;
  final double height;
  final bool dense;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: KolamPainter(color: color ?? Theme.of(context).colorScheme.primary.withValues(alpha: 0.45), dense: dense)),
      );
}

/// Section heading with a small motif and an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.motif, this.actionLabel, this.onAction, this.subtitle});

  final String title;
  final Motif? motif;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (motif != null) ...[
            MotifIcon(motif!, size: 22, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleLarge),
                if (subtitle != null) Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
              ],
            ),
          ),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Trust level as a small pill. Official, verified, community and unverified
/// stay visually distinct: the whole point of carrying the level to the device.
class TrustBadge extends StatelessWidget {
  const TrustBadge({super.key, required this.trust, this.compact = false});

  final Trust trust;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (Color color, IconData icon) = switch (trust.level) {
      TrustLevel.official => (Palette.tulsi, Icons.verified_rounded),
      TrustLevel.verified => (const Color(0xFF1F5F8B), Icons.check_circle_rounded),
      TrustLevel.community => (Palette.saffron, Icons.groups_rounded),
      TrustLevel.unverified => (Palette.stone, Icons.help_outline_rounded),
    };
    final label = trust.label ?? trust.level.label;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          // Flexible: the badge sits in narrow columns (guide answers, cards)
          // where "Community · stale" at large text is wider than the room.
          Flexible(
            child: Text(
              trust.isStale ? '$label · stale' : label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: compact ? 10 : 12, fontWeight: FontWeight.w700, letterSpacing: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Network photo with a deity-motif placeholder when there is none.
class TempleImage extends StatelessWidget {
  const TempleImage({super.key, this.url, this.deitySlug, this.fit = BoxFit.cover, this.motifSize = 56});

  final String? url;
  final String? deitySlug;
  final BoxFit fit;
  final double motifSize;

  @override
  Widget build(BuildContext context) {
    final day = DayTheme.forDeity(deitySlug);
    final placeholder = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [day.accent.withValues(alpha: 0.85), Color.lerp(day.accent, Palette.deep, 0.5)!],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Opacity(opacity: 0.22, child: CustomPaint(painter: LatticePainter(color: Colors.white, cell: 34))),
          Align(alignment: Alignment.bottomCenter, child: GopuramBand(color: Colors.black, opacity: 0.25, height: motifSize * 1.4)),
          Center(child: MotifIcon(day.motif, size: motifSize, color: Colors.white.withValues(alpha: 0.9), secondary: day.secondary)),
        ],
      ),
    );
    if (url == null || url!.isEmpty) return placeholder;
    return AppImage(url!, fit: fit, placeholder: placeholder, decodeWidth: 800);
  }
}

/// Search-result and carousel card for one temple.
class TempleCard extends StatelessWidget {
  const TempleCard({super.key, required this.temple, required this.onTap, this.width, this.compact = false, this.trailing});

  final TempleSummary temple;
  final VoidCallback onTap;
  final double? width;
  final bool compact;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = DayTheme.forDeity(temple.deity?.slug);
    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: compact ? _compact(theme, day) : _tall(theme, day),
      ),
    );
    return width == null ? card : SizedBox(width: width, child: card);
  }

  Widget _tall(ThemeData theme, DayTheme day) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The image takes whatever the text leaves, so a larger font never
          // pushes the card past its strip.
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                TempleImage(url: temple.primaryPhoto?.best, deitySlug: temple.deity?.slug),
                Positioned(left: 10, top: 10, child: TrustBadge(trust: temple.trust, compact: true)),
                if (temple.distanceKm != null)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: _Pill(text: '${temple.distanceKm!.toStringAsFixed(temple.distanceKm! < 10 ? 1 : 0)} km', color: Palette.deep),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(temple.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif', fontSize: 17)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    MotifIcon(day.motif, size: 14, color: day.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        [temple.deity?.name, temple.location.short].where((e) => e != null && e.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _compact(ThemeData theme, DayTheme day) => Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(width: 72, height: 72, child: TempleImage(url: temple.primaryPhoto?.thumbnail ?? temple.primaryPhoto?.best, deitySlug: temple.deity?.slug, motifSize: 30)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(temple.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif')),
                  const SizedBox(height: 4),
                  Text(
                    [temple.deity?.name, temple.location.short].where((e) => e != null && e.isNotEmpty).join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 6),
                  // Wraps: a long trust label in Telugu beside the distance
                  // does not fit one line of a 280-wide card at large text.
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      TrustBadge(trust: temple.trust, compact: true),
                      if (temple.distanceKm != null) _Pill(text: '${temple.distanceKm!.toStringAsFixed(temple.distanceKm! < 10 ? 1 : 0)} km', color: day.accent),
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

/// A flickering diya used as the loading indicator.
class DiyaLoader extends StatefulWidget {
  const DiyaLoader({super.key, this.size = 56, this.label});

  final double size;
  final String? label;

  @override
  State<DiyaLoader> createState() => _DiyaLoaderState();
}

class _DiyaLoaderState extends State<DiyaLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Transform.scale(
              scaleY: 0.9 + _c.value * 0.2,
              alignment: Alignment.bottomCenter,
              child: MotifIcon(Motif.diya, size: widget.size, color: color, secondary: Palette.turmeric),
            ),
          ),
          if (widget.label != null) ...[
            const SizedBox(height: 12),
            Text(widget.label!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

/// A quiet note that the data on screen is the bundled fallback.
class OfflineNote extends StatelessWidget {
  const OfflineNote({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.turmeric.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.turmeric.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 16, color: Palette.vermilion),
          const SizedBox(width: 8),
          Expanded(child: Text(S.of(context)('offline_note'), style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// A tile with a carved-stone lattice background, for categories and states.
class StoneTile extends StatelessWidget {
  const StoneTile({super.key, required this.title, this.subtitle, this.motif, this.icon, required this.onTap, this.color});

  final String title;
  final String? subtitle;
  final Motif? motif;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Positioned.fill(child: Opacity(opacity: 0.35, child: CustomPaint(painter: LatticePainter(color: c.withValues(alpha: 0.35), cell: 22)))),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (motif != null) MotifIcon(motif!, size: 30, color: c) else if (icon != null) Icon(icon, color: c, size: 28),
                  const Spacer(),
                  Flexible(child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif'))),
                  if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A mantra in Devanagari with its transliteration, framed by a torana.
class MantraCard extends StatelessWidget {
  const MantraCard({super.key, required this.day, this.mantra, this.transliteration, this.title, this.meaning, this.playKey, this.audioUrl, this.audio});

  final DayTheme day;
  final String? title;
  final String? meaning;

  /// When set, the card can play the mantra: [audioUrl] as a recording when
  /// there is one, otherwise chanted by the device voice.
  final String? playKey;
  final String? audioUrl;
  final String? mantra;
  final String? transliteration;

  /// The recording attached in the admin panel, when there is one.
  final DevotionalMedia? audio;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: day.accent.withValues(alpha: 0.4)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -30,
            left: 0,
            right: 0,
            child: SizedBox(height: 44, child: CustomPaint(painter: ToranaPainter(color: day.accent.withValues(alpha: 0.6), strokeWidth: 2, scallops: 13))),
          ),
          Column(
            children: [
              Text((title ?? S.of(context)('mantra_of_day')).toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 2, color: day.accent)),
              const SizedBox(height: 10),
              Text(mantra ?? day.mantra, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'NotoSerif', height: 1.3)),
              const SizedBox(height: 6),
              Text(transliteration ?? day.transliteration, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withValues(alpha: 0.75))),
              if (meaning != null && meaning!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(meaning!, textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
              ],
              if (playKey != null) ...[
                const SizedBox(height: 12),
                MantraControls(playKey: playKey!, text: mantra ?? day.mantra, audioUrl: audioUrl, audio: audio, accent: day.accent, day: day),
                if (audio != null && (audio!.artist != null || audio!.license != null))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text([audio!.title, audio!.artist, audio!.license].whereType<String>().where((e) => e.isNotEmpty).join(' · '), textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                  ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Empty-state placeholder with a motif and a line of copy.
class EmptyShrine extends StatelessWidget {
  const EmptyShrine({super.key, required this.motif, required this.message, this.action});

  final Motif motif;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MotifIcon(motif, size: 72, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'NotoSerif')),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}


/// The deity's image when the API has one, the painted motif otherwise.
class DeityPortrait extends StatelessWidget {
  const DeityPortrait({super.key, required this.day, this.imageUrl, this.size = 72, this.color});

  final DayTheme day;
  final String? imageUrl;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final on = color ?? day.onAccent();
    final motif = MotifIcon(day.motif, size: size * 0.6, color: on, secondary: day.secondary);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: on.withValues(alpha: 0.12), border: Border.all(color: on.withValues(alpha: 0.35))),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null ? Center(child: motif) : AppImage(imageUrl!, placeholder: Center(child: motif), decodeWidth: 240),
    );
  }
}


/// Play / stop and mute for a mantra, bound to the app-wide [MantraPlayer].
class MantraControls extends StatelessWidget {
  const MantraControls({super.key, required this.playKey, required this.text, this.audioUrl, this.audio, required this.accent, this.compact = false, this.onColor, this.day});

  final String playKey;
  final String text;

  /// A direct audio URL, when the caller found one itself.
  final String? audioUrl;

  /// The recording from the API. An audio file plays here and loops; a
  /// YouTube or Vimeo recording opens in the embedded player; anything
  /// else falls back to the device voice.
  final DevotionalMedia? audio;
  final Color accent;
  final bool compact;
  final Color? onColor;
  final DayTheme? day;

  @override
  Widget build(BuildContext context) {
    final player = context.watch<MantraPlayer>();
    final playing = player.isPlayingKey(playKey);
    final fg = onColor ?? accent;
    final kind = audio?.playback.kind;
    final rawDirect = kind == 'audio' ? audio!.url : (audioUrl ?? (kind == null && audio?.playback.isPlayable == true ? audio!.url : null));
    final base = context.read<ApiClient?>()?.baseUrl;
    final direct = rawDirect == null ? null : (base == null ? rawDirect : AppImage.resolve(rawDirect, base));
    final embeds = audio != null && (audio!.playback.needsEmbed || kind == 'video') && audio!.url != null;
    final label = playing ? 'Stop' : embeds ? 'Play recording' : direct != null ? 'Play recording' : 'Chant';
    void onPressed() {
      if (embeds && !playing) {
        player.stop();
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => MediaPlayerScreen(media: audio!, day: day ?? DayTheme.today())));
        return;
      }
      player.toggle(key: playKey, text: text, audioUrl: direct);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (compact)
          IconButton(
            tooltip: label,
            style: IconButton.styleFrom(foregroundColor: fg, side: BorderSide(color: fg.withValues(alpha: 0.5))),
            onPressed: onPressed,
            icon: Icon(playing ? Icons.stop_rounded : embeds ? Icons.play_circle_fill_rounded : Icons.play_arrow_rounded),
          )
        else
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(foregroundColor: fg, backgroundColor: fg.withValues(alpha: 0.12)),
            onPressed: onPressed,
            icon: Icon(playing ? Icons.stop_rounded : embeds ? Icons.play_circle_fill_rounded : Icons.play_arrow_rounded),
            label: Text(label),
          ),
        const SizedBox(width: 6),
        IconButton(
          tooltip: player.muted ? 'Unmute' : 'Mute',
          style: IconButton.styleFrom(foregroundColor: fg),
          onPressed: player.toggleMuted,
          icon: Icon(player.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
        ),
      ],
    );
  }
}

/// Strip heights that grow with the user's font size, so a larger text
/// setting never overflows a fixed-height list.
double scaledHeight(BuildContext context, double base) {
  final f = MediaQuery.textScalerOf(context).scale(1.0);
  return base * (1 + (f - 1) * 0.7);
}


/// An app-bar title that is invisible while the header is expanded and
/// fades in as it collapses, so it never sits on top of the hero content.
class CollapsedTitle extends StatelessWidget {
  const CollapsedTitle({super.key, required this.text, required this.color, required this.expandedHeight});

  final String text;
  final Color color;
  final double expandedHeight;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    var t = 1.0;
    if (settings != null) {
      final range = (settings.maxExtent - settings.minExtent).clamp(1.0, double.infinity);
      t = 1 - ((settings.currentExtent - settings.minExtent) / range).clamp(0.0, 1.0);
      // Only the last third of the collapse shows the title.
      t = ((t - 0.66) / 0.34).clamp(0.0, 1.0);
    }
    return Opacity(opacity: t, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color)));
  }
}
