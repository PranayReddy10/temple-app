import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/brand.dart';
import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/bookings_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../temple/temple_screen.dart';

/// The devotee's seva bookings: the ones made in the app, each with the code
/// the temple counter scans, and the notes kept of bookings made elsewhere.
class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});

  @override
  State<BookingsScreen> createState() => _BookingsScreenState();

  /// Records a booking made outside the app (the temple's site or counter)
  /// so the reference is at hand.
  static Future<void> record(BuildContext context, TempleSummary temple, Puja puja) async {
    final ctl = context.read<BookingsController>();
    final ref = TextEditingController();
    final note = TextEditingController();
    var date = DateTime.now();
    var people = 1;
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
              Text('${puja.name} · ${temple.name.split(',').first}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(puja.booking.isOfficial ? 'Booked through the temple\'s official route. Note it here so the reference is at hand.' : 'Booked at the temple counter or elsewhere. Note it here so the reference is at hand.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now().subtract(const Duration(days: 365)), lastDate: DateTime.now().add(const Duration(days: 730)));
                        if (p != null) setSheet(() => date = p);
                      },
                      icon: const Icon(Icons.calendar_month_rounded),
                      label: Text('${date.day}/${date.month}/${date.year}'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(onPressed: () => setSheet(() => people = (people - 1).clamp(1, 20)), icon: const Icon(Icons.remove_circle_outline_rounded)),
                  Text('$people', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(onPressed: () => setSheet(() => people = (people + 1).clamp(1, 20)), icon: const Icon(Icons.add_circle_outline_rounded)),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: ref, decoration: const InputDecoration(labelText: 'Booking reference (optional)')),
              const SizedBox(height: 10),
              TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save note')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    await ctl.add(SevaBooking(
      id: DateTime.now().microsecondsSinceEpoch.toRadixString(36),
      templeSlug: temple.slug,
      templeName: temple.name,
      pujaName: puja.name,
      date: date,
      reference: ref.text.trim().isEmpty ? null : ref.text.trim(),
      people: people,
      note: note.text.trim().isEmpty ? null : note.text.trim(),
      isOfficial: puja.booking.isOfficial,
    ));
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Noted in My seva bookings.')));
  }
}

class _BookingsScreenState extends State<BookingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<BookingsController>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<BookingsController>();
    final booked = ctl.booked;
    final ahead = booked.where((b) => !b.isPast).toList();
    final over = booked.where((b) => b.isPast).toList();
    final notes = ctl.all;
    final empty = booked.isEmpty && notes.isEmpty;
    return Scaffold(
      appBar: AppBar(title: Text(s('bookings'))),
      body: RefreshIndicator(
        onRefresh: ctl.refresh,
        child: empty
            ? ListView(
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.7,
                    child: EmptyShrine(
                      motif: Motif.kalasha,
                      message: ctl.canSync
                          ? 'Pujas and sevas you book in the app appear here with the code the temple scans at its counter. Open a temple and look for "Book in the app" under Puja & seva.'
                          : 'Sign in to book pujas and sevas in the app. Your bookings, with the code the temple scans at its counter, appear here.',
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  if (ctl.error != null) const Padding(padding: EdgeInsets.only(bottom: 8), child: OfflineNote()),
                  if (ahead.isNotEmpty) ...[
                    SectionHeader(title: s('upcoming'), motif: Motif.diya, subtitle: s('booking_show_at_counter')),
                    for (final b in ahead) _BookedCard(b: b),
                  ],
                  if (over.isNotEmpty) ...[
                    SectionHeader(title: s('booking_over'), motif: Motif.bell),
                    for (final b in over) _BookedCard(b: b),
                  ],
                  if (notes.isNotEmpty) ...[
                    SectionHeader(title: s('noted_bookings'), motif: Motif.lotus, subtitle: 'Your own notes; the temple\'s confirmation is the record that counts'),
                    for (final b in notes) _NoteCard(b: b),
                  ],
                  const SizedBox(height: 12),
                  Text('A booking made in the app is confirmed by the payment, and received at the temple by scanning its code once.', style: theme.textTheme.bodySmall),
                ],
              ),
      ),
    );
  }
}

Color bookingStatusColor(String status) => switch (status) {
      'verified' => Palette.tulsi,
      'confirmed' => Palette.ash,
      'pending_payment' => Palette.gold,
      'refunded' => Palette.kumkum,
      _ => Palette.stone,
    };

