import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/booking_repository.dart';
import '../../core/api/temple_repository.dart';
import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/platform.dart';
import '../../core/services/analytics.dart';
import '../../core/state/app_config_controller.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/bookings_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../bookings/book_puja_sheet.dart';
import '../bookings/bookings_screen.dart';
import '../temple/temple_screen.dart';

/// Opens an event's own page: a festival, a programme, a weekly bhajan.
Future<void> openEvent(BuildContext context, TempleEvent event) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventScreen(id: event.id, preview: event)));

/// "18:30" as the devotee reads it ("6:30 PM").
String? eventTime(String? hhmm) {
  if (hhmm == null) return null;
  final parts = hhmm.split(':');
  final h = int.tryParse(parts.first);
  final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
  if (h == null || m == null) return hhmm;
  return DateFormat.jm().format(DateTime(2000, 1, 1, h, m));
}

/// "6:30 – 8:30 PM", or null for an all-day event.
String? eventTimeRange(TempleEvent e) {
  final from = eventTime(e.startsAt);
  if (from == null) return null;
  final to = eventTime(e.endsAt);
  return to == null ? from : '$from – $to';
}

/// "Free", or the server's own price label ("₹100.00 per person").
String eventPriceLabel(BuildContext context, EventRegistrationInfo r) {
  if (!r.isPaid || r.pricePaise <= 0) return S.of(context)('booking_free');
  return r.price ?? '${BookPujaFlow.rupees(r.pricePaise)} / person';
}

/// The event's type in the devotee's language ("Bhajan", "Festival").
String? eventTypeLabel(BuildContext context, String? type) {
  const known = {'festival', 'program', 'puja', 'announcement', 'bhajan'};
  if (type == null || !known.contains(type)) return null;
  return S.of(context)('event_type_$type');
}

DayTheme _themeFor(TempleEvent e) => DayTheme.forDeity(SampleData.bySlug(e.templeSlug ?? '')?.deity?.slug);

/// One event: when it is (every week, for a bhajan mandali), where, who
/// leads it, what will be sung, and "I'll join" or tickets when the temple
/// takes registrations.
class EventScreen extends StatefulWidget {
  const EventScreen({super.key, this.id, this.preview});

