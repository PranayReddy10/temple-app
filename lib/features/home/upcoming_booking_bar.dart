import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/state/bookings_controller.dart';
import '../../core/theme/palette.dart';
import '../bookings/bookings_screen.dart';

/// The seva or ticket coming up, pinned to the bottom of Home.
///
/// It stays until the temple marks the devotee received, the day passes, or
/// it is cancelled, so the next thing they booked is always one tap away:
/// the details, and the way there.
class UpcomingBookingBar extends StatelessWidget {
  const UpcomingBookingBar({super.key});

  /// How much room the bar takes, so the page can scroll clear of it.
  static const double height = 92;

  static String dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = context.watch<BookingsController>().upcomingBooked;
    if (upcoming.isEmpty) return const SizedBox.shrink();
    final b = upcoming.first;
    final more = upcoming.length - 1;
    final theme = Theme.of(context);
    final color = bookingStatusColor(b.status);
    final time = b.slotLabel ?? b.pujaStartsAt;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Material(
          elevation: 8,
          shadowColor: Colors.black38,
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookingDetailScreen(reference: b.reference))),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Palette.gold.withValues(alpha: 0.6), width: 1.5),
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Row(children: [
                // The day, as on a ticket stub.
                Container(
                  width: 52,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(color: Palette.kumkum.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(DateFormat('MMM').format(b.bookedFor).toUpperCase(), style: const TextStyle(fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.w700, color: Palette.kumkum)),
                    Text('${b.bookedFor.day}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Palette.kumkum, height: 1.1)),
                  ]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Icon(b.isEvent ? Icons.confirmation_number_rounded : Icons.local_fire_department_rounded, size: 14, color: color),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          b.isPendingPayment ? 'Awaiting payment' : (b.isEvent ? 'Your ticket' : 'Your seva'),
                          style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (more > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(99)),
                          child: Text('+$more more', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 2),
                    Text(b.pujaName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    Text(
                      [dayLabel(b.bookedFor), if (time != null) time, if (b.templeName != null) b.templeName!].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: S.of(context)('directions'),
                  onPressed: b.templeName == null ? null : () => openBookingDirections(b),
                  icon: const Icon(Icons.directions_rounded),
                  color: theme.colorScheme.primary,
                ),
                if (more > 0)
                  IconButton(
                    tooltip: 'All bookings',
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookingsScreen())),
                    icon: const Icon(Icons.list_alt_rounded),
                  )
                else
                  const Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

