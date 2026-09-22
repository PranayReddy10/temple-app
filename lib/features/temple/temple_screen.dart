import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/temple_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/day_controller.dart';
import '../../core/state/favourites_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/yatra_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_widgets.dart';
import '../passport/stamp_widget.dart';
import '../photo_stamp/photo_stamp_screen.dart';

/// The full temple profile. Entered through the temple door, and while open
/// the app wears the temple deity's colour.
class TempleScreen extends StatefulWidget {
  const TempleScreen({super.key, required this.slug, this.preview});

  final String slug;
  final TempleSummary? preview;

  @override
  State<TempleScreen> createState() => _TempleScreenState();
}

class _TempleScreenState extends State<TempleScreen> {
  Result<TempleDetail>? _detail;
  String? _error;
  int _photo = 0;

  @override
  void initState() {
    super.initState();
    _load();
    final slug = widget.preview?.deity?.slug;
    if (slug != null) WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DayController>().preview(DayTheme.forDeity(slug)));
  }

  @override
  void dispose() {
    final ctl = context.read<DayController>();
    WidgetsBinding.instance.addPostFrameCallback((_) => ctl.resetToToday());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<TempleRepository>().temple(widget.slug);
      if (!mounted) return;
      setState(() => _detail = r);
      final slug = r.data.summary.deity?.slug;
      if (slug != null && widget.preview?.deity?.slug != slug) context.read<DayController>().preview(DayTheme.forDeity(slug));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.isNotFound ? 'This temple is not published.' : e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load this temple.');
    }
  }

  TempleSummary get _summary => _detail?.data.summary ?? widget.preview!;

  @override
  Widget build(BuildContext context) {
    if (_detail == null && widget.preview == null) {
      return Scaffold(appBar: AppBar(), body: _error != null ? EmptyShrine(motif: Motif.diya, message: _error!) : const DiyaLoader(label: 'Opening the sanctum'));
    }
    final s = S.of(context);
    final theme = Theme.of(context);
    final t = _summary;
    final d = _detail?.data;
    final day = DayTheme.forDeity(t.deity?.slug);
    final passport = context.watch<PassportController>();
    final favs = context.watch<FavouritesController>();
    final visited = passport.hasVisited(t.slug);
    final saved = favs.contains(t.slug);
    final photos = d?.photos.isNotEmpty == true ? d!.photos : [if (t.primaryPhoto != null) t.primaryPhoto!];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: day.accent,
            foregroundColor: day.onAccent(),
            actions: [
              IconButton(
                tooltip: saved ? s('saved') : s('save'),
                onPressed: () => favs.toggle(t.slug),
                icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (photos.isEmpty)
                    TempleImage(deitySlug: t.deity?.slug, motifSize: 110)
                  else
                    PageView.builder(
                      itemCount: photos.length,
                      onPageChanged: (i) => setState(() => _photo = i),
                      itemBuilder: (_, i) => TempleImage(url: photos[i].best, deitySlug: t.deity?.slug, motifSize: 110),
                    ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent, Colors.black.withValues(alpha: 0.55)]),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(left: 0, right: 0, bottom: 0, child: SizedBox(height: 56, child: CustomPaint(painter: ToranaPainter(color: Palette.gold, strokeWidth: 3, scallops: 15)))),
                  if (photos.length > 1)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: Row(
                        children: [
                          for (var i = 0; i < photos.length; i++)
                            Container(
                              width: i == _photo ? 16 : 6,
                              height: 6,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == _photo ? 1 : 0.5), borderRadius: BorderRadius.circular(3)),
                            ),
                        ],
                      ),
                    ),
                  if (photos.isNotEmpty && photos[_photo].credit != null)
                    Positioned(left: 16, bottom: 14, child: Text('© ${photos[_photo].credit}', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70))),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(t.name, style: theme.textTheme.headlineSmall)),
                      const SizedBox(width: 12),
                      MotifIcon(day.motif, size: 40, color: day.accent, secondary: day.secondary),
                    ],
                  ),
                  if (d != null && d.alternateNames.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(d.alternateNames.join(' · '), style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TrustBadge(trust: t.trust),
                      if (t.deity != null) Chip(avatar: MotifIcon(day.motif, size: 16, color: day.accent), label: Text(t.deity!.name), visualDensity: VisualDensity.compact),
                      if (d != null) for (final c in d.categories) Chip(label: Text(c.name), visualDensity: VisualDensity.compact),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 16, color: day.accent),
                      const SizedBox(width: 6),
                      Expanded(child: Text([d?.summary.location.address, t.location.city, t.location.district, t.location.state].where((e) => e != null && e.isNotEmpty).toSet().join(', '), style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                  if (d?.isClosedToday == true) ...[
                    const SizedBox(height: 12),
                    _Banner(icon: Icons.door_front_door_rounded, text: s('closed_today'), color: Palette.kumkum),
                  ],
                  if (_detail?.isOffline == true) ...[const SizedBox(height: 8), const Padding(padding: EdgeInsets.zero, child: OfflineNote())],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _checkIn(t),
                          icon: Icon(visited ? Icons.verified_rounded : Icons.approval_rounded),
                          label: Text(visited ? s('visited') : s('check_in')),
                          style: FilledButton.styleFrom(backgroundColor: day.accent, foregroundColor: day.onAccent()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(tooltip: s('add_to_yatra'), onPressed: () => _addToYatra(t), icon: const Icon(Icons.route_rounded)),
                      const SizedBox(width: 6),
                      if (t.location.hasCoordinates)
                        IconButton.filledTonal(
                          tooltip: 'Directions',
                          onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${t.location.latitude},${t.location.longitude}'), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.directions_rounded),
                        ),
                    ],
                  ),
                  if (visited) ...[
                    const SizedBox(height: 16),
                    Center(child: StampWidget(visit: passport.firstVisit(t.slug)!, size: 120)),
                  ],
                ],
              ),
            ),
          ),
          if (d == null && _error == null)
            const SliverToBoxAdapter(child: SizedBox(height: 120, child: DiyaLoader()))
          else if (d == null)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(20), child: _Banner(icon: Icons.cloud_off_rounded, text: _error!, color: Palette.saffron)))
          else ...[
            if (t.shortDescription != null || d.history != null || d.significance != null) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('about'), motif: Motif.om)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t.shortDescription != null) Text(t.shortDescription!, style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'NotoSerif', height: 1.5)),
                      if (d.history != null && d.history != t.shortDescription) ...[const SizedBox(height: 10), Text(d.history!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))],
                      if (d.significance != null) ...[const SizedBox(height: 10), Text(d.significance!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))],
                      if (d.architectureStyle != null || d.builtPeriod != null) ...[
                        const SizedBox(height: 10),
                        Wrap(spacing: 8, children: [
                          if (d.architectureStyle != null) Chip(avatar: const Icon(Icons.account_balance_rounded, size: 16), label: Text(d.architectureStyle!)),
                          if (d.builtPeriod != null) Chip(avatar: const Icon(Icons.history_rounded, size: 16), label: Text(d.builtPeriod!)),
                        ]),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (d.timings.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('timings'), motif: Motif.bell)),
              SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 20), sliver: SliverToBoxAdapter(child: _TimingsTable(timings: d.timings, accent: day.accent))),
            ],
            if (d.closures.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader(title: 'Upcoming closures', motif: Motif.diya)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: d.closures.length,
                  itemBuilder: (context, i) {
                    final c = d.closures[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.event_busy_rounded, color: c.isActiveToday ? Palette.kumkum : day.accent),
                      title: Text(c.reason ?? 'Closed'),
                      subtitle: Text([c.startsOn, if (c.endsOn != c.startsOn) c.endsOn].whereType<String>().join(' → ') + (c.isFullDay ? '' : ' · partial day')),
                    );
                  },
                ),
              ),
            ],
            if (d.pujas.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('pujas'), motif: Motif.kalasha)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.separated(itemCount: d.pujas.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, i) => _PujaCard(puja: d.pujas[i], accent: day.accent)),
              ),
            ],
            if (d.events.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('festivals'), motif: Motif.bell)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: d.events.length,
                  itemBuilder: (context, i) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Icon(Icons.celebration_rounded, color: day.accent),
                      title: Text(d.events[i].title, style: const TextStyle(fontFamily: 'NotoSerif')),
                      subtitle: Text(d.events[i].dateLabel ?? d.events[i].startsOn ?? ''),
                    ),
                  ),
                ),
              ),
            ],
            if (d.facilities.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('facilities'), motif: Motif.lotus)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final f in d.facilities)
                        Chip(
                          avatar: Icon(f.isVerified ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: f.isVerified ? Palette.tulsi : theme.colorScheme.outline),
                          label: Text(f.name),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (d.visitorRules.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('visitor_rules'), motif: Motif.namam)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      for (final e in d.visitorRules.entries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(_ruleIcon(e.key), color: day.accent),
                          title: Text(_ruleLabel(e.key), style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.5)),
                          subtitle: Text(e.value),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            if (d.website != null || d.phone != null || d.email != null) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('contact'), motif: Motif.shankhaChakra)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (d.website != null) ActionChip(avatar: const Icon(Icons.language_rounded, size: 16), label: const Text('Website'), onPressed: () => launchUrl(Uri.parse(d.website!), mode: LaunchMode.externalApplication)),
                      if (d.phone != null) ActionChip(avatar: const Icon(Icons.call_rounded, size: 16), label: Text(d.phone!), onPressed: () => launchUrl(Uri.parse('tel:${d.phone}'))),
                      if (d.email != null) ActionChip(avatar: const Icon(Icons.mail_rounded, size: 16), label: Text(d.email!), onPressed: () => launchUrl(Uri.parse('mailto:${d.email}'))),
                    ],
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: Column(
                  children: [
                    const KolamDivider(),
                    const SizedBox(height: 10),
                    Text(
                      [
                        '${t.trust.label ?? t.trust.level.label} record',
                        if (t.trust.sourceName != null) 'Source: ${t.trust.sourceName}',
                        if (t.trust.lastVerifiedAt != null) 'Last verified ${t.trust.lastVerifiedAt}' else 'Not yet verified against a primary source',
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static IconData _ruleIcon(String key) => switch (key) {
        'dress_code' => Icons.checkroom_rounded,
        'photography' => Icons.no_photography_rounded,
        'mobile' => Icons.phonelink_erase_rounded,
        'footwear' => Icons.do_not_step_rounded,
        'entry' => Icons.login_rounded,
        'queue' => Icons.people_alt_rounded,
        _ => Icons.info_outline_rounded,
      };

  static String _ruleLabel(String key) => switch (key) {
        'dress_code' => 'Dress code',
        'photography' => 'Photography',
        'mobile' => 'Mobile phones',
        'footwear' => 'Footwear',
        'entry' => 'Entry',
        'queue' => 'Queue',
        _ => key,
      };

  Future<void> _checkIn(TempleSummary t) async {
    final passport = context.read<PassportController>();
    final note = TextEditingController();
    String? photoPath;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Check in at ${t.name}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('A manual check-in records your darshan and inks a stamp in your passport. GPS and QR verification arrive in a later phase.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              TextField(controller: note, maxLines: 2, decoration: const InputDecoration(hintText: 'A line to remember this visit by (optional)')),
              const SizedBox(height: 12),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
                      if (x != null) setSheet(() => photoPath = x.path);
                    },
                    icon: Icon(photoPath == null ? Icons.add_a_photo_rounded : Icons.check_rounded),
                    label: Text(photoPath == null ? 'Add a photo' : 'Photo added'),
                  ),
                  const Spacer(),
                  FilledButton.icon(onPressed: () => Navigator.of(context).pop(true), icon: const Icon(Icons.approval_rounded), label: const Text('Stamp it')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final first = !passport.hasVisited(t.slug);
    await passport.checkIn(t, note: note.text.trim().isEmpty ? null : note.text.trim(), photoPath: photoPath);
    if (!mounted) return;
    final visit = passport.visits.first;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(first ? 'Stamp earned' : 'Darshan recorded', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              StampLanding(visit: visit),
              const SizedBox(height: 20),
              Text(first ? 'Your passport now carries ${t.name}.' : 'Another visit to a temple already in your passport.', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.of(this.context).push(MaterialPageRoute(builder: (_) => PhotoStampScreen(visit: visit)));
                      },
                      child: const Text('Photo stamp'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addToYatra(TempleSummary t) async {
    final yatras = context.read<YatraController>();
    final stop = YatraStop(slug: t.slug, name: t.name, city: t.location.city, deitySlug: t.deity?.slug, lat: t.location.latitude, lng: t.location.longitude);
    if (yatras.yatras.isEmpty) {
      final y = await yatras.create('My first yatra', deitySlug: t.deity?.slug);
      await yatras.addStop(y, 0, stop);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${y.name}')));
      return;
    }
    final chosen = await showModalBottomSheet<Yatra>(
      context: context,
      builder: (context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        shrinkWrap: true,
        children: [
          Text('Add to which yatra?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final y in yatras.yatras)
            ListTile(
              leading: MotifIcon(DayTheme.forDeity(y.deitySlug).motif, size: 28, color: DayTheme.forDeity(y.deitySlug).accent),
              title: Text(y.name),
              subtitle: Text('${y.stopCount} stops · ${y.days.length} days'),
              trailing: y.allStops.any((s) => s.slug == t.slug) ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.of(context).pop(y),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              final y = await yatras.create('New yatra', deitySlug: t.deity?.slug);
              if (context.mounted) Navigator.of(context).pop(y);
            },
            icon: const Icon(Icons.add_rounded),
            label: const Text('New yatra'),
          ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    await yatras.addStop(chosen, chosen.days.length - 1, stop);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added to ${chosen.name}')));
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.5))),
        child: Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)))]),
      );
}

class _TimingsTable extends StatelessWidget {
  const _TimingsTable({required this.timings, required this.accent});

  final List<Timing> timings;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.colorScheme.outlineVariant)),
      child: Column(
        children: [
          for (var i = 0; i < timings.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(timings[i].kind == 'aarti' ? Icons.local_fire_department_rounded : timings[i].kind == 'darshan' ? Icons.visibility_rounded : Icons.schedule_rounded, color: accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(timings[i].label ?? timings[i].kind ?? 'Timing', style: theme.textTheme.titleSmall),
                        Text(timings[i].dayLabel ?? 'Every day', style: theme.textTheme.bodySmall),
                        if (timings[i].notes != null) Text(timings[i].notes!, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  Text(timings[i].window ?? '${timings[i].opensAt ?? ''} – ${timings[i].closesAt ?? ''}', style: theme.textTheme.titleSmall?.copyWith(color: accent)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Renders the fee and booking exactly as the API contract requires: the fee
/// label verbatim (an unpriced puja is not free), and a link called official
/// only when `is_official` says so.
class _PujaCard extends StatelessWidget {
  const _PujaCard({required this.puja, required this.accent});

  final Puja puja;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final b = puja.booking;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (puja.imageUrl != null) AspectRatio(aspectRatio: 16 / 7, child: TempleImage(url: puja.imageUrl)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(puja.name, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif'))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: (puja.fee.isFree ? Palette.tulsi : accent).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                      child: Text(puja.fee.display, style: theme.textTheme.labelMedium?.copyWith(color: puja.fee.isFree ? Palette.tulsi : accent, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (puja.description != null) ...[const SizedBox(height: 6), Text(puja.description!, style: theme.textTheme.bodySmall?.copyWith(height: 1.4))],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    if (puja.startsAt != null) _Meta(icon: Icons.schedule_rounded, text: puja.startsAt!),
                    if (puja.durationLabel != null) _Meta(icon: Icons.hourglass_bottom_rounded, text: puja.durationLabel!),
                    if (puja.eligibility != null) _Meta(icon: Icons.person_rounded, text: puja.eligibility!),
                    if (puja.scheduleNote != null) _Meta(icon: Icons.info_outline_rounded, text: puja.scheduleNote!),
                  ],
                ),
                if (puja.includes != null) ...[const SizedBox(height: 6), Text('Includes: ${puja.includes}', style: theme.textTheme.bodySmall)],
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(b.isOfficial ? Icons.verified_rounded : Icons.info_outline_rounded, size: 16, color: b.isOfficial ? Palette.tulsi : theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Expanded(child: Text(b.label ?? (b.isOfficial ? 'Official booking' : 'Book at the temple'), style: theme.textTheme.bodySmall?.copyWith(color: b.isOfficial ? Palette.tulsi : null))),
                    if (b.url != null)
                      TextButton(
                        onPressed: () => launchUrl(Uri.parse(b.url!), mode: LaunchMode.externalApplication),
                        child: Text(b.isOfficial ? 'Book' : 'Open link'),
                      ),
                  ],
                ),
                if (b.note != null) Text(b.note!, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)), const SizedBox(width: 4), Text(text, style: Theme.of(context).textTheme.bodySmall)],
      );
}
