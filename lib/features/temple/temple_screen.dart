import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
import '../../core/state/family_controller.dart';
import '../../core/state/favourites_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/yatra_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/media_widgets.dart';
import '../../core/widgets/temple_widgets.dart';
import '../bookings/bookings_screen.dart';
import '../family/family_screen.dart';
import '../passport/stamp_widget.dart';
import '../qr/qr_screens.dart';
import '../submissions/submissions_screen.dart';
import '../photo_stamp/photo_stamp_screen.dart';

/// The full temple profile. Entered through the temple door, and while open
/// the app wears the temple deity's colour.
///
/// One long scroll with a pinned row of section anchors (Overview, Gallery,
/// Songs & videos, Darshan, Seva) rather than separate tabs, so a devotee at
/// the gate can flick from timings to the aarti video without losing place.
class TempleScreen extends StatefulWidget {
  const TempleScreen({super.key, required this.slug, this.preview});

  final String slug;
  final TempleSummary? preview;

  @override
  State<TempleScreen> createState() => _TempleScreenState();
}

class _TempleScreenState extends State<TempleScreen> {
  Result<TempleDetail>? _detail;
  Result<List<DevotionalMedia>>? _media;
  String? _error;
  int _photo = 0;
  bool _previewing = false;
  final _keys = {for (final k in _Section.values) k: GlobalKey()};
  // Cached here because dispose() may not look up ancestors through context.
  late final DayController _dayCtl = context.read<DayController>();

  @override
  void initState() {
    super.initState();
    _load();
    final slug = widget.preview?.deity?.slug;
    if (slug != null) _startPreview(slug);
    if (widget.preview != null) _loadMedia(widget.preview!);
  }

