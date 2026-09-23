import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/temple_repository.dart';
import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/data/sample_data.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/day_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/yatra_controller.dart';
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
  const HomeScreen({super.key, required this.onExplore, this.onTab});

  final VoidCallback onExplore;

  /// Switches the shell to another tab: 2 is Passport, 3 is Yatra.
  final ValueChanged<int>? onTab;

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
      repo.temples(const TempleQuery(perPage: 10, featuredOnly: true)),
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
          SliverToBoxAdapter(child: _Greeting(name: context.watch<AuthController>().devotee?.name)),
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
                  _QuickAction(icon: Icons.qr_code_scanner_rounded, label: s('scan_qr'), onTap: () => scanTempleAndCheckIn(context)),
                  const SizedBox(width: 8),
                  _QuickAction(icon: Icons.route_rounded, label: s('new_yatra'), onTap: () => widget.onTab?.call(3)),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(child: _ReminderBanner(reminders: context.watch<RemindersController>().upcoming)),
          SliverToBoxAdapter(child: _JourneyCard(day: day, onPassport: () => widget.onTab?.call(2))),
          SliverToBoxAdapter(child: SectionHeader(title: s('todays_practice'), motif: Motif.diya)),
          SliverToBoxAdapter(child: _PracticeCard(day: day)),
          SliverToBoxAdapter(child: SectionHeader(title: s('browse_deities'), motif: Motif.om)),
          const SliverToBoxAdapter(child: _DeityRow()),
          SliverToBoxAdapter(child: SectionHeader(title: s('week'), motif: Motif.bell)),
          SliverToBoxAdapter(child: _WeekStrip(current: day)),
          if (dayCtl.todayMedia.isNotEmpty) ...[
            SliverToBoxAdapter(child: SectionHeader(title: s('today_media'), motif: day.motif, actionLabel: s('see_all'), onAction: () => enterTemple(context, DayScreen(weekday: day.weekday), accent: day.accent))),
            SliverToBoxAdapter(
              child: SizedBox(
                height: scaledHeight(context, 200),
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
          SliverToBoxAdapter(child: SectionHeader(title: s('categories'), motif: Motif.shankhaChakra, actionLabel: s('see_all'), onAction: widget.onExplore)),
          const SliverToBoxAdapter(child: _CircuitRow()),
          SliverToBoxAdapter(child: _YatraPrompt(day: day, onOpen: () => widget.onTab?.call(3))),
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
          SliverToBoxAdapter(child: SectionHeader(title: s('verse_of_day'), motif: Motif.lotus)),
          SliverToBoxAdapter(child: _VerseCard(day: day)),
          SliverToBoxAdapter(child: SectionHeader(title: s('temple_tips'), motif: Motif.namam)),
          const SliverToBoxAdapter(child: _TipsCard()),
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lead?.mantra ?? day.mantra, style: theme.textTheme.titleLarge?.copyWith(color: on, fontFamily: 'NotoSerif')),
                          Text(lead?.mantraTransliteration ?? day.transliteration, style: theme.textTheme.bodySmall?.copyWith(color: on.withValues(alpha: 0.8), fontStyle: FontStyle.italic)),
                        ],
                      ),
                    ),
                    MantraControls(
                      playKey: 'day-${day.weekday}',
                      text: lead?.mantra ?? day.mantra,
                      audio: lead?.mantraAudio?.audio,
                      audioUrl: lead?.mantraAudio?.audio == null ? lead?.media.where((m) => m.type == 'chant' && m.playback.kind == 'audio').firstOrNull?.url : null,
                      accent: day.accent,
                      onColor: on,
                      day: day,
                      compact: true,
                    ),
                  ],
                ),
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
      height: scaledHeight(context, 116),
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
                  Flexible(child: MotifIcon(d.motif, size: 34, color: isToday ? d.onAccent() : d.accent, secondary: d.secondary)),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(d.deityName, maxLines: 1, style: theme.textTheme.labelMedium?.copyWith(color: isToday ? d.onAccent() : theme.colorScheme.onSurface, fontFamily: 'NotoSerif'))),
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
        height: scaledHeight(context, 262),
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
                Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 0.3, fontWeight: FontWeight.w600)),
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