  /// Fetched from the server when known; the [preview] shows meanwhile.
  final int? id;
  final TempleEvent? preview;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> {
  TempleEvent? _event;
  String? _error;
  bool _loading = false;
  DateTime? _day;

  @override
  void initState() {
    super.initState();
    _event = widget.preview;
    Analytics.instance.screen('event', item: widget.id?.toString());
    _load();
  }

  Future<void> _load() async {
    final id = widget.id;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final e = await context.read<TempleRepository>().event(id);
      if (!mounted) return;
      setState(() {
        // An event listed on a temple page does not name its temple; keep
        // what the preview knew.
        _event = e.templeSlug == null && widget.preview?.templeSlug != null ? _withTemple(e, widget.preview!) : e;
        final dates = _event!.upcomingDates;
        if (_day == null || !dates.contains(_day)) _day = dates.firstOrNull;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.isNotFound ? S.of(context)('event_missing') : e.message);
    } catch (_) {
      if (mounted && _event == null) setState(() => _error = S.of(context)('event_missing'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static TempleEvent _withTemple(TempleEvent e, TempleEvent from) => TempleEvent(
        id: e.id,
        type: e.type,
        title: e.title,
        description: e.description,
        imageUrl: e.imageUrl,
        startsOn: e.startsOn,
        endsOn: e.endsOn,
        dateLabel: e.dateLabel,
        isHappeningToday: e.isHappeningToday,
        templeSlug: from.templeSlug,
        templeName: from.templeName,
        templeCity: from.templeCity,
        isAllDay: e.isAllDay,
        startsAt: e.startsAt,
        endsAt: e.endsAt,
        recurrence: e.recurrence,
        nextOn: e.nextOn,
        nextDates: e.nextDates,
        groupName: e.groupName,
        openToAll: e.openToAll,
        songs: e.songs,
        registration: e.registration,
      );

  Future<void> _join(TempleEvent e) async {
    await EventJoinFlow.start(context, e, occursOn: _day ?? e.nextDate);
    // The count of who is coming has changed.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final e = _event;
    if (e == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error != null ? EmptyShrine(motif: Motif.bell, message: _error!, action: TextButton(onPressed: _load, child: Text(s('retry')))) : const DiyaLoader(),
      );
    }
    final day = _themeFor(e);
    final r = e.registration;
    final dates = e.upcomingDates;
    final selected = _day ?? dates.firstOrNull;
    final time = eventTimeRange(e);
    final typeLabel = eventTypeLabel(context, e.type);
    return Scaffold(
      bottomNavigationBar: _ActionBar(event: e, day: day, onJoin: () => _join(e)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: e.imageUrl != null ? 220 : null,
              backgroundColor: day.accent,
              foregroundColor: day.onAccent(),
              actions: [if (_loading) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))],
              flexibleSpace: e.imageUrl == null ? null : FlexibleSpaceBar(background: TempleImage(url: e.imageUrl, deitySlug: SampleData.bySlug(e.templeSlug ?? '')?.deity?.slug)),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
              sliver: SliverList.list(
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (typeLabel != null) _Pill(label: typeLabel, color: day.accent, icon: e.isBhajan ? Icons.music_note_rounded : Icons.celebration_rounded),
                      if (e.isWeekly) _Pill(label: s('event_weekly'), color: Palette.tulsi, icon: Icons.repeat_rounded),
                      _Pill(label: e.openToAll ? s('event_open_to_all') : s('event_invite_only'), color: e.openToAll ? Palette.tulsi : Palette.stone, icon: e.openToAll ? Icons.groups_rounded : Icons.lock_outline_rounded),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(e.title, style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'NotoSerif')),
                  if (e.groupName != null) ...[
                    const SizedBox(height: 4),
                    Text('${s('event_led_by')} ${e.groupName}', style: theme.textTheme.bodyMedium?.copyWith(color: day.accent, fontWeight: FontWeight.w600)),
                  ],
                  if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))),
                  if (e.templeSlug != null || e.templeName != null) ...[
                    const SizedBox(height: 14),
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: ClipRRect(borderRadius: BorderRadius.circular(10), child: SizedBox(width: 44, height: 44, child: TempleCover(slug: e.templeSlug, motifSize: 22))),
                        title: Text(e.templeName ?? '', style: const TextStyle(fontFamily: 'NotoSerif')),
                        subtitle: e.templeCity == null ? null : Text(e.templeCity!),
                        trailing: e.templeSlug == null ? null : const Icon(Icons.chevron_right_rounded),
                        onTap: e.templeSlug == null ? null : () => enterTemple(context, TempleScreen(slug: e.templeSlug!, preview: SampleData.bySlug(e.templeSlug!)), accent: day.accent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _Fact(
                    icon: Icons.calendar_month_rounded,
                    label: s('event_when'),
                    value: e.isWeekly && selected != null ? '${s('event_every')} ${DateFormat('EEEE').format(selected)}' : (selected != null ? DateFormat('EEEE, d MMMM yyyy').format(selected) : (e.dateLabel ?? e.startsOn ?? '')),
                    accent: day.accent,
                  ),
                  if (dates.length > 1) ...[
                    Text(s('event_pick_date'), style: theme.textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in dates)
                          ChoiceChip(
                            label: Text(DateFormat('EEE, d MMM').format(d)),
                            selected: selected == d,
                            onSelected: (_) => setState(() => _day = d),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                  ],
                  _Fact(icon: Icons.schedule_rounded, label: s('event_time'), value: time ?? s('event_all_day'), accent: day.accent),
                  if (r.enabled)
                    _Fact(
                      icon: Icons.groups_rounded,
                      label: s('event_attendance'),
                      value: [
                        '${r.going} ${s('event_going')}',
                        if (r.capacity != null) (r.isFull ? s('event_full') : s('event_places_left').replaceFirst('{n}', '${r.left}')),
                        eventPriceLabel(context, r),
                      ].join(' · '),
                      accent: day.accent,
                    ),
                  if (e.description != null && e.description!.trim().isNotEmpty) ...[
                    SectionHeader(title: s('event_about'), motif: Motif.lotus),
                    Text(e.description!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                  ],
                  if (e.songs.isNotEmpty) ...[
                    SectionHeader(title: s('event_songs'), motif: Motif.bell),
                    for (var i = 0; i < e.songs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                              child: Text('${i + 1}', style: theme.textTheme.labelSmall?.copyWith(color: day.accent, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Padding(padding: const EdgeInsets.only(top: 3), child: Text(e.songs[i], style: theme.textTheme.bodyMedium))),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The price and the one button: "I'll join", "Buy tickets", or a note
/// that nobody needs to sign up.
class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.event, required this.day, required this.onJoin});

  final TempleEvent event;
  final DayTheme day;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final r = event.registration;
    if (!r.enabled) {
      if (!event.openToAll || !event.isBhajan) return const SizedBox.shrink();
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(children: [const Icon(Icons.check_circle_outline_rounded, color: Palette.tulsi), const SizedBox(width: 8), Expanded(child: Text(s('event_no_signup'), style: theme.textTheme.bodyMedium))]),
        ),
      );
    }
    final canJoin = event.upcomingDates.isNotEmpty;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.paddingOf(context).bottom + 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(eventPriceLabel(context, r), style: theme.textTheme.titleMedium?.copyWith(color: day.accent, fontWeight: FontWeight.w800)),
                Text('${r.going} ${s('event_going')}', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Shrinks its label rather than squeezing the price to nothing on
          // a narrow phone with large text.
          Flexible(
            flex: 3,
            child: FilledButton.icon(
              onPressed: canJoin ? onJoin : null,
              style: FilledButton.styleFrom(backgroundColor: day.accent, foregroundColor: day.onAccent(), minimumSize: const Size.fromHeight(48), padding: const EdgeInsets.symmetric(horizontal: 14)),
              icon: Icon(r.isPaid ? Icons.confirmation_number_rounded : Icons.front_hand_rounded),
              label: FittedBox(fit: BoxFit.scaleDown, child: Text(r.isPaid ? s('event_buy_tickets') : s('event_join'), maxLines: 1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value, required this.accent});

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                Text(value, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "I'll join" or "Buy tickets": signed in first, the people and names,
/// then the same checkout a seva booking is paid through.
class EventJoinFlow {
  const EventJoinFlow._();

  static Future<void> start(BuildContext context, TempleEvent event, {DateTime? occursOn}) async {
    final s = S.of(context);
    final r = event.registration;
    if (event.id == null || !r.enabled) return;
    if (!await ensureSignedIn(context) || !context.mounted) return;
    final config = context.read<AppConfigController>().config;
    if (r.isPaid && !config.templePaymentsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(config.paymentsElsewhere ? s('booking_pay_elsewhere') : s('booking_pay_soon'))));
      return;
    }
    final request = await showModalBottomSheet<_JoinRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _JoinSheet(event: event, day: occursOn, devotee: context.read<AuthController>().devotee),
    );
    if (request == null || !context.mounted) return;
    final picked = await chooseGateway(context, paid: r.totalFor(request.people) > 0);
    if (picked == null || !context.mounted) return;
    await _place(context, event, occursOn, request, picked.code);
  }

  static Future<void> _place(BuildContext context, TempleEvent event, DateTime? occursOn, _JoinRequest r, String? gateway) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final bookings = context.read<BookingsController>();
    final repo = BookingRepository(context.read<ApiClient>());

    var closed = false;
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())));
    void close() {
      if (!closed && navigator.mounted) {
        closed = true;
        navigator.pop();
      }
    }

    try {
      final start = await repo.joinEvent(eventId: event.id!, occursOn: occursOn, people: r.people, name: r.name, phone: r.phone, gateway: gateway, platform: AppPlatform.name);
      await bookings.put(start.booking);
      close();
      if (!start.needsPayment) {
        if (navigator.mounted) await navigator.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(reference: start.booking.reference, justBooked: true)));
        return;
      }
      if (!context.mounted) return;
      await payFor(context, start, gateway: gateway);
    } on ApiException catch (e) {
      close();
      messenger.showSnackBar(SnackBar(content: Text(e.errors.values.expand((v) => v).firstOrNull ?? e.message)));
    } catch (_) {
      close();
      messenger.showSnackBar(SnackBar(content: Text(s('payment_offline'))));
    }
  }
}

class _JoinRequest {
  const _JoinRequest({required this.people, this.name, this.phone});