  void _startPreview(String slug) {
    if (_previewing) return;
    _previewing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _dayCtl.preview(DayTheme.forDeity(slug));
    });
  }

  @override
  void dispose() {
    if (_previewing) {
      final ctl = _dayCtl;
      WidgetsBinding.instance.addPostFrameCallback((_) => ctl.endPreview());
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<TempleRepository>().temple(widget.slug);
      if (!mounted) return;
      setState(() => _detail = r);
      final slug = r.data.summary.deity?.slug;
      if (slug != null) _startPreview(slug);
      if (widget.preview == null) _loadMedia(r.data.summary);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.isNotFound ? 'This temple is not published.' : e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load this temple.');
    }
  }

  Future<void> _loadMedia(TempleSummary t) async {
    final r = await context.read<TempleRepository>().templeMedia(t);
    if (mounted) setState(() => _media = r);
  }

  TempleSummary get _summary => _detail?.data.summary ?? widget.preview!;

  void _jump(_Section s) {
    final ctx = _keys[s]!.currentContext;
    if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 450), curve: Curves.easeInOutCubic, alignment: 0.02);
  }

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
    final media = _media?.data ?? const <DevotionalMedia>[];

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _Hero(temple: t, photos: photos, index: _photo, onPage: (i) => setState(() => _photo = i), day: day, saved: saved, onSave: () => favs.toggle(t), onOpenPhoto: (i) => _openViewer(photos, i)),
          SliverPersistentHeader(pinned: true, delegate: _AnchorBar(day: day, onTap: _jump, labels: [s('overview'), s('gallery'), s('songs_videos'), s('darshan'), s('seva')])),
          // ---- Overview -------------------------------------------------
          SliverToBoxAdapter(
            key: _keys[_Section.overview],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(t.name, style: theme.textTheme.headlineSmall)),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(shape: BoxShape.circle, color: day.accent.withValues(alpha: 0.12), border: Border.all(color: day.accent.withValues(alpha: 0.4))),
                        child: MotifIcon(day.motif, size: 34, color: day.accent, secondary: day.secondary),
                      ),
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
                  if (d?.isClosedToday == true) ...[const SizedBox(height: 12), _Banner(icon: Icons.door_front_door_rounded, text: s('closed_today'), color: Palette.kumkum)],
                  if (_detail?.isOffline == true) const Padding(padding: EdgeInsets.only(top: 8), child: OfflineNote()),
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
                          tooltip: s('directions'),
                          onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${t.location.latitude},${t.location.longitude}'), mode: LaunchMode.externalApplication),
                          icon: const Icon(Icons.directions_rounded),
                        ),
                    ],
                  ),
                  if (visited) ...[const SizedBox(height: 16), Center(child: StampWidget(visit: passport.firstVisit(t.slug)!, size: 120))],
                ],
              ),
            ),
          ),
          if (d == null && _error == null)
            const SliverToBoxAdapter(child: SizedBox(height: 120, child: DiyaLoader()))
          else if (d == null)
            SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(20), child: _Banner(icon: Icons.cloud_off_rounded, text: _error!, color: Palette.saffron)))
          else ...[
            SliverToBoxAdapter(child: SectionHeader(title: s('quick_facts'), motif: Motif.om)),
            SliverToBoxAdapter(child: _QuickFacts(detail: d, day: day)),
            if (t.shortDescription != null || d.history != null || d.significance != null) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('about'), motif: Motif.bell)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (t.shortDescription != null) Text(t.shortDescription!, style: theme.textTheme.bodyLarge?.copyWith(fontFamily: 'NotoSerif', height: 1.5)),
                      if (d.history != null && d.history != t.shortDescription) ...[const SizedBox(height: 10), Text(d.history!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))],
                      if (d.significance != null) ...[const SizedBox(height: 10), Text(d.significance!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5))],
                    ],
                  ),
                ),
              ),
            ],
            SliverPadding(padding: const EdgeInsets.fromLTRB(20, 24, 20, 0), sliver: SliverToBoxAdapter(child: MantraCard(day: day, title: s('blessing')))),
            // ---- Gallery ----------------------------------------------
            SliverToBoxAdapter(key: _keys[_Section.gallery], child: SectionHeader(title: s('gallery'), motif: Motif.lotus, subtitle: photos.isEmpty ? null : '${photos.length} photos')),
            if (photos.isEmpty)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _EmptyLine(icon: Icons.photo_library_outlined, text: s('no_photos'))))
            else
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 6, crossAxisSpacing: 6),
                  itemCount: photos.length,
                  itemBuilder: (context, i) => GestureDetector(
                    onTap: () => _openViewer(photos, i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          TempleImage(url: photos[i].thumbnail ?? photos[i].best, deitySlug: t.deity?.slug, motifSize: 28),
                          if (photos[i].category != null)
                            Positioned(left: 6, bottom: 6, child: _Pill(text: photos[i].category!, color: Colors.black54)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            // ---- Songs & videos -----------------------------------------
            SliverToBoxAdapter(key: _keys[_Section.media], child: SectionHeader(title: s('songs_videos'), motif: Motif.bell, subtitle: t.deity != null ? '${s('temples_of')} ${t.deity!.name}'.replaceFirst(s('temples_of'), 'For').trim() : null)),
            if (_media == null)
              const SliverToBoxAdapter(child: SizedBox(height: 80, child: DiyaLoader(size: 36)))
            else if (media.isEmpty)
              SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _EmptyLine(icon: Icons.music_off_rounded, text: s('no_media'))))
            else ...[
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 206,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: media.where((m) => m.type == 'video').length.clamp(0, 8),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, i) => MediaCard(media: media.where((m) => m.type == 'video').elementAt(i), day: day, width: 150),
                  ),
                ),
              ),
              SliverToBoxAdapter(child: MediaSections(media: media.where((m) => m.type != 'video').toList(), day: day)),
            ],
            // ---- Darshan ------------------------------------------------
            SliverToBoxAdapter(key: _keys[_Section.darshan], child: SectionHeader(title: s('timings'), motif: Motif.sun)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: d.timings.isEmpty ? const _EmptyLine(icon: Icons.schedule_rounded, text: 'Timings not published yet. Check with the temple before travelling.') : _TimingsTable(timings: d.timings, accent: day.accent)),
            ),
            if (d.closures.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('closures'), motif: Motif.diya)),
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
            if (d.events.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('festivals'), motif: Motif.bell)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: d.events.length,
                  itemBuilder: (context, i) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (d.events[i].imageUrl != null) AspectRatio(aspectRatio: 16 / 7, child: TempleImage(url: d.events[i].imageUrl, deitySlug: t.deity?.slug)),
                        ListTile(
                          leading: Icon(Icons.celebration_rounded, color: day.accent),
                          title: Text(d.events[i].title, style: const TextStyle(fontFamily: 'NotoSerif')),
                          subtitle: Text([d.events[i].dateLabel ?? d.events[i].startsOn, d.events[i].description].whereType<String>().join('\n')),
                          isThreeLine: d.events[i].description != null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (d.visitorRules.isNotEmpty) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('visitor_rules'), motif: Motif.namam)),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.colorScheme.outlineVariant)),
                    child: Column(
                      children: [
                        for (final e in d.visitorRules.entries)
                          ListTile(
                            dense: true,
                            leading: Icon(_ruleIcon(e.key), color: day.accent),
                            title: Text(_ruleLabel(e.key), style: theme.textTheme.labelLarge?.copyWith(letterSpacing: 0.5)),
                            subtitle: Text(e.value),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            // ---- Seva ---------------------------------------------------
            SliverToBoxAdapter(key: _keys[_Section.seva], child: SectionHeader(title: s('pujas'), motif: Motif.kalasha)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: d.pujas.isEmpty
                  ? const SliverToBoxAdapter(child: _EmptyLine(icon: Icons.local_fire_department_outlined, text: 'No pujas or sevas published yet.'))
                  : SliverList.separated(itemCount: d.pujas.length, separatorBuilder: (_, __) => const SizedBox(height: 10), itemBuilder: (context, i) => _PujaCard(puja: d.pujas[i], accent: day.accent, onBooked: () => BookingsScreen.record(context, t, d.pujas[i]))),
            ),
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
                        Chip(avatar: Icon(f.isVerified ? Icons.check_circle_rounded : Icons.circle_outlined, size: 16, color: f.isVerified ? Palette.tulsi : theme.colorScheme.outline), label: Text(f.name)),
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
            if (t.location.hasCoordinates) ...[
              SliverToBoxAdapter(child: SectionHeader(title: s('stay_travel'), motif: Motif.diya, subtitle: 'Opens in Maps; partner stays arrive in a later phase')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(avatar: const Icon(Icons.hotel_rounded, size: 16), label: Text(s('hotels_nearby')), onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/hotels/@${t.location.latitude},${t.location.longitude},13z'), mode: LaunchMode.externalApplication)),
                      ActionChip(avatar: const Icon(Icons.directions_bus_rounded, size: 16), label: Text(s('trains_buses')), onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${t.location.latitude},${t.location.longitude}&travelmode=transit'), mode: LaunchMode.externalApplication)),
                      ActionChip(avatar: const Icon(Icons.restaurant_rounded, size: 16), label: const Text('Food nearby'), onPressed: () => launchUrl(Uri.parse('https://www.google.com/maps/search/vegetarian+restaurants/@${t.location.latitude},${t.location.longitude},14z'), mode: LaunchMode.externalApplication)),
                    ],
                  ),
                ),
              ),
            ],
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: OutlinedButton.icon(onPressed: () => SubmissionsScreen.submit(context, temple: t), icon: const Icon(Icons.edit_note_rounded), label: Text(s('suggest_edit'))),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
                child: Column(
                  children: [
                    SizedBox(height: 70, width: double.infinity, child: CustomPaint(painter: GopuramPainter(color: day.accent, opacity: 0.22, tiers: 6))),
                    const SizedBox(height: 6),
                    const KolamDivider(),
                    const SizedBox(height: 10),
                    Text(
                      [
                        '${t.trust.label ?? t.trust.level.label} record',
                        if (t.trust.sourceName != null) 'Source: ${t.trust.sourceName}',
                        if (t.trust.lastVerifiedAt != null) 'Last verified ${t.trust.lastVerifiedAt}' else s('source_note'),
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

  void _openViewer(List<Photo> photos, int i) {
    if (photos.isEmpty) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoViewer(photos: photos, initial: i, deitySlug: _summary.deity?.slug), fullscreenDialog: true));
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

  /// Distance within which a GPS check-in counts as verified.
  static const double gpsRangeKm = 2.0;

  Future<void> _checkIn(TempleSummary t) async {
    final passport = context.read<PassportController>();
    final family = context.read<FamilyController>();
    final note = TextEditingController();
    String? photoPath;
    var verification = Verification.manual;
    String? verifyNote;
    bool verifying = false;
    final members = <String>{};
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          Future<void> gps() async {
            setSheet(() => verifying = true);
            try {
              var p = await Geolocator.checkPermission();
              if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
              if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw 'Location permission is needed to verify.';
              if (!t.location.hasCoordinates) throw 'This temple has no coordinates on record yet.';
              final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high));
              final km = TempleRepository.distanceKm(pos.latitude, pos.longitude, t.location.latitude!, t.location.longitude!);
              if (km <= gpsRangeKm) {
                setSheet(() {
                  verification = Verification.gps;
                  verifyNote = 'You are ${(km * 1000).round()} m from the temple. Verified by GPS.';
                });
              } else {
                setSheet(() => verifyNote = 'You are ${km.toStringAsFixed(km < 10 ? 1 : 0)} km away, outside the ${gpsRangeKm.toStringAsFixed(0)} km range. The visit will be recorded as manual.');
              }
            } catch (e) {
              setSheet(() => verifyNote = '$e');
            } finally {
              setSheet(() => verifying = false);
            }
          }

          Future<void> qr() async {
            final slug = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => QrScanScreen(expectedSlug: t.slug)));
            if (slug == t.slug) {
              setSheet(() {
                verification = Verification.qr;
                verifyNote = 'Temple code matched. Verified by temple QR.';
              });
            }
          }

          final s = S.of(context);
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Check in at ${t.name}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text('Verify with your location or the temple\'s QR code, or record the visit on your word. The passport shows which.', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: verifying || verification != Verification.manual ? null : gps,
                          icon: verifying ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(verification == Verification.gps ? Icons.verified_rounded : Icons.my_location_rounded),
                          label: Text(verification == Verification.gps ? s('verified_gps') : 'Verify by GPS'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: verification != Verification.manual ? null : qr,
                          icon: Icon(verification == Verification.qr ? Icons.verified_rounded : Icons.qr_code_scanner_rounded),
                          label: Text(verification == Verification.qr ? s('verified_qr') : s('scan_qr')),
                        ),
                      ),
                    ],
                  ),
                  if (verifyNote != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(verifyNote!, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: verification == Verification.manual ? Theme.of(context).colorScheme.error : Palette.tulsi))),
                  if (family.members.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(s('who_came'), style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        for (final m in family.members)
                          GestureDetector(
                            onTap: () => setSheet(() => members.contains(m.id) ? members.remove(m.id) : members.add(m.id)),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [MemberAvatar(member: m, size: 44, selected: members.contains(m.id)), const SizedBox(height: 3), Text(m.name.split(' ').first, style: Theme.of(context).textTheme.labelSmall)]),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
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
          );
        },
      ),
    );
    if (confirmed != true || !mounted) return;
    final first = !passport.hasVisited(t.slug);
    await passport.checkIn(t, note: note.text.trim().isEmpty ? null : note.text.trim(), photoPath: photoPath, verification: verification, members: members.toList());
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
              const SizedBox(height: 12),
              VerificationBadge(verification: visit.verification),
              const SizedBox(height: 12),
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

