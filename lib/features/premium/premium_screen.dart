import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/app_config_controller.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/subscription_controller.dart';
import '../../core/theme/palette.dart';
import '../auth/auth_screen.dart';
import '../../core/payments/native_checkout.dart';

/// Premium plans: what each includes, the one held now, and buying one
/// through the payment gateways set in the admin panel.
class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  String? _buying;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionController>().loadPlans();
      context.read<AuthController>().reload();
    });
  }

  Future<void> _buy(SubscriptionPlan plan) async {
    final s = S.of(context);
    final auth = context.read<AuthController>();
    final config = context.read<AppConfigController>().config;
    final subs = context.read<SubscriptionController>();
    final messenger = ScaffoldMessenger.of(context);
    if (!auth.isSignedIn) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
      if (!mounted || !auth.isSignedIn) return;
    }
    String? gateway = config.defaultGateway;
    if (config.gateways.length > 1) {
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
      if (gateway == null) return;
    }
    setState(() => _buying = plan.code);
    try {
      final start = await subs.begin(plan, gateway: gateway);
      if (!mounted) return;
      String status;
      if (NativeCheckout.supports(start.sdk)) {
        // The gateway's own payment sheet: UPI apps, cards, banks, in-app.
        final result = await NativeCheckout.pay(start.sdk!);
        if (!result.completed) {
          messenger.showSnackBar(SnackBar(content: Text(s('payment_cancelled'))));
          return;
        }
        status = await subs.confirm(start.paymentId, result.fields);
        if (status == 'pending') status = await subs.settle(start.paymentId);
      } else {
        // No SDK for this gateway (or the web build): its page in the
        // system browser tab, then ask the server once the devotee is back.
        await NativeCheckout.payInBrowserTab(start.checkoutUrl);
        status = await subs.settle(start.paymentId, attempts: 10);
      }
      messenger.showSnackBar(SnackBar(content: Text(switch (status) { 'paid' => s('premium_active'), 'pending' => s('payment_pending'), _ => s('payment_failed') })));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(s('payment_offline'))));
    } finally {
      if (mounted) setState(() => _buying = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final subs = context.watch<SubscriptionController>();
    final config = context.watch<AppConfigController>().config;
    final d = context.watch<AuthController>().devotee;
    final ends = DateTime.tryParse(d?.subscriptionEndsAt ?? '')?.toLocal();

    return Scaffold(
      appBar: AppBar(title: Text(s('premium'))),
      body: RefreshIndicator(
        onRefresh: subs.loadPlans,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2B1B16), Color(0xFF6E1423)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                  const Positioned.fill(child: Opacity(opacity: 0.08, child: CustomPaint(painter: LatticePainter(color: Palette.gold, cell: 26)))),
                  Row(
                    children: [
                      Container(width: 56, height: 56, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass), child: const Center(child: MotifIcon(Motif.kalasha, size: 32, color: Palette.deep))),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d?.subscriptionPlan ?? s('premium_title'), style: theme.textTheme.titleLarge?.copyWith(color: Palette.sandal, fontFamily: 'NotoSerif')),
                            const SizedBox(height: 4),
                            Text(
                              ends != null ? '${s('premium_until')} ${ends.day}/${ends.month}/${ends.year}' : s('premium_pitch'),
                              style: theme.textTheme.bodySmall?.copyWith(color: Palette.gold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (subs.loading && subs.plans.isEmpty) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            if (!subs.loading && subs.plans.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(subs.error == null ? s('premium_none') : s('payment_offline'), textAlign: TextAlign.center)),
            for (final plan in subs.plans) ...[
              _PlanCard(
                plan: plan,
                busy: _buying == plan.code,
                canBuy: config.paymentsEnabled,
                onBuy: _buying == null ? () => _buy(plan) : null,
              ),
              const SizedBox(height: 14),
            ],
            if (!config.paymentsEnabled && subs.plans.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16)),
                child: Text(config.paymentsElsewhere ? s('premium_elsewhere') : s('premium_soon'), style: theme.textTheme.bodySmall),
              ),
            const SizedBox(height: 12),
            Text(s('premium_note'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, required this.busy, required this.canBuy, this.onBuy});

  final SubscriptionPlan plan;
  final bool busy;
  final bool canBuy;
  final VoidCallback? onBuy;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: plan.badge != null ? Palette.gold : theme.colorScheme.outlineVariant, width: plan.badge != null ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(plan.name, style: theme.textTheme.titleLarge?.copyWith(fontFamily: 'NotoSerif'))),
              if (plan.badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(gradient: Palette.brass, borderRadius: BorderRadius.circular(999)),
                  child: Text(plan.badge!, style: const TextStyle(color: Palette.deep, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: plan.price, style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
            if (plan.period != null) TextSpan(text: '  ${plan.period}', style: theme.textTheme.bodyMedium),
          ])),
          if (plan.description != null) ...[const SizedBox(height: 6), Text(plan.description!, style: theme.textTheme.bodyMedium)],
          const SizedBox(height: 10),
          for (final line in plan.benefitLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [const Icon(Icons.check_circle_rounded, size: 18, color: Palette.tulsi), const SizedBox(width: 8), Expanded(child: Text(line))]),
            ),
          if (canBuy) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onBuy,
                child: busy ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text('${s('premium_buy')} · ${plan.price}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
