import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/donation_repository.dart';
import '../../core/brand.dart';
import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/platform.dart';
import '../../core/services/analytics.dart';
import '../../core/state/app_config_controller.dart';
import '../../core/state/auth_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../bookings/book_puja_sheet.dart';
import '../temple/temple_screen.dart';

/// "Give to the hundi" from a temple page: signed in first, and only where
/// payments are open, the same as booking a seva.
Future<void> openHundi(BuildContext context, TempleSummary temple, DonationSettings settings) async {
  final s = S.of(context);
  if (!await ensureSignedIn(context) || !context.mounted) return;
  final config = context.read<AppConfigController>().config;
  if (!config.paymentsEnabled) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(config.paymentsElsewhere ? s('booking_pay_elsewhere') : s('booking_pay_soon'))));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DonateScreen(temple: temple, settings: settings)));
}

Color donationStatusColor(String status) => switch (status) {
      'paid' => Palette.tulsi,
      'pending_payment' => Palette.gold,
      'failed' => Palette.kumkum,
      _ => Palette.stone,
    };

IconData donationStatusIcon(String status) => switch (status) {
      'paid' => Icons.verified_rounded,
      'pending_payment' => Icons.hourglass_top_rounded,
      'failed' => Icons.cancel_rounded,
      _ => Icons.currency_rupee_rounded,
    };

/// The online hundi: an amount (a suggested one or the devotee's own), what
/// it is for, the name on the receipt or none, and a note. Paid through the
/// same checkout as a seva booking; the server's word is the receipt.
class DonateScreen extends StatefulWidget {
  const DonateScreen({super.key, required this.temple, required this.settings});

  final TempleSummary temple;
  final DonationSettings settings;

  @override
  State<DonateScreen> createState() => _DonateScreenState();
}

class _DonateScreenState extends State<DonateScreen> {
  late final _name = TextEditingController(text: context.read<AuthController>().devotee?.name ?? '');
  final _custom = TextEditingController();
  final _note = TextEditingController();
  late int? _chosen = _suggested.length > 2 ? _suggested[2] : _suggested.firstOrNull;
  late String? _purpose = widget.settings.purposes.firstOrNull?.value;
  bool _anonymous = false;
  bool _busy = false;

  List<int> get _suggested => widget.settings.suggestedAmounts.where((a) => a >= widget.settings.minAmount && a <= widget.settings.maxAmount).toList();

  @override
  void initState() {
    super.initState();
    Analytics.instance.screen('hundi', item: widget.temple.slug);
  }

