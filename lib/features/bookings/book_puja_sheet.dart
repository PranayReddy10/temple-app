import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/booking_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/payments/native_checkout.dart';
import '../../core/platform.dart';
import '../../core/state/app_config_controller.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/bookings_controller.dart';
import '../../core/state/subscription_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../auth/auth_screen.dart';
import 'bookings_screen.dart';

/// Booking a puja, seva or prasadam in the app, where the temple has
/// switched it on for that seva.
///
/// One sheet: the day, how many, whose name the sankalpam is in, and the
/// total. A free seva is booked at once; a priced one is paid the way a plan
/// is (the gateway's own sheet in the app, or its page in a browser tab),
/// and the server confirms the booking when the gateway confirms the money.
/// The app's word never confirms anything.
class BookPujaFlow {
  const BookPujaFlow._();

  static String rupees(int paise) => NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: paise % 100 == 0 ? 0 : 2).format(paise / 100);

  static Future<void> start(BuildContext context, TempleSummary temple, Puja puja) async {
    final s = S.of(context);
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
      if (!context.mounted || !auth.isSignedIn) return;
    }
    final config = context.read<AppConfigController>().config;
    if (puja.appBooking.requiresPayment && !config.paymentsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(config.paymentsElsewhere ? s('booking_pay_elsewhere') : s('booking_pay_soon'))));
      return;
    }

    final request = await showModalBottomSheet<_BookingRequest>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _BookPujaSheet(temple: temple, puja: puja, devotee: auth.devotee),
    );
    if (request == null || !context.mounted) return;

    String? gateway = config.defaultGateway;
    if (puja.appBooking.totalFor(request.people) > 0 && config.gateways.length > 1) {
      gateway = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(padding: const EdgeInsets.all(16), child: Text(s('pay_with'), style: Theme.of(context).textTheme.titleMedium)),
              for (final g in config.gateways)
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(g.name),
                  subtitle: Text(g.code == 'phonepe' ? 'UPI, cards' : 'UPI, cards, net banking, wallets'),
                  trailing: g.code == config.defaultGateway ? const Icon(Icons.star_rounded, size: 18) : null,
                  onTap: () => Navigator.of(context).pop(g.code),
                ),
            ],
          ),
        ),
      );
      if (gateway == null || !context.mounted) return;
    }

    await _place(context, temple, puja, request, gateway);
  }

  static Future<void> _place(BuildContext context, TempleSummary temple, Puja puja, _BookingRequest r, String? gateway) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final bookings = context.read<BookingsController>();
    final subs = context.read<SubscriptionController>();
    final repo = BookingRepository(context.read<ApiClient>());

    // A modal spinner while the server and the gateway talk: leaving the
    // page mid-payment is how a devotee ends up paid and unsure.
    var closed = false;
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())));
    void close() {
      if (!closed && navigator.mounted) {
        closed = true;
        navigator.pop();
      }
    }

    try {
      final start = await repo.book(
        templeSlug: temple.slug,
        pujaId: puja.id!,
        day: r.day,
        people: r.people,
        name: r.name,
        phone: r.phone,
        gotram: r.gotram,
        nakshatram: r.nakshatram,
        note: r.note,
        gateway: gateway,
        platform: AppPlatform.name,
      );
      await bookings.put(start.booking);
      var booking = start.booking;

      if (start.needsPayment) {
        close();
        String status;
        if (NativeCheckout.supports(start.sdk)) {
          final result = await NativeCheckout.pay(start.sdk!);
          if (!result.completed) {
            messenger.showSnackBar(SnackBar(content: Text(s('booking_payment_cancelled'))));
            // The booking stays pending on the server until it expires; the
            // devotee can see it and try again from My seva bookings.
            return;
          }
          status = await subs.confirm(start.paymentId!, result.fields);
          if (status == 'pending') status = await subs.settle(start.paymentId!);
        } else if (NativeCheckout.isNative(start.gateway ?? gateway)) {
          if (!context.mounted) return;
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(s('payment_could_not_start')),
              content: Text(start.sdkError ?? s('payment_offline')),
              actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
            ),
          );
          return;
        } else {
          await NativeCheckout.payInBrowserTab(start.checkoutUrl!);
          status = await subs.settle(start.paymentId!, attempts: 10);
        }
        booking = await bookings.reload(booking.reference) ?? booking;
        if (status != 'paid' && !booking.isConfirmed) {
          messenger.showSnackBar(SnackBar(content: Text(status == 'pending' ? s('booking_payment_pending') : s('booking_payment_failed'))));
          if (status == 'pending' && navigator.mounted) navigator.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(reference: booking.reference)));
          return;
        }
      } else {
        close();
      }
      if (!navigator.mounted) return;
      await navigator.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(reference: booking.reference, justBooked: true)));
    } on ApiException catch (e) {
      close();
      messenger.showSnackBar(SnackBar(content: Text(e.errors.values.expand((v) => v).firstOrNull ?? e.message)));
    } catch (_) {
      close();
      messenger.showSnackBar(SnackBar(content: Text(s('payment_offline'))));
    }
  }
}

class _BookingRequest {
  const _BookingRequest({required this.day, required this.people, this.name, this.phone, this.gotram, this.nakshatram, this.note});

