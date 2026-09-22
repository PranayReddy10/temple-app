import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/temple_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/day_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../explore/search_screen.dart';
import '../temple/temple_screen.dart';

/// One weekday's sanctum: the deity, mantra, offerings, vrat, devotional
/// media and temples. While open, the whole app wears this day's colour.
class DayScreen extends StatefulWidget {
  const DayScreen({super.key, required this.weekday});

  final int weekday;

  @override
  State<DayScreen> createState() => _DayScreenState();
}

class _DayScreenState extends State<DayScreen> {
  Result<List<DevotionalDay>>? _days;
  late int _weekday = widget.weekday;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DayController>().preview(DayTheme.all[_weekday]));
  }

  Future<void> _load() async {
    setState(() => _days = null);
    final r = await context.read<TempleRepository>().day(_weekday);
    if (mounted) setState(() => _days = r);
  }

  void _switch(int w) {
    setState(() => _weekday = w);
    context.read<DayController>().preview(DayTheme.all[w]);
    _load();
  }

  @override
  void dispose() {
    // Restoring the theme after the route is gone avoids a flash of colour
    // mid-transition; the door closes in this day's colour.
    final ctl = context.read<DayController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => ctl.resetToToday());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final day = DayTheme.all[_weekday];
    final on = day.onAccent();
    final lead = _days?.data.firstOrNull;
    final extras = _days?.data.skip(1).toList() ?? const <DevotionalDay>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: day.accent,
            foregroundColor: on,
            title: Text('${day.sanskritDay} · ${day.dayName}', style: TextStyle(color: on)),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [day.accent, Color.lerp(day.accent, Colors.black, 0.25)!]),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Opacity(opacity: 0.12, child: CustomPaint(painter: LatticePainter(color: on, cell: 32))),
                    Align(alignment: Alignment.bottomCenter, child: GopuramBand(color: on, height: 110, opacity: 0.16, tiers: 7)),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 40),
                          MotifIcon(day.motif, size: 96, color: on, secondary: day.secondary),
                          const SizedBox(height: 10),
                          Text(lead?.deity?.name ?? day.deityName, style: theme.textTheme.displaySmall?.copyWith(color: on)),
                          Text(day.epithet, style: theme.textTheme.bodyMedium?.copyWith(color: on.withValues(alpha: 0.85), fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: _WeekSwitcher(current: _weekday, onSelect: _switch)),
          if (_days?.isOffline == true) const SliverToBoxAdapter(child: OfflineNote()),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
            sliver: SliverToBoxAdapter(child: MantraCard(day: day, mantra: lead?.mantra, transliteration: lead?.mantraTransliteration)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(child: _InfoTile(title: s('offering'), body: day.offering, icon: Icons.local_florist_rounded, color: day.accent)),
                  const SizedBox(width: 12),
                  Expanded(child: _InfoTile(title: s('fasting'), body: day.fastingNote, icon: Icons.brightness_3_rounded, color: day.accent)),
                ],
              ),
            ),
          ),
          if (lead?.significance != null && lead!.significance!.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(child: Text(lead.significance!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))),
            ),
          if (extras.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader(title: 'Also honoured today', motif: Motif.om)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(
                itemCount: extras.length,
                itemBuilder: (context, i) {
                  final d = extras[i];
                  final dt = DayTheme.forDeity(d.deity?.slug);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: MotifIcon(dt.motif, size: 34, color: dt.accent, secondary: dt.secondary),
                      title: Text(d.deity?.name ?? d.title, style: const TextStyle(fontFamily: 'NotoSerif')),
                      subtitle: Text(d.mantraTransliteration ?? d.subtitle ?? ''),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(initial: TempleQuery(deity: d.deity?.slug)))),
                    ),
                  );
                },
              ),
            ),
          ],
          if (lead != null && lead.media.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader(title: 'Bhajans & darshan', motif: Motif.bell, subtitle: 'Credited to their artists, under the licence shown')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.builder(itemCount: lead.media.length, itemBuilder: (context, i) => _MediaTile(media: lead.media[i], accent: day.accent)),
            ),
          ],
          SliverToBoxAdapter(
            child: SectionHeader(
              title: '${s('temples_of')} ${lead?.deity?.name ?? day.deityName}',
              motif: day.motif,
              actionLabel: s('see_all'),
              onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(initial: TempleQuery(deity: lead?.deity?.slug ?? day.deitySlug)))),
            ),
          ),
          if (_days == null)
            const SliverToBoxAdapter(child: SizedBox(height: 140, child: DiyaLoader()))
          else if (lead == null || lead.temples.isEmpty)
            SliverToBoxAdapter(child: EmptyShrine(motif: day.motif, message: 'No temples of ${day.deityName} published yet.'))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              sliver: SliverList.separated(
                itemCount: lead.temples.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) => TempleCard(
                  temple: lead.temples[i],
                  compact: true,
                  onTap: () => enterTemple(context, TempleScreen(slug: lead.temples[i].slug, preview: lead.temples[i]), accent: day.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({required this.current, required this.onSelect});

  final int current;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = DayTheme.all[i];
          final selected = i == current;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => onSelect(i),
            avatar: MotifIcon(d.motif, size: 18, color: selected ? d.onAccent() : d.accent),
            label: Text(d.dayName.substring(0, 3)),
            selectedColor: d.accent,
            labelStyle: TextStyle(color: selected ? d.onAccent() : theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
            showCheckmark: false,
          );
        },
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.title, required this.body, required this.icon, required this.color});

  final String title;
  final String body;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(title.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: color))]),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  const _MediaTile({required this.media, required this.accent});

  final DevotionalMedia media;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (media.type) {
      'video' => Icons.play_circle_fill_rounded,
      'song' || 'audio' => Icons.music_note_rounded,
      _ => Icons.image_rounded,
    };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: accent),
        ),
        title: Text(media.title, style: const TextStyle(fontFamily: 'NotoSerif')),
        subtitle: Text(
          [media.artist, media.durationLabel, media.license].where((e) => e != null && e.isNotEmpty).join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        trailing: media.sourceType == 'external' ? const Icon(Icons.open_in_new_rounded, size: 18) : const Icon(Icons.chevron_right_rounded),
        onTap: media.url == null ? null : () => launchUrl(Uri.parse(media.url!), mode: LaunchMode.externalApplication),
      ),
    );
  }
}