  @override
  void dispose() {
    _name.dispose();
    _custom.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _amount => _custom.text.trim().isNotEmpty ? int.tryParse(_custom.text.trim()) : _chosen;

  bool get _valid {
    final a = _amount;
    return a != null && a >= widget.settings.minAmount && a <= widget.settings.maxAmount;
  }

  static String _rupees(int r) => NumberFormat.decimalPattern('en_IN').format(r);

  Future<void> _give() async {
    final s = S.of(context);
    final amount = _amount;
    if (amount == null || !_valid) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final repo = DonationRepository(context.read<ApiClient>());
    final picked = await chooseGateway(context, paid: true);
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final start = await repo.give(
        templeSlug: widget.temple.slug,
        amountRupees: amount,
        purpose: _purpose,
        donorName: _anonymous ? null : _name.text.trim(),
        anonymous: _anonymous,
        note: _note.text.trim(),
        gateway: picked.code,
        platform: AppPlatform.name,
      );
      if (!mounted) return;
      final checkout = start.checkout;
      if (checkout != null) {
        Analytics.instance.beginCheckout('hundi', item: widget.temple.slug, value: amount, gateway: checkout.gateway ?? picked.code);
        final status = await runCheckout(context, checkout, gateway: picked.code);
        // Stopped before paying: stay here, the form as it was.
        if (status == null) return;
        if (status == 'paid') Analytics.instance.purchase('hundi', item: widget.temple.slug, value: amount, transactionId: checkout.paymentId);
      }
      // The server reconciles with the gateway before it answers.
      Donation donation = start.donation;
      try {
        donation = await repo.show(start.donation.reference);
      } catch (_) {}
      if (!navigator.mounted) return;
      await navigator.pushReplacement(MaterialPageRoute(builder: (_) => DonationReceiptScreen(donation: donation, justGiven: true)));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.errors.values.expand((v) => v).firstOrNull ?? e.message)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s('payment_offline'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final t = widget.temple;
    final day = DayTheme.forDeity(t.deity?.slug);
    final set = widget.settings;
    final amount = _amount;
    return Scaffold(
      appBar: AppBar(title: Text(s('hundi_give'))),
      bottomNavigationBar: Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: FilledButton.icon(
              onPressed: _valid && !_busy ? _give : null,
              style: FilledButton.styleFrom(backgroundColor: day.accent, foregroundColor: day.onAccent(), minimumSize: const Size.fromHeight(52)),
              icon: _busy ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: day.onAccent())) : const Icon(Icons.lock_rounded),
              label: Text(amount == null ? s('hundi_pay') : '${s('hundi_pay')} ₹${_rupees(amount)}'),
            ),
          ),
        ),
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Row(
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: SizedBox(width: 56, height: 56, child: TempleCover(slug: t.slug, deitySlug: t.deity?.slug, photo: t.primaryPhoto))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name, style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'NotoSerif')),
                      Text(s('hundi_pitch'), style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            SectionHeader(title: s('hundi_amount'), motif: Motif.kalasha),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final a in _suggested)
                  ChoiceChip(
                    label: Text('₹${_rupees(a)}'),
                    selected: _custom.text.trim().isEmpty && _chosen == a,
                    onSelected: (_) => setState(() {
                      _chosen = a;
                      _custom.clear();
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _custom,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: s('hundi_other_amount'),
                prefixIcon: const Icon(Icons.currency_rupee_rounded),
                helperText: s('hundi_range').replaceFirst('{min}', _rupees(set.minAmount)).replaceFirst('{max}', _rupees(set.maxAmount)),
                errorText: _custom.text.trim().isNotEmpty && !_valid ? s('hundi_range').replaceFirst('{min}', _rupees(set.minAmount)).replaceFirst('{max}', _rupees(set.maxAmount)) : null,
              ),
            ),
            if (set.purposes.isNotEmpty) ...[
              SectionHeader(title: s('hundi_purpose'), motif: Motif.lotus),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in set.purposes) ChoiceChip(label: Text(p.label), selected: _purpose == p.value, onSelected: (_) => setState(() => _purpose = p.value)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              enabled: !_anonymous,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s('hundi_name'), prefixIcon: const Icon(Icons.person_rounded)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _anonymous,
              onChanged: (v) => setState(() => _anonymous = v),
              title: Text(s('hundi_anonymous')),
              subtitle: Text(s('hundi_anonymous_note')),
            ),
            TextField(controller: _note, maxLength: 300, maxLines: 2, decoration: InputDecoration(labelText: s('hundi_note'))),
          ],
        ),
      ),
    );
  }
}

/// A hundi gift's receipt: amount, temple, purpose, who gave it, and
/// whether the money arrived. Re-read from the server on open.
class DonationReceiptScreen extends StatefulWidget {
  const DonationReceiptScreen({super.key, required this.donation, this.justGiven = false});

  final Donation donation;
  final bool justGiven;

  @override
  State<DonationReceiptScreen> createState() => _DonationReceiptScreenState();
}