IconData bookingStatusIcon(String status) => switch (status) {
      'verified' => Icons.verified_rounded,
      'confirmed' => Icons.confirmation_number_rounded,
      'pending_payment' => Icons.hourglass_top_rounded,
      'refunded' => Icons.currency_rupee_rounded,
      _ => Icons.cancel_rounded,
    };

class _BookedCard extends StatelessWidget {
  const _BookedCard({required this.b});

  final PujaBooking b;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = DayTheme.forDeity(SampleData.bySlug(b.templeSlug ?? '')?.deity?.slug);
    final color = bookingStatusColor(b.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingDetailScreen(reference: b.reference))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                child: b.isPast ? Icon(bookingStatusIcon(b.status), color: color) : Icon(Icons.qr_code_2_rounded, color: day.accent, size: 30),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.pujaName, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif')),
                    Text([b.templeName, DateFormat('EEE, d MMM').format(b.bookedFor), '${b.people} ${b.people == 1 ? 'person' : 'people'}'].whereType<String>().join(' · '), style: theme.textTheme.bodySmall, maxLines: 2),
                    const SizedBox(height: 6),
                    // Wraps: on a narrow phone the pill and the reference
                    // do not both fit beside the amount.
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                          child: Text(b.statusLabel, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
                        ),
                        Text(b.reference, style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'monospace', letterSpacing: 1)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(b.amountLabel, style: theme.textTheme.labelLarge?.copyWith(color: day.accent, fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.b});

  final SevaBooking b;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = DayTheme.forDeity(SampleData.bySlug(b.templeSlug)?.deity?.slug);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Icon(Icons.edit_note_rounded, color: day.accent)),
        ),
        title: Text(b.pujaName, style: const TextStyle(fontFamily: 'NotoSerif')),
        subtitle: Text([
          b.templeName,
          '${b.date.day}/${b.date.month}/${b.date.year} · ${b.people} ${b.people == 1 ? 'person' : 'people'}',
          if (b.reference != null) 'Ref ${b.reference}',
          if (b.note != null) b.note!,
        ].join('\n'), style: theme.textTheme.bodySmall),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(b.isOfficial ? Icons.verified_rounded : Icons.storefront_rounded, size: 18, color: b.isOfficial ? Palette.tulsi : theme.colorScheme.outline),
            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18), onPressed: () => context.read<BookingsController>().remove(b.id)),
          ],
        ),
        onTap: () => enterTemple(context, TempleScreen(slug: b.templeSlug, preview: SampleData.bySlug(b.templeSlug)), accent: day.accent),
      ),
    );
  }
}

/// One booking made in the app: the code for the counter, large; the
/// reference to read out; and where it stands.
class BookingDetailScreen extends StatefulWidget {
  const BookingDetailScreen({super.key, required this.reference, this.justBooked = false});

  final String reference;

