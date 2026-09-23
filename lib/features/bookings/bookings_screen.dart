import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

/// The devotee's own record of sevas booked through official routes.
class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<BookingsController>();
    final upcoming = ctl.upcoming;
    final past = ctl.all.where((b) => b.isPast).toList();
    return Scaffold(
      appBar: AppBar(title: Text(s('bookings'))),
      body: ctl.all.isEmpty
          ? const EmptyShrine(motif: Motif.kalasha, message: 'When you book a puja or seva through a temple\'s official route, note it here so the reference is at hand at the counter. Open any puja on a temple page and tap "I booked this".')
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                if (upcoming.isNotEmpty) SectionHeader(title: s('upcoming'), motif: Motif.diya),
                for (final b in upcoming) _BookingCard(b: b),
                if (past.isNotEmpty) const SectionHeader(title: 'Completed', motif: Motif.bell),
                for (final b in past) _BookingCard(b: b),
                const SizedBox(height: 12),
                Text('The app never takes payment. These are your own notes; the temple\'s confirmation is the record that counts.', style: theme.textTheme.bodySmall),
              ],
            ),
    );
  }

  /// Records a booking from a temple page.
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
              Text(puja.booking.isOfficial ? 'Booked through the temple\'s official route.' : 'Note: the record for this puja has no official online booking route. Book at the temple counter.', style: Theme.of(context).textTheme.bodySmall),
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
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save booking')),
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
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking noted in My seva bookings.')));
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.b});

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
          child: Center(child: Icon(Icons.local_fire_department_rounded, color: day.accent)),
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