/// A word of welcome under the day's header, with the date.
class _Greeting extends StatelessWidget {
  const _Greeting({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final now = DateTime.now();
    final part = now.hour < 12 ? s('good_morning') : now.hour < 17 ? s('good_afternoon') : s('good_evening');
    final first = name?.trim().split(' ').first;
    String date;
    try {
      date = DateFormat('EEEE, d MMMM', Localizations.localeOf(context).languageCode).format(now);
    } catch (_) {
      date = DateFormat('EEEE, d MMMM').format(now);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.primary.withValues(alpha: 0.12)),
            child: MotifIcon(Motif.diya, size: 26, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(first == null || first.isEmpty ? '${s('namaste')}!' : '${s('namaste')}, $first', style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'NotoSerif', fontWeight: FontWeight.w600)),
                Text('$part · $date', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The devotee's pilgrimage so far, and the next milestone to aim for.
class _JourneyCard extends StatelessWidget {
  const _JourneyCard({required this.day, required this.onPassport});

  final DayTheme day;
  final VoidCallback onPassport;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final passport = context.watch<PassportController>();
    final yatras = context.watch<YatraController>().yatras;
    final earned = passport.earned.map((a) => a.slug).toSet();
    final next = Achievement.all.where((a) => !earned.contains(a.slug)).firstOrNull;
    final on = day.onAccent();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Material(
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPassport,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color.lerp(day.accent, Colors.black, 0.25)!, day.accent], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MotifIcon(Motif.kalasha, size: 22, color: on, secondary: day.secondary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s('your_journey'), style: theme.textTheme.titleMedium?.copyWith(color: on, fontFamily: 'NotoSerif'))),
                    Icon(Icons.arrow_forward_rounded, color: on.withValues(alpha: 0.9), size: 20),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _JourneyStat(value: '${passport.stampCount}', label: s('stamps'), color: on),
                    _JourneyStat(value: '${passport.visits.length}', label: s('visits'), color: on),
                    _JourneyStat(value: '${passport.statesVisited.length}', label: s('states_short'), color: on),
                    _JourneyStat(value: '${yatras.length}', label: s('yatras'), color: on),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  passport.stampCount == 0 ? s('journey_start') : next == null ? s('journey_all_done') : '${s('next_milestone')}: ${next.title} · ${next.description}',
                  style: theme.textTheme.bodySmall?.copyWith(color: on.withValues(alpha: 0.92), height: 1.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _JourneyStat extends StatelessWidget {
  const _JourneyStat({required this.value, required this.label, required this.color});

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(label, style: theme.textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.85), letterSpacing: 0.5))),
        ],
      ),
    );
  }
}

/// What the day asks of a devotee: the offering and the vrat.
class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.day});

  final DayTheme day;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    Widget row(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Icon(icon, color: day.accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.labelLarge?.copyWith(color: day.accent, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(color: day.tint(theme.brightness), borderRadius: BorderRadius.circular(20), border: Border.all(color: day.accent.withValues(alpha: 0.35))),
        child: Column(
          children: [
            row(Icons.volunteer_activism_rounded, '${s('offering')} · ${day.deityName}', day.offering),
            Divider(color: day.accent.withValues(alpha: 0.2), height: 12),
            row(Icons.nightlight_round, s('fasting'), day.fastingNote),
          ],
        ),
      ),
    );
  }
}

/// Every deity as a round emblem; tapping one lists their temples.
class _DeityRow extends StatelessWidget {
  const _DeityRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: scaledHeight(context, 104),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: SampleData.deities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final d = SampleData.deities[i];
          final dt = DayTheme.forDeity(d.slug);
          return InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(initial: TempleQuery(deity: d.slug)))),
            child: Column(
              children: [
                DeityIcon(slug: d.slug, imageUrl: d.imageUrl, size: 62, accent: dt.accent, secondary: dt.secondary, onAccent: dt.onAccent()),
                const SizedBox(height: 6),
                SizedBox(width: 72, child: FittedBox(fit: BoxFit.scaleDown, child: Text(d.name, maxLines: 1, style: theme.textTheme.labelMedium?.copyWith(fontFamily: 'NotoSerif')))),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The great pilgrimage circuits as cards: Jyotirlinga, Char Dham and more.
class _CircuitRow extends StatelessWidget {
  const _CircuitRow();

  static Motif _motif(String slug) => switch (slug) {
        'jyotirlinga' => Motif.trishul,
        'char-dham' || 'chota-char-dham' => Motif.kalasha,
        'shakti-peetha' => Motif.yantra,
        'divya-desam' => Motif.namam,
        'sapta-puri' => Motif.diya,
        _ => Motif.lotus,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final circuits = SampleData.categories.where((c) => c.kind == 'circuit').toList();
    return SizedBox(
      height: scaledHeight(context, 132),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: circuits.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final c = circuits[i];
          return SizedBox(
            width: 210,
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(initial: TempleQuery(category: c.slug)))),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          MotifIcon(_motif(c.slug), size: 26, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'NotoSerif', fontWeight: FontWeight.w600))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(child: Text(c.description ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(height: 1.35))),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Invites a first yatra, or picks up the one under way.
class _YatraPrompt extends StatelessWidget {
  const _YatraPrompt({required this.day, required this.onOpen});

  final DayTheme day;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<YatraController>();
    final current = ctl.active ?? ctl.yatras.where((y) => !y.isComplete && y.stopCount > 0).firstOrNull;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: day.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(Icons.route_rounded, color: day.accent, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(current == null ? s('plan_first_yatra') : '${s('continue_yatra')}: ${current.name}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    current == null ? s('yatra_pitch') : '${current.doneCount}/${current.stopCount} · ${current.days.length} ${s('days_word')}',
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
                  ),
                  if (current != null) ...[
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: current.progress, minHeight: 6, color: day.accent, backgroundColor: day.accent.withValues(alpha: 0.15))),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(onPressed: onOpen, style: FilledButton.styleFrom(backgroundColor: day.accent, foregroundColor: day.onAccent()), child: Text(current == null ? s('start') : s('open'))),
          ],
        ),
      ),
    );
  }
}