  final int people;
  final String? name;
  final String? phone;
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({required this.event, this.day, this.devotee});

  final TempleEvent event;
  final DateTime? day;
  final Devotee? devotee;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  late final _name = TextEditingController(text: widget.devotee?.name ?? '');
  late final _phone = TextEditingController(text: widget.devotee?.phone ?? '');
  int _people = 1;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  /// No more than one registration may bring, nor than places left on the
  /// next date (the count the server gives is for that date).
  int get _max {
    final r = widget.event.registration;
    final left = widget.day == null || widget.day == widget.event.nextDate ? r.left : null;
    final max = left == null ? r.maxPeople : (left < r.maxPeople ? left : r.maxPeople);
    return max < 1 ? 1 : max;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final e = widget.event;
    final r = e.registration;
    final day = _themeFor(e);
    final total = r.totalFor(_people);
    final when = [if (widget.day != null) DateFormat('EEE, d MMM').format(widget.day!), eventTimeRange(e)].whereType<String>().join(' · ');
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(width: 44, height: 44, decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)), child: Icon(e.isBhajan ? Icons.music_note_rounded : Icons.celebration_rounded, color: day.accent)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'NotoSerif')),
                      if (when.isNotEmpty) Text(when, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(eventPriceLabel(context, r), style: theme.textTheme.bodySmall?.copyWith(color: Palette.tulsi, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(s('event_how_many'), style: theme.textTheme.labelLarge)),
                IconButton(onPressed: _people > 1 ? () => setState(() => _people--) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
                Text('$_people', style: theme.textTheme.titleMedium),
                IconButton(onPressed: _people < _max ? () => setState(() => _people++) : null, icon: const Icon(Icons.add_circle_outline_rounded)),
              ],
            ),
            Text(s('event_up_to').replaceFirst('{n}', '$_max'), style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: s('booking_in_the_name_of'), prefixIcon: const Icon(Icons.person_rounded))),
            const SizedBox(height: 10),
            TextField(controller: _phone, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]'))], decoration: InputDecoration(labelText: s('booking_phone'), prefixIcon: const Icon(Icons.call_rounded))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s('booking_total').toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5)),
                      Text(total == 0 ? s('booking_free') : BookPujaFlow.rupees(total), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: day.accent)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  flex: 3,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(context).pop(_JoinRequest(people: _people, name: _name.text.trim(), phone: _phone.text.trim())),
                    style: FilledButton.styleFrom(backgroundColor: day.accent, foregroundColor: day.onAccent(), minimumSize: const Size.fromHeight(50), padding: const EdgeInsets.symmetric(horizontal: 16)),
                    icon: Icon(total == 0 ? Icons.check_circle_rounded : Icons.lock_rounded),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(total == 0 ? s('event_join') : '${s('event_buy_tickets')} · ${BookPujaFlow.rupees(total)}', maxLines: 1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(s('event_footnote'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

/// A bhajan gathering on Home: the next date and time, who leads it, how
/// many are going, and whether it is free.
class BhajanCard extends StatelessWidget {
  const BhajanCard({super.key, required this.event});

  final TempleEvent event;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = event;
    final next = e.nextDate;
    final time = eventTime(e.startsAt);
    final r = e.registration;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => openEvent(context, e),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 58,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Text(next == null ? '' : DateFormat('EEE').format(next).toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary, letterSpacing: 1)),
                      Text(next == null ? '' : '${next.day}', style: theme.textTheme.titleLarge?.copyWith(color: scheme.primary)),
                      Icon(Icons.music_note_rounded, size: 16, color: scheme.primary),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif'), maxLines: 2, overflow: TextOverflow.ellipsis),
                      if (e.templeName != null) Text('${e.templeName}${e.templeCity != null ? ' · ${e.templeCity}' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                      Text(
                        [if (next != null) DateFormat('EEE, d MMM').format(next), if (time != null) time].join(' · '),
                        style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary, fontWeight: FontWeight.w700),
                      ),
                      if (e.groupName != null) Text(e.groupName!, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (e.isWeekly) _Pill(label: s('event_weekly'), color: Palette.tulsi, icon: Icons.repeat_rounded),
                          if (r.enabled && r.going > 0) _Pill(label: '${r.going} ${s('event_going')}', color: scheme.primary, icon: Icons.groups_rounded),
                          _Pill(label: eventPriceLabel(context, r), color: r.isPaid ? Palette.saffron : Palette.tulsi),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: scheme.onSurface.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
