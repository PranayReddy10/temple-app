import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/temple_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/day_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/widgets/media_widgets.dart';
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
  // Cached here because dispose() may not look up ancestors through context.
  late final DayController _dayCtl = context.read<DayController>();

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dayCtl.preview(DayTheme.all[_weekday]);
    });
  }

  Future<void> _load() async {
    setState(() => _days = null);
    final r = await context.read<TempleRepository>().day(_weekday);
    if (mounted) setState(() => _days = r);
  }

  void _switch(int w) {
    setState(() => _weekday = w);
    _dayCtl
      ..endPreview()
      ..preview(DayTheme.all[w]);
    _load();
  }

  @override
  void dispose() {
    // Ending the preview after the route is gone avoids a flash of colour
    // mid-transition; the door closes in this day's colour.
    final ctl = _dayCtl;
    WidgetsBinding.instance.addPostFrameCallback((_) => ctl.endPreview());
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
            title: CollapsedTitle(text: '${day.sanskritDay} · ${day.dayName}', color: on, expandedHeight: 300),
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
                          DeityPortrait(day: day, imageUrl: lead?.deity?.imageUrl, size: 110, color: on),
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
            sliver: SliverToBoxAdapter(
              child: MantraCard(
                day: day,
                mantra: lead?.mantra,
                transliteration: lead?.mantraTransliteration,
                meaning: lead?.mantraAudio?.meaning ?? lead?.deity?.mantraMeaning,
                playKey: 'day-${day.weekday}',
                audio: lead?.mantraAudio?.audio,
                audioUrl: lead?.mantraAudio?.audio == null ? lead?.media.where((m) => m.type == 'chant' && m.playback.kind == 'audio').firstOrNull?.url : null,
              ),
            ),
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
            SliverToBoxAdapter(child: SectionHeader(title: s('songs_videos'), motif: Motif.bell, subtitle: 'For ${lead.deity?.name ?? day.deityName}')),
            if (lead.media.any(isVideoLike))
            SliverToBoxAdapter(
              child: SizedBox(
                height: scaledHeight(context, 206),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: lead.media.where(isVideoLike).take(8).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => MediaCard(media: lead.media.where(isVideoLike).elementAt(i), day: day, width: 150),
                ),
              ),
            ),
            SliverToBoxAdapter(child: MediaSections(media: lead.media.where((m) => !isVideoLike(m)).toList(), day: day)),
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
          Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Expanded(child: Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: color)))]),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}
