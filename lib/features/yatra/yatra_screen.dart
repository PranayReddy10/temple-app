import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/temple_repository.dart';
import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/offline_pack_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/yatra_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../explore/search_screen.dart';
import '../temple/temple_screen.dart';

/// Yatra: plan multi-temple pilgrimages by day, then walk them in Yatra mode.
///
/// Drawn as a winding pilgrim path: each yatra is a milestone card with its
/// deity's motif and progress along the route.
class YatraScreen extends StatelessWidget {
  const YatraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<YatraController>();
    final top = MediaQuery.paddingOf(context).top;
    final active = ctl.active;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _create(context), icon: const Icon(Icons.add_rounded), label: Text(s('new_yatra'))),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 16, 20, 8),
              child: Row(
                children: [
                  Expanded(child: Text(s('my_yatras'), style: theme.textTheme.headlineMedium)),
                  MotifIcon(Motif.diya, size: 30, color: theme.colorScheme.primary, secondary: Palette.turmeric),
                ],
              ),
            ),
          ),
          if (active != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: _ActiveBanner(yatra: active, onOpen: () => enterTemple(context, YatraDetailScreen(id: active.id), accent: DayTheme.forDeity(active.deitySlug).accent)),
              ),
            ),
          if (ctl.yatras.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: EmptyShrine(motif: Motif.diya, message: s('no_yatras')))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              sliver: SliverList.separated(
                itemCount: ctl.yatras.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final y = ctl.yatras[i];
                  final day = DayTheme.forDeity(y.deitySlug);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => enterTemple(context, YatraDetailScreen(id: y.id), accent: day.accent),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                                  child: Center(child: MotifIcon(day.motif, size: 28, color: day.accent, secondary: day.secondary)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(y.name, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif')),
                                      Text('${y.stopCount} temples · ${y.days.length} ${y.days.length == 1 ? 'day' : 'days'}${y.startDate != null ? ' · from ${_date(y.startDate!)}' : ''}', style: theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                if (y.isComplete) const Icon(Icons.workspace_premium_rounded, color: Palette.gold),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _RouteLine(stops: y.allStops.toList(), accent: day.accent),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static Future<void> _create(BuildContext context) async {
    final ctl = context.read<YatraController>();
    final name = TextEditingController();
    String? deity;
    DateTime? start;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.of(context)('new_yatra'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: name, autofocus: true, decoration: const InputDecoration(hintText: 'Name, e.g. Jyotirlinga darshan 2026')),
              const SizedBox(height: 12),
              Text('Devoted to', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final d in DayTheme.all)
                    ChoiceChip(
                      avatar: MotifIcon(d.motif, size: 16, color: d.accent),
                      label: Text(d.deityName),
                      selected: deity == d.deitySlug,
                      onSelected: (v) => setSheet(() => deity = v ? d.deitySlug : null),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(context: context, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 730)), initialDate: DateTime.now());
                  if (picked != null) setSheet(() => start = picked);
                },
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text(start == null ? 'Start date (optional)' : _date(start!)),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Create')),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    final y = await ctl.create(name.text.trim().isEmpty ? 'My yatra' : name.text.trim(), deitySlug: deity, startDate: start);
    if (context.mounted) enterTemple(context, YatraDetailScreen(id: y.id), accent: DayTheme.forDeity(deity).accent);
  }
}

class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({required this.yatra, required this.onOpen});

  final Yatra yatra;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = DayTheme.forDeity(yatra.deitySlug);
    final next = yatra.allStops.where((s) => !s.done).firstOrNull;
    return Material(
      color: day.accent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              MotifIcon(Motif.diya, size: 36, color: day.onAccent(), secondary: Palette.turmeric),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${S.of(context)('yatra_mode').toUpperCase()} · ${yatra.name}', style: theme.textTheme.labelSmall?.copyWith(color: day.onAccent(), letterSpacing: 1.5)),
                    Text(next == null ? 'All stops complete. Om Shanti.' : 'Next: ${next.name}', style: theme.textTheme.titleMedium?.copyWith(color: day.onAccent(), fontFamily: 'NotoSerif')),
                    Text('${yatra.doneCount} of ${yatra.stopCount} done', style: theme.textTheme.bodySmall?.copyWith(color: day.onAccent().withValues(alpha: 0.85))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: day.onAccent()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stops as beads on a thread, done beads filled.
class _RouteLine extends StatelessWidget {
  const _RouteLine({required this.stops, required this.accent});

  final List<YatraStop> stops;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (stops.isEmpty) return Text('No temples yet. Add one from Explore or a temple page.', style: Theme.of(context).textTheme.bodySmall);
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          for (var i = 0; i < stops.length && i < 12; i++) ...[
            Tooltip(
              message: stops[i].name,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: stops[i].done ? accent : Colors.transparent,
                  border: Border.all(color: accent, width: 2),
                ),
                child: stops[i].done ? Icon(Icons.check_rounded, size: 11, color: DayTheme.forDeity(stops[i].deitySlug).onAccent()) : null,
              ),
            ),
            if (i < stops.length - 1 && i < 11) Expanded(child: Container(height: 2, color: accent.withValues(alpha: stops[i].done ? 1 : 0.3))),
          ],
          if (stops.length > 12) Text(' +${stops.length - 12}', style: TextStyle(color: accent, fontSize: 12)),
        ],
      ),
    );
  }
}

