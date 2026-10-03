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
import '../../core/services/analytics.dart';
import '../auth/auth_screen.dart';
import 'bookings_screen.dart';
import '../../core/time_format.dart';

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
    if (!await ensureSignedIn(context) || !context.mounted) return;
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

    final picked = await chooseGateway(context, paid: puja.appBooking.totalFor(request.people) > 0);
    if (picked == null || !context.mounted) return;
    final gateway = picked.code;

    await _place(context, temple, puja, request, gateway);
  }

  static Future<void> _place(BuildContext context, TempleSummary temple, Puja puja, _BookingRequest r, String? gateway) async {
    final s = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final bookings = context.read<BookingsController>();
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
        slotId: r.slot?.id,
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
      if (!start.needsPayment) {
        close();
        if (navigator.mounted) await navigator.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(reference: start.booking.reference, justBooked: true)));
        return;
      }
      close();
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

/// Signs the devotee in first when they are not: what booking, joining an
/// event and giving to a hundi all need. True when signed in.
Future<bool> ensureSignedIn(BuildContext context) async {
  final auth = context.read<AuthController>();
  if (auth.isSignedIn) return true;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
  return context.mounted && auth.isSignedIn;
}

/// The gateway to pay through: asked only when something is to be paid and
/// the server offers more than one. Null when the devotee closed the choice.
Future<({String? code})?> chooseGateway(BuildContext context, {required bool paid}) async {
  final s = S.of(context);
  final config = context.read<AppConfigController>().config;
  if (!paid || config.gateways.length <= 1) return (code: config.defaultGateway);
  final code = await showModalBottomSheet<String>(
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
  return code == null ? null : (code: code);
}

/// Opens the gateway for a checkout the server created (a seva booking, an
/// event ticket, a hundi gift) and asks the server how it ended: "paid",
/// "pending" or "failed". Null when the devotee stopped before paying, or
/// the gateway could not start (they have been told).
Future<String?> runCheckout(BuildContext context, Checkout checkout, {String? gateway}) async {
  final s = S.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final subs = context.read<SubscriptionController>();
  if (NativeCheckout.supports(checkout.sdk)) {
    final result = await NativeCheckout.pay(checkout.sdk!);
    if (!result.completed) {
      messenger.showSnackBar(SnackBar(content: Text(result.unavailable ? s('payment_needs_store_install') : s('booking_payment_cancelled'))));
      return null;
    }
    final status = await subs.confirm(checkout.paymentId, result.fields);
    return status == 'pending' ? await subs.settle(checkout.paymentId) : status;
  }
  if (NativeCheckout.isNative(checkout.gateway ?? gateway)) {
    if (!context.mounted) return null;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s('payment_could_not_start')),
        content: Text(checkout.sdkError ?? s('payment_offline')),
        actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
    return null;
  }
  await NativeCheckout.payInBrowserTab(checkout.checkoutUrl!, settled: () async => await subs.status(checkout.paymentId) != 'pending');
  return subs.settle(checkout.paymentId, attempts: 10);
}

/// Takes the payment for a booking the server has just placed or re-opened
/// ("Pay now"), then shows where it stands. Shared by a new booking and by
/// paying again for one still awaiting payment, so both behave the same.
/// An event ticket is paid for here too.
Future<void> payFor(BuildContext context, BookingStart start, {String? gateway}) async {
  final s = S.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final bookings = context.read<BookingsController>();
  var booking = start.booking;
  final value = booking.amountPaise / 100;
  final kind = booking.isEvent ? 'event' : 'seva';
  Analytics.instance.beginCheckout(kind, item: booking.pujaName, value: value, gateway: start.gateway ?? gateway);

  final status = await runCheckout(context, start.checkout!, gateway: gateway);
  if (status == null) {
    // Still awaiting payment on the server: My seva bookings offers
    // "Pay now" until the day passes.
    await bookings.reload(booking.reference);
    return;
  }
  booking = await bookings.reload(booking.reference) ?? booking;
  if (status == 'paid' || booking.isLive) Analytics.instance.purchase(kind, item: booking.pujaName, value: value, transactionId: start.paymentId);
  if (status != 'paid' && !booking.isLive) {
    messenger.showSnackBar(SnackBar(content: Text(status == 'pending' ? s('booking_payment_pending') : s('booking_payment_failed'))));
    // The booking, awaiting payment, with "Pay now": never a ticket.
    if (navigator.mounted) await navigator.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(reference: booking.reference)));
    return;
  }
  if (navigator.mounted) await navigator.push(MaterialPageRoute(builder: (_) => BookingDetailScreen(reference: booking.reference, justBooked: true)));
}

/// "Pay now" on a booking still awaiting payment.
Future<void> payAgain(BuildContext context, PujaBooking booking) async {
  final messenger = ScaffoldMessenger.of(context);
  final s = S.of(context);
  final repo = BookingRepository(context.read<ApiClient>());
  final bookings = context.read<BookingsController>();
  try {
    final start = await repo.pay(booking.reference, platform: AppPlatform.name, event: booking.isEvent);
    await bookings.put(start.booking);
    if (!context.mounted) return;
    if (!start.needsPayment) {
      // It had gone through after all.
      await bookings.reload(booking.reference);
      messenger.showSnackBar(SnackBar(content: Text(s('booking_confirmed_title'))));
      return;
    }
    await payFor(context, start);
  } on ApiException catch (e) {
    await bookings.reload(booking.reference);
    messenger.showSnackBar(SnackBar(content: Text(e.errors.values.expand((v) => v).firstOrNull ?? e.message)));
  } catch (_) {
    messenger.showSnackBar(SnackBar(content: Text(s('payment_offline'))));
  }
}