/// A verse from the Bhagavad Gita, a different one each day.
class _VerseCard extends StatelessWidget {
  const _VerseCard({required this.day});

  final DayTheme day;

  static const _verses = <(String, String, String)>[
    ('कर्मण्येवाधिकारस्ते मा फलेषु कदाचन', 'Your right is to the work alone, never to its fruits.', 'Bhagavad Gita 2.47'),
    ('पत्रं पुष्पं फलं तोयं यो मे भक्त्या प्रयच्छति', 'A leaf, a flower, a fruit or a little water, offered with love, I accept.', 'Bhagavad Gita 9.26'),
    ('उद्धरेदात्मनात्मानं नात्मानमवसादयेत्', 'Lift yourself up by your own effort; never let yourself sink.', 'Bhagavad Gita 6.5'),
    ('यदा यदा हि धर्मस्य ग्लानिर्भवति भारत', 'Whenever righteousness declines, I come forth.', 'Bhagavad Gita 4.7'),
    ('अद्वेष्टा सर्वभूतानां मैत्रः करुण एव च', 'Bearing ill will to no one, friendly and compassionate to all.', 'Bhagavad Gita 12.13'),
    ('युक्ताहारविहारस्य युक्तचेष्टस्य कर्मसु', 'Balance in food, rest, work and sleep ends sorrow.', 'Bhagavad Gita 6.17'),
    ('सर्वधर्मान्परित्यज्य मामेकं शरणं व्रज', 'Set everything else aside and take refuge in Me; do not grieve.', 'Bhagavad Gita 18.66'),
    ('मात्रास्पर्शास्तु कौन्तेय शीतोष्णसुखदुःखदाः', 'Heat and cold, joy and pain come and go; bear them with patience.', 'Bhagavad Gita 2.14'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final v = _verses[now.difference(DateTime(now.year)).inDays % _verses.length];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: day.tint(theme.brightness), borderRadius: BorderRadius.circular(20), border: Border.all(color: day.accent.withValues(alpha: 0.3))),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: day.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
            Text(v.$1, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSansDevanagari', color: day.accent, height: 1.5)),
            const SizedBox(height: 8),
            Text('“${v.$2}”', style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'NotoSerif', fontStyle: FontStyle.italic, height: 1.45)),
            const SizedBox(height: 8),
            Text('— ${v.$3}', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Plain advice for a first visit, the things people wish they had known.
class _TipsCard extends StatelessWidget {
  const _TipsCard();

  static const _tips = <(IconData, String, String)>[
    (Icons.checkroom_rounded, 'Dress traditionally', 'Many temples, especially in the south, ask for a dhoti, saree or salwar. Shorts are often refused.'),
    (Icons.do_not_step_rounded, 'Footwear stays outside', 'Most temples have a free or low-cost counter by the gate.'),
    (Icons.schedule_rounded, 'Check the timings', 'The sanctum usually closes for a few hours in the afternoon. Timings are on every temple page.'),
    (Icons.no_photography_rounded, 'Ask before photos', 'Photography is rarely allowed inside the sanctum.'),
    (Icons.currency_rupee_rounded, 'Carry some cash', 'Prasadam and seva counters do not always take cards or UPI.'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              for (final t in _tips)
                ListTile(
                  dense: true,
                  leading: Icon(t.$1, color: theme.colorScheme.primary),
                  title: Text(t.$2, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  subtitle: Text(t.$3, style: theme.textTheme.bodySmall),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