enum _Section { overview, gallery, media, darshan, seva }

/// Collapsing hero: a swipeable gallery under a torana, with the trust badge
/// and the save button.
class _Hero extends StatelessWidget {
  const _Hero({required this.temple, required this.photos, required this.index, required this.onPage, required this.day, required this.saved, required this.onSave, required this.onOpenPhoto});

  final TempleSummary temple;
  final List<Photo> photos;
  final int index;
  final ValueChanged<int> onPage;
  final DayTheme day;
  final bool saved;
  final VoidCallback onSave;
  final ValueChanged<int> onOpenPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 340,
      pinned: true,
      stretch: true,
      backgroundColor: day.accent,
      foregroundColor: day.onAccent(),
      title: LayoutBuilder(builder: (context, c) => Text(temple.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: day.onAccent()))),
      actions: [IconButton(tooltip: saved ? S.of(context)('saved') : S.of(context)('save'), onPressed: onSave, icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded))],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (photos.isEmpty)
              TempleImage(deitySlug: temple.deity?.slug, motifSize: 110)
            else
              PageView.builder(
                itemCount: photos.length,
                onPageChanged: onPage,
                itemBuilder: (_, i) => GestureDetector(onTap: () => onOpenPhoto(i), child: TempleImage(url: photos[i].best, deitySlug: temple.deity?.slug, motifSize: 110)),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.45, 1], colors: [Colors.black.withValues(alpha: 0.4), Colors.transparent, Colors.black.withValues(alpha: 0.55)]),
                  ),
                ),
              ),
            ),
            const Positioned(left: 0, right: 0, bottom: 0, child: IgnorePointer(child: SizedBox(height: 56, child: CustomPaint(painter: ToranaPainter(color: Palette.gold, strokeWidth: 3, scallops: 15))))),
            Positioned(left: 16, bottom: 18, child: TrustBadge(trust: temple.trust)),
            if (photos.length > 1)
              Positioned(
                right: 16,
                bottom: 18,
                child: Row(
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Container(width: i == index ? 16 : 6, height: 6, margin: const EdgeInsets.only(left: 4), decoration: BoxDecoration(color: Colors.white.withValues(alpha: i == index ? 1 : 0.5), borderRadius: BorderRadius.circular(3))),
                  ],
                ),
              ),
            if (photos.isNotEmpty && photos[index].credit != null)
              Positioned(left: 16, bottom: 44, child: Text('© ${photos[index].credit}', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white70))),
          ],
        ),
      ),
    );
  }
}