class _BookingRequest {
  const _BookingRequest({required this.day, this.slot, required this.people, this.name, this.phone, this.gotram, this.nakshatram, this.note});

  final DateTime day;
  final PujaSlot? slot;
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

  // Time slots, when the temple set them: loaded for the chosen day.
  List<PujaSlot>? _slots;
  PujaSlot? _slot;
  bool _slotsLoading = false;
  String? _slotsError;

  @override
  void initState() {
    super.initState();
    _loadSlots();
  }

  void _setDay(DateTime d) {
    setState(() => _day = d);
    _loadSlots();
  }

  Future<void> _loadSlots() async {
    final puja = widget.puja;
    if (!puja.appBooking.hasSlots || puja.id == null) return;
    final day = _day;
    setState(() {
      _slotsLoading = true;
      _slotsError = null;
      _slot = null;
    });
    try {
      final slots = await BookingRepository(context.read<ApiClient>()).slots(templeSlug: widget.temple.slug, pujaId: puja.id!, day: day);
      if (!mounted || day != _day) return;
      setState(() {
        _slots = slots;
        // The first slot with room, so one tap books the usual case.
        _slot = slots.where((x) => x.fits(_people)).firstOrNull;
      });
    } catch (_) {
      if (mounted && day == _day) setState(() => _slotsError = 'Could not load the time slots. Check your connection.');
    } finally {
      if (mounted && day == _day) setState(() => _slotsLoading = false);
    }
  }

  /// At most what the chosen slot has room for.
  int get _maxPeople {
    final max = widget.puja.appBooking.maxPeople;
    final left = _slot?.available;
    return left == null ? max : (left < max ? left : max);
  }

  bool get _ready => !widget.puja.appBooking.hasSlots || (_slot != null && _slot!.fits(_people));

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
    if (picked != null) _setDay(DateTime(picked.year, picked.month, picked.day));
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
                for (final d in quick) ChoiceChip(label: Text(_dayLabel(d)), selected: _day == d, onSelected: (_) => _setDay(d)),
                ActionChip(avatar: const Icon(Icons.calendar_month_rounded, size: 16), label: Text(quick.contains(_day) ? s('booking_pick_day') : _dayLabel(_day)), onPressed: _pickDay),
              ],
            ),
            if (ab.hasSlots) ...[
              const SizedBox(height: 16),
              Text('Time slot', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              if (_slotsLoading)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator())
              else if (_slotsError != null)
                Row(children: [Expanded(child: Text(_slotsError!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))), TextButton(onPressed: _loadSlots, child: const Text('Retry'))])
              else if ((_slots ?? const []).isEmpty)
                Text('No time slots on ${_dayLabel(_day)}. Choose another day.', style: theme.textTheme.bodySmall)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final slot in _slots!)
                      _SlotChip(
                          slot: slot,
                          selected: _slot?.id == slot.id,
                          accent: day.accent,
                          onTap: slot.fits(1)
                              ? () => setState(() {
                                    _slot = slot;
                                    if (slot.available != null && _people > slot.available!) _people = slot.available!.clamp(1, ab.maxPeople);
                                  })
                              : null)
                  ],
                ),
            ] else if (puja.startsAt != null)
              Padding(padding: const EdgeInsets.only(top: 6), child: Text('${s('booking_starts')} ${showTime(puja.startsAt)}${puja.scheduleNote != null ? ' · ${puja.scheduleNote}' : ''}', style: theme.textTheme.bodySmall)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text(s('booking_how_many'), style: theme.textTheme.labelLarge)),
                IconButton(onPressed: _people > 1 ? () => setState(() => _people--) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
                Text('$_people', style: theme.textTheme.titleMedium),
                IconButton(onPressed: _people < _maxPeople ? () => setState(() => _people++) : null, icon: const Icon(Icons.add_circle_outline_rounded)),
              ],
            ),
            Text(_slot?.available != null && _slot!.available! < ab.maxPeople ? '${_slot!.available} left in this slot' : '${s('booking_up_to')} ${ab.maxPeople}', style: theme.textTheme.bodySmall),
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
                  onPressed: !_ready
                      ? null
                      : () => Navigator.of(context).pop(_BookingRequest(
                            day: _day,
                            slot: _slot,
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

/// A time slot to pick, like a show time: the time, and how many places
/// are left (or "Full", or "Started" for today's earlier slots).
class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot, required this.selected, required this.accent, this.onTap});

  final PujaSlot slot;
  final bool selected;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    final status = slot.started
        ? 'Started'
        : slot.isFull
            ? 'Full'
            : slot.available == null
                ? 'Open'
                : '${slot.available} left';
    final fg = selected ? Colors.white : (enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.38));
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${slot.label}, $status',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent : (enabled ? theme.colorScheme.surface : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? accent : (enabled ? accent.withValues(alpha: 0.45) : theme.colorScheme.outlineVariant)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(slot.label, style: theme.textTheme.labelLarge?.copyWith(color: fg, fontWeight: FontWeight.w700, decoration: slot.isFull ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 2),
              Text(status, style: theme.textTheme.labelSmall?.copyWith(color: selected ? Colors.white.withValues(alpha: 0.9) : (enabled ? (slot.available != null && slot.available! <= 3 ? Palette.kumkum : Palette.tulsi) : fg))),
            ],
          ),
        ),
      ),
    );
  }
}