  /// Straight after booking: a warmer heading, and the status is re-read.
  final bool justBooked;

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    final ctl = context.read<BookingsController>();
    final b = ctl.byReference(widget.reference);
    if (!ctl.canSync || (b != null && b.isPast && !b.isPendingPayment)) return;
    setState(() => _busy = true);
    await ctl.reload(widget.reference);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _cancel(PujaBooking b) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s('booking_cancel')),
        content: Text(s('booking_cancel_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s('keep'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), style: FilledButton.styleFrom(backgroundColor: Palette.kumkum), child: Text(s('booking_cancel'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await context.read<BookingsController>().cancel(b.reference);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of(context)('payment_offline'))));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final b = context.watch<BookingsController>().byReference(widget.reference);
    if (b == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyShrine(motif: Motif.diya, message: 'This booking is not on this device. Pull to refresh My seva bookings.'));
    }
    final day = DayTheme.forDeity(SampleData.bySlug(b.templeSlug ?? '')?.deity?.slug);
    final color = bookingStatusColor(b.status);
    final showCode = b.isConfirmed || b.isPendingPayment;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.justBooked ? s('booking_confirmed_title') : b.pujaName),
        actions: [if (_busy) const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) else IconButton(tooltip: s('retry'), onPressed: _reload, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          // The ticket.
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Palette.ivory, borderRadius: BorderRadius.circular(24), border: Border.all(color: b.isVerified ? Palette.tulsi : Palette.gold, width: 3)),
            child: Column(
              children: [
                Text(Brand.name.toUpperCase(), style: const TextStyle(color: Palette.deep, letterSpacing: 3, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(b.pujaName, textAlign: TextAlign.center, style: const TextStyle(color: Palette.deep, fontFamily: 'NotoSerif', fontSize: 22)),
                if (b.templeName != null) Text(b.templeName!, textAlign: TextAlign.center, style: const TextStyle(color: Palette.teak, fontSize: 13)),
                const SizedBox(height: 14),
                if (showCode)
                  QrImageView(
                    data: b.qrData,
                    size: 220,
                    backgroundColor: Palette.ivory,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Palette.kumkum),
                    dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Palette.deep),
                  )
                else
                  Container(
                    width: 220,
                    height: 160,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(bookingStatusIcon(b.status), size: 56, color: color),
                        const SizedBox(height: 8),
                        Text(b.isVerified ? s('booking_received') : b.statusLabel, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                        if (b.isVerified && b.verifiedAt != null) Text(DateFormat('d MMM, h:mm a').format(DateTime.tryParse(b.verifiedAt!)?.toLocal() ?? DateTime.now()), style: const TextStyle(color: Palette.teak, fontSize: 12)),
                      ],
                    ),
                  ),
                const SizedBox(height: 14),
                Text(s('booking_reference').toUpperCase(), style: const TextStyle(color: Palette.teak, letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w700)),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: b.reference));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied.')));
                  },
                  child: Text(b.reference, style: const TextStyle(color: Palette.deep, fontFamily: 'monospace', fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3)),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(bookingStatusIcon(b.status), size: 16, color: color), const SizedBox(width: 6), Text(b.statusLabel, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12))]),
                ),
                const SizedBox(height: 8),
                const MotifIcon(Motif.kalasha, size: 22, color: Palette.kumkum),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            b.isPendingPayment
                ? s('booking_payment_pending')
                : b.isConfirmed
                    ? s('booking_show_at_counter')
                    : b.isVerified
                        ? 'The temple received you. Thank you for your darshan.'
                        : b.cancelReason ?? b.statusLabel,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          _Fact(icon: Icons.calendar_month_rounded, label: 'Day', value: '${DateFormat('EEEE, d MMMM yyyy').format(b.bookedFor)}${b.pujaStartsAt != null ? ' · ${b.pujaStartsAt}' : ''}', accent: day.accent),
          _Fact(icon: Icons.groups_rounded, label: 'People', value: '${b.people}', accent: day.accent),
          _Fact(icon: Icons.person_rounded, label: s('booking_in_the_name_of'), value: [b.devoteeName, if (b.gotram != null) 'Gotram ${b.gotram}', if (b.nakshatram != null) b.nakshatram!].join(' · '), accent: day.accent),
          if (b.note != null) _Fact(icon: Icons.notes_rounded, label: 'Note', value: b.note!, accent: day.accent),
          _Fact(icon: Icons.currency_rupee_rounded, label: 'Paid', value: b.isFree ? s('booking_free') : '${b.amountLabel}${b.paymentStatus != null ? ' · ${b.paymentStatus}' : ''}', accent: day.accent),
          if (b.instructions != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: day.accent.withValues(alpha: 0.3))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, color: day.accent, size: 20), const SizedBox(width: 10), Expanded(child: Text(b.instructions!, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)))]),
            ),
          ],
          const SizedBox(height: 20),
          if (b.templeSlug != null)
            OutlinedButton.icon(
              onPressed: () => enterTemple(context, TempleScreen(slug: b.templeSlug!, preview: SampleData.bySlug(b.templeSlug!)), accent: day.accent),
              icon: const Icon(Icons.temple_hindu_rounded),
              label: Text(b.templeName ?? 'Open the temple'),
            ),
          if (b.canCancel) ...[
            const SizedBox(height: 8),
            TextButton.icon(onPressed: _busy ? null : () => _cancel(b), icon: const Icon(Icons.cancel_outlined, color: Palette.kumkum), label: Text(s('booking_cancel'), style: const TextStyle(color: Palette.kumkum))),
          ],
        ],
      ),
    );
  }
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
      padding: const EdgeInsets.only(bottom: 10),
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
