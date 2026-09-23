import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/api/temple_repository.dart';
import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/day_controller.dart';
import '../../core/state/reminders_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/widgets/media_widgets.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../calendar/calendar_screen.dart';
import '../days/day_screen.dart';
import '../guide/guide_screen.dart';
import '../qr/qr_screens.dart';
import '../explore/search_screen.dart';
import '../temple/temple_screen.dart';

/// Home: today's deity, search, nearby, popular temples and festivals.
///
/// The header is the day's sanctum: its colour, motif and mantra. Everything
/// below is content, so the eye lands on the deity first.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onExplore});

  final VoidCallback onExplore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Result<Paged<TempleSummary>>? _popular;
  Result<List<TempleEvent>>? _events;
  Result<Paged<TempleSummary>>? _nearby;
  String? _nearbyError;
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app after midnight should show the new day.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<DayController>().refreshToday();
  }

  Future<void> _load() async {
    final repo = context.read<TempleRepository>();
    final results = await Future.wait([
      repo.temples(const TempleQuery(perPage: 10, sort: 'recent')),
      repo.events(),
    ]);
    if (!mounted) return;
    setState(() {
      _popular = results[0] as Result<Paged<TempleSummary>>;
      _events = results[1] as Result<List<TempleEvent>>;
    });
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _nearbyError = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw 'Location permission is needed to find temples near you.';
      }
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      if (!mounted) return;
      final r = await context.read<TempleRepository>().temples(TempleQuery(lat: pos.latitude, lng: pos.longitude, radiusKm: 300, perPage: 10));
      if (!mounted) return;
      setState(() => _nearby = r);
    } catch (e) {
      if (mounted) setState(() => _nearbyError = e.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _open(TempleSummary t) => enterTemple(context, TempleScreen(slug: t.slug, preview: t), accent: DayTheme.forDeity(t.deity?.slug).accent);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dayCtl = context.watch<DayController>();
    // Home is always today, whatever page is previewing another deity.
    final day = dayCtl.todayTheme;
    final theme = Theme.of(context);
    final todayData = dayCtl.today;
    final lead = todayData.firstOrNull;

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([_load(), dayCtl.refresh()]);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _DayHeader(day: day, lead: lead, onTap: () => enterTemple(context, DayScreen(weekday: day.weekday), accent: day.accent))),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: _SearchBar(hint: s('search_hint'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen(autofocus: true)))),
            ),
          ),
          if (dayCtl.loaded && dayCtl.offline) const SliverToBoxAdapter(child: OfflineNote()),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  _QuickAction(icon: Icons.auto_awesome_rounded, label: s('ask_guide'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GuideScreen()))),
                  const SizedBox(width: 8),
                  _QuickAction(icon: Icons.calendar_month_rounded, label: s('calendar'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen()))),
                  const SizedBox(width: 8),
                  _QuickAction(icon: Icons.qr_code_scanner_rounded, label: s('scan_qr'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanScreen()))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _ReminderBanner(reminders: context.watch<RemindersController>().upcoming)),
          SliverToBoxAdapter(child: SectionHeader(title: s('week'), motif: Motif.bell)),
          SliverToBoxAdapter(child: _WeekStrip(current: day)),
          if (dayCtl.todayMedia.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(title: s('today_media'), motif: day.motif, actionLabel: s('see_all'), onAction: () => enterTemple(context, DayScreen(weekday: day.weekday), accent: day.accent))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 200,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: dayCtl.todayMedia.take(10).length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) => MediaCard(media: dayCtl.todayMedia[i], day: day, width: 140),
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(child: SectionHeader(title: s('nearby'), motif: Motif.diya, actionLabel: _nearby == null ? null : s('see_all'), onAction: widget.onExplore)),
          SliverToBoxAdapter(child: _NearbySection(result: _nearby, error: _nearbyError, locating: _locating, onLocate: _locate, onOpen: _open)),
          if (lead != null && lead.temples.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(title: '${s('temples_of')} ${lead.deity?.name ?? day.deityName}', motif: day.motif, actionLabel: s('see_all'), onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(initial: TempleQuery(deity: lead.deity?.slug ?? day.deitySlug)))))),
            SliverToBoxAdapter(child: _Carousel(temples: lead.temples, onOpen: _open)),
          ],
          SliverToBoxAdapter(child: SectionHeader(title: s('popular'), motif: Motif.kalasha, actionLabel: s('see_all'), onAction: widget.onExplore)),
          SliverToBoxAdapter(
            child: _popular == null
                ? const SizedBox(height: 180, child: DiyaLoader())
                : _Carousel(temples: _popular!.data.items, onOpen: _open),
          ),
          SliverToBoxAdapter(child: SectionHeader(title: s('festivals'), motif: Motif.bell, actionLabel: s('calendar'), onAction: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())))),
          if (_events == null)
            const SliverToBoxAdapter(child: SizedBox(height: 120, child: DiyaLoader()))
          else if (_events!.data.isEmpty)
            const SliverToBoxAdapter(child: EmptyShrine(motif: Motif.bell, message: 'No upcoming events published yet.'))
          else
            SliverList.builder(
              itemCount: _events!.data.length,
              itemBuilder: (context, i) => _EventTile(event: _events!.data[i]),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 32),
              child: Column(
                children: [
                  const KolamDivider(),
                  const SizedBox(height: 8),
                  Text('${Brand.name} · ${Brand.tagline}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.55))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.lead, required this.onTap});

  final DayTheme day;
  final DevotionalDay? lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    final on = day.onAccent();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.fromLTRB(20, top + 16, 20, 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [day.accent, Color.lerp(day.accent, theme.scaffoldBackgroundColor, 0.35)!],
          ),
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: Opacity(opacity: 0.12, child: CustomPaint(painter: LatticePainter(color: on, cell: 30)))),
            Positioned(left: -20, right: -20, bottom: -6, child: GopuramBand(color: on, height: 90, opacity: 0.14, tiers: 6)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${day.sanskritDay} · ${day.dayName}'.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: on.withValues(alpha: 0.85), letterSpacing: 2.5)),
                          const SizedBox(height: 6),
                          Text(lead?.deity?.name ?? day.deityName, style: theme.textTheme.displaySmall?.copyWith(color: on)),
                          Text(day.epithet, style: theme.textTheme.bodyMedium?.copyWith(color: on.withValues(alpha: 0.85), fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    DeityPortrait(day: day, imageUrl: lead?.deity?.imageUrl, size: 80, color: on),
                  ],
                ),
                const SizedBox(height: 18),
                Text(lead?.mantra ?? day.mantra, style: theme.textTheme.titleLarge?.copyWith(color: on, fontFamily: 'NotoSerif')),
                Text(lead?.mantraTransliteration ?? day.transliteration, style: theme.textTheme.bodySmall?.copyWith(color: on.withValues(alpha: 0.8), fontStyle: FontStyle.italic)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: Text(lead?.subtitle ?? day.greeting, style: theme.textTheme.bodyMedium?.copyWith(color: on.withValues(alpha: 0.92)))),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, color: on.withValues(alpha: 0.9)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.hint, required this.onTap});

  final String hint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(999),
      elevation: 3,
      shadowColor: theme.colorScheme.primary.withValues(alpha: 0.3),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(child: Text(hint, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)))),
              Icon(Icons.mic_none_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.current});

  final DayTheme current;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayIndex = DateTime.now().weekday % 7;
    // Start the strip on today so the week reads forward.
    final order = [for (var i = 0; i < 7; i++) DayTheme.all[(todayIndex + i) % 7]];
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: order.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final d = order[i];
          final isToday = d.weekday == todayIndex;
          return GestureDetector(
            onTap: () => enterTemple(context, DayScreen(weekday: d.weekday), accent: d.accent),
            child: Container(
              width: 84,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: isToday ? d.accent : d.tint(theme.brightness),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: d.accent.withValues(alpha: isToday ? 1 : 0.45), width: isToday ? 1.5 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(d.dayName.substring(0, 3).toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: isToday ? d.onAccent() : d.accent)),
                  MotifIcon(d.motif, size: 34, color: isToday ? d.onAccent() : d.accent, secondary: d.secondary),
                  Text(d.deityName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium?.copyWith(color: isToday ? d.onAccent() : theme.colorScheme.onSurface, fontFamily: 'NotoSerif')),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NearbySection extends StatelessWidget {
  const _NearbySection({required this.result, required this.error, required this.locating, required this.onLocate, required this.onOpen});

  final Result<Paged<TempleSummary>>? result;
  final String? error;
  final bool locating;
  final VoidCallback onLocate;
  final void Function(TempleSummary) onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = S.of(context);
    if (locating) return const SizedBox(height: 120, child: DiyaLoader(label: 'Finding temples around you'));
    if (result != null && result!.data.items.isNotEmpty) return _Carousel(temples: result!.data.items, onOpen: onOpen);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.near_me_rounded, color: theme.colorScheme.primary, size: 30),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                error ?? (result == null ? s('nearby_prompt') : 'No temples within 300 km in our records yet.'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: onLocate, child: Text(s('locate'))),
          ],
        ),
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({required this.temples, required this.onOpen});

  final List<TempleSummary> temples;
  final void Function(TempleSummary) onOpen;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 262,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: temples.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, i) => TempleCard(temple: temples[i], width: 230, onTap: () => onOpen(temples[i])),
        ),
      );
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final TempleEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final month = event.startsOn != null && event.startsOn!.length >= 7 ? _month(int.tryParse(event.startsOn!.substring(5, 7))) : '';
    final dayNum = event.startsOn != null && event.startsOn!.length >= 10 ? event.startsOn!.substring(8, 10) : '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: event.templeSlug == null ? null : () => enterTemple(context, TempleScreen(slug: event.templeSlug!)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: event.isHappeningToday ? scheme.primary : scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(dayNum, style: theme.textTheme.titleLarge?.copyWith(color: event.isHappeningToday ? scheme.onPrimary : scheme.primary)),
                      Text(month, style: theme.textTheme.labelSmall?.copyWith(color: event.isHappeningToday ? scheme.onPrimary : scheme.primary, letterSpacing: 1)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.title, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif')),
                      if (event.templeName != null)
                        Text('${event.templeName}${event.templeCity != null ? ' · ${event.templeCity}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      if (event.dateLabel != null)
                        Text(event.dateLabel!, style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary)),
                    ],
                  ),
                ),
                if (event.templeSlug != null) Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _month(int? m) => m == null || m < 1 || m > 12 ? '' : const ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][m - 1];
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
            child: Column(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(height: 4),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderBanner extends StatelessWidget {
  const _ReminderBanner({required this.reminders});

  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context) {
    final soon = reminders.where((r) => r.daysAway <= 14).toList();
    if (soon.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final r = soon.first;
    final when = r.daysAway <= 0 ? 'today' : r.daysAway == 1 ? 'tomorrow' : 'in ${r.daysAway} days';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Material(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('${r.title}${r.templeName != null ? ' at ${r.templeName}' : ''} is $when${soon.length > 1 ? ' · ${soon.length - 1} more' : ''}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