/// Pinned row of section anchors under the hero.
class _AnchorBar extends SliverPersistentHeaderDelegate {
  const _AnchorBar({required this.day, required this.onTap, required this.labels});

  final DayTheme day;
  final ValueChanged<_Section> onTap;
  final List<String> labels;

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              itemCount: labels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) => ActionChip(
                label: Text(labels[i]),
                avatar: Icon(_icons[i], size: 16, color: day.accent),
                side: BorderSide(color: day.accent.withValues(alpha: 0.35)),
                onPressed: () => onTap(_Section.values[i]),
              ),
            ),
          ),
          Container(height: 1, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }

  static const _icons = [Icons.temple_hindu_rounded, Icons.photo_library_rounded, Icons.music_note_rounded, Icons.schedule_rounded, Icons.local_fire_department_rounded];

  @override
  bool shouldRebuild(_AnchorBar old) => old.day != day || old.labels != labels;
}

class _QuickFacts extends StatelessWidget {
  const _QuickFacts({required this.detail, required this.day});

  final TempleDetail detail;
  final DayTheme day;

  @override
  Widget build(BuildContext context) {
    final t = detail.summary;
    final facts = <(IconData, String, String)>[
      if (t.deity != null) (Icons.auto_awesome_rounded, 'Deity', t.deity!.name),
      if (t.location.state != null) (Icons.map_rounded, 'State', t.location.state!),
      if (detail.builtPeriod != null) (Icons.history_rounded, 'Built', detail.builtPeriod!),
      if (detail.architectureStyle != null) (Icons.account_balance_rounded, 'Style', detail.architectureStyle!),
      for (final c in detail.categories.take(2)) (Icons.hub_rounded, c.kind ?? 'Circuit', c.name),
      if (t.location.hasCoordinates) (Icons.my_location_rounded, 'Coordinates', '${t.location.latitude!.toStringAsFixed(3)}, ${t.location.longitude!.toStringAsFixed(3)}'),
    ];
    final theme = Theme.of(context);
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: facts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => Container(
          width: 150,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: day.accent.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(facts[i].$1, size: 14, color: day.accent), const SizedBox(width: 6), Text(facts[i].$2.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: day.accent))]),
              const Spacer(),
              Text(facts[i].$3, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontFamily: 'NotoSerif')),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyLine extends StatelessWidget {
  const _EmptyLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
      child: Row(children: [Icon(icon, color: theme.colorScheme.outline), const SizedBox(width: 10), Expanded(child: Text(text, style: theme.textTheme.bodySmall))]),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
      );
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
  const _PujaCard({required this.puja, required this.accent, required this.onBooked});

  final Puja puja;
  final Color accent;
  final VoidCallback onBooked;

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
                    if (b.url != null) TextButton(onPressed: () => launchUrl(Uri.parse(b.url!), mode: LaunchMode.externalApplication), child: Text(b.isOfficial ? 'Book' : 'Open link')),
                  ],
                ),
                if (b.note != null) Text(b.note!, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: onBooked, icon: const Icon(Icons.bookmark_add_outlined, size: 16), label: const Text('I booked this'))),
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