  final DateTime day;
  final int people;
  final String? name;
  final String? phone;
  final String? gotram;
  final String? nakshatram;
  final String? note;
}

class _BookPujaSheet extends StatefulWidget {
  const _BookPujaSheet({required this.temple, required this.puja, this.devotee});

  final TempleSummary temple;
  final Puja puja;
  final Devotee? devotee;

  @override
  State<_BookPujaSheet> createState() => _BookPujaSheetState();
}

class _BookPujaSheetState extends State<_BookPujaSheet> {
  late final _name = TextEditingController(text: widget.devotee?.name ?? '');
  late final _phone = TextEditingController(text: widget.devotee?.phone ?? '');
  final _gotram = TextEditingController();
  final _nakshatram = TextEditingController();
  final _note = TextEditingController();
  late DateTime _day = _today;
  int _people = 1;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _gotram, _nakshatram, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDay() async {
    final last = _today.add(Duration(days: widget.puja.appBooking.advanceDays));
    final picked = await showDatePicker(context: context, initialDate: _day.isAfter(last) ? last : _day, firstDate: _today, lastDate: last);
    if (picked != null) setState(() => _day = DateTime(picked.year, picked.month, picked.day));
  }

  String _dayLabel(DateTime d) {
    if (d == _today) return 'Today';
    if (d == _today.add(const Duration(days: 1))) return 'Tomorrow';
    return DateFormat('EEE, d MMM').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final puja = widget.puja;
    final ab = puja.appBooking;
    final day = DayTheme.forDeity(widget.temple.deity?.slug);
    final total = ab.totalFor(_people);
    final quick = [_today, _today.add(const Duration(days: 1)), _today.add(const Duration(days: 2))].where((d) => !d.isAfter(_today.add(Duration(days: ab.advanceDays)))).toList();
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
                Container(width: 44, height: 44, decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)), child: Icon(Icons.local_fire_department_rounded, color: day.accent)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(puja.name, style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'NotoSerif')),
                      Text(widget.temple.name, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              ab.requiresPayment ? (ab.feePerPerson ? '${BookPujaFlow.rupees(ab.amountPaise)} per person' : '${BookPujaFlow.rupees(ab.amountPaise)} per booking') : s('booking_free_note'),
              style: theme.textTheme.bodySmall?.copyWith(color: Palette.tulsi, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Text(s('booking_which_day'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in quick) ChoiceChip(label: Text(_dayLabel(d)), selected: _day == d, onSelected: (_) => setState(() => _day = d)),
                ActionChip(avatar: const Icon(Icons.calendar_month_rounded, size: 16), label: Text(quick.contains(_day) ? s('booking_pick_day') : _dayLabel(_day)), onPressed: _pickDay),
              ],
            ),
            if (puja.startsAt != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${s('booking_starts')} ${puja.startsAt}${puja.scheduleNote != null ? ' · ${puja.scheduleNote}' : ''}', style: theme.textTheme.bodySmall)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(s('booking_how_many'), style: theme.textTheme.labelLarge)),
                IconButton(onPressed: _people > 1 ? () => setState(() => _people--) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
                Text('$_people', style: theme.textTheme.titleMedium),
                IconButton(onPressed: _people < ab.maxPeople ? () => setState(() => _people++) : null, icon: const Icon(Icons.add_circle_outline_rounded)),
              ],
            ),
            Text('${s('booking_up_to')} ${ab.maxPeople}', style: theme.textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: s('booking_in_the_name_of'), prefixIcon: const Icon(Icons.person_rounded))),
            const SizedBox(height: 10),
            TextField(controller: _phone, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]'))], decoration: InputDecoration(labelText: s('booking_phone'), prefixIcon: const Icon(Icons.call_rounded), helperText: s('booking_phone_help'))),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: TextField(controller: _gotram, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Gotram (optional)'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: _nakshatram, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nakshatram (optional)'))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(controller: _note, maxLength: 500, maxLines: 2, decoration: InputDecoration(labelText: s('booking_note'), counterText: '')),
            if (ab.instructions != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: day.accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: day.accent.withValues(alpha: 0.3))),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.info_outline_rounded, size: 18, color: day.accent), const SizedBox(width: 8), Expanded(child: Text(ab.instructions!, style: theme.textTheme.bodySmall))]),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s('booking_total').toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.5)),
                      Text(total == 0 ? s('booking_free') : BookPujaFlow.rupees(total), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: day.accent)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_BookingRequest(
                    day: _day,
                    people: _people,
                    name: _name.text.trim(),
                    phone: _phone.text.trim(),
                    gotram: _gotram.text.trim(),
                    nakshatram: _nakshatram.text.trim(),
                    note: _note.text.trim(),
                  )),
                  style: FilledButton.styleFrom(backgroundColor: day.accent, foregroundColor: day.onAccent(), minimumSize: const Size(0, 50), padding: const EdgeInsets.symmetric(horizontal: 20)),
                  icon: Icon(total == 0 ? Icons.check_circle_rounded : Icons.lock_rounded),
                  label: Text(total == 0 ? s('booking_book_free') : '${s('booking_pay_and_book')} ${BookPujaFlow.rupees(total)}'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(s('booking_footnote'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}