class _DonationReceiptScreenState extends State<DonationReceiptScreen> {
  late Donation _d = widget.donation;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (!widget.justGiven || _d.isPending) WidgetsBinding.instance.addPostFrameCallback((_) => _reload());
  }

  Future<void> _reload() async {
    setState(() => _busy = true);
    try {
      final d = await DonationRepository(context.read<ApiClient>()).show(_d.reference);
      if (mounted) setState(() => _d = d);
    } catch (_) {
      // The copy in hand stands.
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final d = _d;
    final day = DayTheme.forDeity(SampleData.bySlug(d.templeSlug ?? '')?.deity?.slug);
    final color = donationStatusColor(d.status);
    final paidAt = DateTime.tryParse(d.paidAt ?? d.createdAt ?? '')?.toLocal();
    return Scaffold(
      appBar: AppBar(
        title: Text(s('hundi_receipt')),
        actions: [if (_busy) const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))) else IconButton(tooltip: s('retry'), onPressed: _reload, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Palette.ivory, borderRadius: BorderRadius.circular(24), border: Border.all(color: d.isPaid ? Palette.tulsi : Palette.gold, width: 3)),
            child: Column(
              children: [
                Text(Brand.name.toUpperCase(), style: const TextStyle(color: Palette.deep, letterSpacing: 3, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(s('hundi_receipt'), style: const TextStyle(color: Palette.teak, fontSize: 13)),
                const SizedBox(height: 10),
                const MotifIcon(Motif.kalasha, size: 30, color: Palette.kumkum),
                const SizedBox(height: 8),
                Text(d.amountLabel, style: const TextStyle(color: Palette.deep, fontFamily: 'NotoSerif', fontSize: 34, fontWeight: FontWeight.w700)),
                if (d.templeName != null) Text(d.templeName!, textAlign: TextAlign.center, style: const TextStyle(color: Palette.teak, fontSize: 14)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withValues(alpha: 0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(donationStatusIcon(d.status), size: 16, color: color), const SizedBox(width: 6), Text(d.statusLabel, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12))]),
                ),
                const SizedBox(height: 14),
                Text(s('hundi_reference').toUpperCase(), style: const TextStyle(color: Palette.teak, letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w700)),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: d.reference));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reference copied.')));
                  },
                  child: Text(d.reference, style: const TextStyle(color: Palette.deep, fontFamily: 'monospace', fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 2)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            d.isPaid ? s('hundi_thanks') : (d.isPending ? s('hundi_pending') : (d.status == 'failed' ? s('hundi_not_paid') : d.statusLabel)),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          _Row(icon: Icons.temple_hindu_rounded, label: s('hundi_temple'), value: [d.templeName, d.templeCity].whereType<String>().join(', '), accent: day.accent),
          if (d.purposeLabel != null) _Row(icon: Icons.volunteer_activism_rounded, label: s('hundi_purpose'), value: d.purposeLabel!, accent: day.accent),
          _Row(icon: Icons.person_rounded, label: s('hundi_from'), value: d.isAnonymous || (d.donorName ?? '').isEmpty ? s('hundi_anonymous_label') : d.donorName!, accent: day.accent),
          if (paidAt != null) _Row(icon: Icons.event_rounded, label: s('event_when'), value: DateFormat('d MMM yyyy, h:mm a').format(paidAt), accent: day.accent),
          if (d.note != null && d.note!.isNotEmpty) _Row(icon: Icons.notes_rounded, label: 'Note', value: d.note!, accent: day.accent),
          if (d.templeSlug != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => enterTemple(context, TempleScreen(slug: d.templeSlug!, preview: SampleData.bySlug(d.templeSlug!)), accent: day.accent),
              icon: const Icon(Icons.temple_hindu_rounded),
              label: Text(d.templeName ?? 'Open the temple'),
            ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, required this.accent});

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

/// "My hundi gifts": every gift given in the app, newest first, each with
/// its receipt.
class MyDonationsScreen extends StatefulWidget {
  const MyDonationsScreen({super.key});

  @override
  State<MyDonationsScreen> createState() => _MyDonationsScreenState();
}

class _MyDonationsScreenState extends State<MyDonationsScreen> {
  List<Donation>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    Analytics.instance.screen('my_hundi');
    _load();
  }

  Future<void> _load() async {
    if (!context.read<AuthController>().isSignedIn) {
      setState(() => _items = const []);
      return;
    }
    try {
      final list = await DonationRepository(context.read<ApiClient>()).mine();
      if (mounted) {
        setState(() {
          _items = list;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = S.of(context)('payment_offline'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: Text(s('my_hundi'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: items == null && _error == null
            ? const DiyaLoader()
            : (items ?? const []).isEmpty
                ? ListView(
                    children: [
                      if (_error != null) Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error))),
                      SizedBox(height: MediaQuery.sizeOf(context).height * 0.6, child: EmptyShrine(motif: Motif.kalasha, message: s('my_hundi_empty'))),
                    ],
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      if (_error != null) const Padding(padding: EdgeInsets.only(bottom: 8), child: OfflineNote()),
                      for (final d in items!) _DonationCard(d: d),
                    ],
                  ),
      ),
    );
  }
}

class _DonationCard extends StatelessWidget {
  const _DonationCard({required this.d});

  final Donation d;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = donationStatusColor(d.status);
    final when = DateTime.tryParse(d.paidAt ?? d.createdAt ?? '')?.toLocal();
    final day = DayTheme.forDeity(SampleData.bySlug(d.templeSlug ?? '')?.deity?.slug);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => DonationReceiptScreen(donation: d))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 50, height: 50, child: TempleCover(slug: d.templeSlug, motifSize: 22))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.templeName ?? d.reference, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif'), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text([d.purposeLabel, if (when != null) DateFormat('d MMM yyyy').format(when)].whereType<String>().join(' · '), style: theme.textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                          child: Text(d.statusLabel, style: theme.textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w700)),
                        ),
                        Text(d.reference, style: theme.textTheme.labelSmall?.copyWith(fontFamily: 'monospace', letterSpacing: 1)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text(d.amountLabel, style: theme.textTheme.labelLarge?.copyWith(color: day.accent, fontWeight: FontWeight.w800)),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
