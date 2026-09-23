import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/models.dart';
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
          Text(
            trust.isStale ? '$label · stale' : label,
            style: TextStyle(color: color, fontSize: compact ? 10 : 12, fontWeight: FontWeight.w700, letterSpacing: 0.4),
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
    return Image.network(
      url!,
      fit: fit,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) => progress == null ? child : placeholder,
    );
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
          AspectRatio(
            aspectRatio: 16 / 10,
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
                  Row(
                    children: [
                      TrustBadge(trust: temple.trust, compact: true),
                      if (temple.distanceKm != null) ...[
                        const SizedBox(width: 6),
                        _Pill(text: '${temple.distanceKm!.toStringAsFixed(temple.distanceKm! < 10 ? 1 : 0)} km', color: day.accent),
                      ],
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
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif')),
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
  const MantraCard({super.key, required this.day, this.mantra, this.transliteration, this.title, this.meaning});

  final DayTheme day;
  final String? title;
  final String? meaning;
  final String? mantra;
  final String? transliteration;

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
      child: Padding(
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
      child: imageUrl == null ? Center(child: motif) : Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: motif)),
    );
  }
}