/// One yatra: days, stops, reorder, mark done, open in maps.
class YatraDetailScreen extends StatelessWidget {
  const YatraDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<YatraController>();
    final y = ctl.byId(id);
    if (y == null) return Scaffold(appBar: AppBar(), body: const EmptyShrine(motif: Motif.diya, message: 'This yatra was removed.'));
    final day = DayTheme.forDeity(y.deitySlug);
    final passport = context.watch<PassportController>();
    final packs = context.watch<OfflinePackController>();
    final located = y.allStops.where((st) => st.lat != null).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(y.name),
        actions: [
          IconButton(tooltip: 'Rename', icon: const Icon(Icons.edit_rounded), onPressed: () => _rename(context, ctl, y)),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete this yatra?'),
                    actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete'))],
                  ),
                );
                if (ok == true && context.mounted) {
                  await ctl.delete(y);
                  if (context.mounted) Navigator.of(context).pop();
                }
              } else if (v == 'maps') {
                final pts = y.allStops.where((s) => s.lat != null).map((s) => '${s.lat},${s.lng}').toList();
                if (pts.isNotEmpty) {
                  final uri = Uri.parse('https://www.google.com/maps/dir/${pts.join('/')}');
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'maps', child: ListTile(leading: Icon(Icons.map_rounded), title: Text('Open route in Maps'))),
              PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline_rounded), title: Text('Delete yatra'))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [day.accent, Color.lerp(day.accent, Colors.black, 0.25)!]),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Stack(
              children: [
                Positioned(right: -10, bottom: -20, child: Opacity(opacity: 0.18, child: MotifIcon(day.motif, size: 120, color: day.onAccent()))),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${y.stopCount} temples · ${y.days.length} days${y.distanceKm > 0 ? ' · ~${y.distanceKm.toStringAsFixed(0)} km straight-line' : ''}', style: theme.textTheme.bodyMedium?.copyWith(color: day.onAccent().withValues(alpha: 0.9))),
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: y.progress, minHeight: 8, color: day.onAccent(), backgroundColor: day.onAccent().withValues(alpha: 0.25))),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => ctl.setActive(y, !y.active),
                            icon: Icon(y.active ? Icons.pause_circle_rounded : Icons.play_circle_rounded),
                            label: Text(y.active ? 'Leave ${s('yatra_mode')}' : s('yatra_mode')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonalIcon(onPressed: () => ctl.addDay(y), icon: const Icon(Icons.add_rounded), label: const Text('Day')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.alt_route_rounded, size: 16),
                label: Text(s('optimise_route')),
                onPressed: located < 3 ? null : () async {
                  await ctl.optimise(y);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reordered to the shortest route: ~${y.distanceKm.toStringAsFixed(0)} km.')));
                },
              ),
              ActionChip(avatar: const Icon(Icons.calendar_view_week_rounded, size: 16), label: Text(s('auto_plan_days')), onPressed: y.stopCount < 2 ? null : () => _autoPlan(context, ctl, y)),
              ActionChip(
                avatar: packs.isDownloading(y.id)
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(packs.hasPack(y.id) ? Icons.offline_pin_rounded : Icons.download_for_offline_outlined, size: 16, color: packs.hasPack(y.id) ? Palette.tulsi : null),
                label: Text(packs.hasPack(y.id) ? '${s('pack_ready')} · ${packs.packedTemples(y.id)}/${y.stopCount}' : s('download_pack')),
                onPressed: packs.isDownloading(y.id) || y.stopCount == 0
                    ? null
                    : () async {
                        if (packs.hasPack(y.id)) {
                          await packs.remove(y.id);
                          return;
                        }
                        final failed = await packs.download(y);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failed == 0 ? 'Every temple on this yatra is saved for offline.' : '$failed of ${y.stopCount} could not be fetched. Bundled records will stand in for them.')));
                        }
                      },
              ),
            ],
          ),
          if (y.isComplete)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: Palette.brass, borderRadius: BorderRadius.circular(18)),
                child: const Row(children: [Icon(Icons.workspace_premium_rounded, color: Palette.deep), SizedBox(width: 10), Expanded(child: Text('Yatra complete. May the merit of every step stay with you.', style: TextStyle(color: Palette.deep, fontWeight: FontWeight.w600)))]),
              ),
            ),
          for (var di = 0; di < y.days.length; di++) ...[
            SectionHeader(
              title: y.days[di].title,
              motif: Motif.sun,
              subtitle: [
                if (y.startDate != null) _date(y.startDate!.add(Duration(days: di))),
                if (y.days[di].stops.length > 1) '~${y.days[di].distanceKm.toStringAsFixed(0)} km',
              ].join(' · ').ifEmptyNull,
              actionLabel: y.days.length > 1 ? 'Remove day' : null,
              onAction: () => ctl.removeDay(y, di),
            ),
            if (y.days[di].stops.isEmpty)
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Text('No temples on this day yet.', style: theme.textTheme.bodySmall))
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: y.days[di].stops.length,
                onReorder: (a, b) => ctl.reorder(y, di, a, b),
                itemBuilder: (context, i) {
                  final stop = y.days[di].stops[i];
                  final sd = DayTheme.forDeity(stop.deitySlug);
                  final visited = passport.hasVisited(stop.slug);
                  return Padding(
                    key: ValueKey(stop.slug),
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: Checkbox(value: stop.done, activeColor: sd.accent, onChanged: (_) => ctl.toggleDone(y, stop)),
                        title: Text(stop.name, style: TextStyle(fontFamily: 'NotoSerif', decoration: stop.done ? TextDecoration.lineThrough : null)),
                        subtitle: Row(
                          children: [
                            MotifIcon(sd.motif, size: 12, color: sd.accent),
                            const SizedBox(width: 4),
                            Flexible(child: Text([stop.city, if (visited) 'stamped'].whereType<String>().join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => ctl.removeStop(y, stop)),
                            ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle_rounded)),
                          ],
                        ),
                        onTap: () => enterTemple(context, TempleScreen(slug: stop.slug, preview: SampleData.bySlug(stop.slug)), accent: sd.accent),
                      ),
                    ),
                  );
                },
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await Navigator.of(context).push<TempleSummary>(MaterialPageRoute(builder: (_) => SearchScreen(picker: true, initial: TempleQuery(deity: y.deitySlug))));
                if (picked != null && context.mounted) {
                  await ctl.addStop(y, di, YatraStop(slug: picked.slug, name: picked.name, city: picked.location.city, deitySlug: picked.deity?.slug, lat: picked.location.latitude, lng: picked.location.longitude));
                }
              },
              icon: const Icon(Icons.add_location_alt_rounded),
              label: Text('Add temple to ${y.days[di].title}'),
            ),
          ],
          const SizedBox(height: 24),
          const KolamDivider(),
        ],
      ),
    );
  }

  static String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

  static Future<void> _autoPlan(BuildContext context, YatraController ctl, Yatra y) async {
    var perDay = 3;
    var km = 250.0;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.of(context)('auto_plan_days'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Orders every stop into the shortest route, then starts a new day when a day would pass the limits below. Distances are straight-line estimates.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Text('Temples per day: $perDay'),
              Slider(value: perDay.toDouble(), min: 1, max: 6, divisions: 5, onChanged: (v) => setSheet(() => perDay = v.round())),
              Text('Distance per day: ${km.round()} km'),
              Slider(value: km, min: 50, max: 600, divisions: 11, onChanged: (v) => setSheet(() => km = v)),
              const SizedBox(height: 8),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Re-plan')),
            ],
          ),
        ),
      ),
    );
    if (ok == true) await ctl.autoPlan(y, maxKmPerDay: km, maxStopsPerDay: perDay);
  }

  static Future<void> _rename(BuildContext context, YatraController ctl, Yatra y) async {
    final c = TextEditingController(text: y.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename yatra'),
        content: TextField(controller: c, autofocus: true),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save'))],
      ),
    );
    if (ok == true && c.text.trim().isNotEmpty) {
      y.name = c.text.trim();
      await ctl.save();
    }
  }
}

extension on String {
  String? get ifEmptyNull => isEmpty ? null : this;
}
