import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/palette.dart';
import '../bookings/bookings_screen.dart';
import '../donations/donate_screen.dart';

/// Where a payment made on the website ended. The gateway's page sends the
/// devotee back to `darshansaathi.com/?payment=<id>`, and the web app opens
/// here: paid, not completed, or still being confirmed by the bank.
class PaymentResultScreen extends StatefulWidget {
  const PaymentResultScreen({super.key, required this.paymentId});

  final String paymentId;

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  Map<String, dynamic>? _payment;
  String? _error;
  Timer? _poll;
  int _tries = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String get _status => '${_payment?['status'] ?? 'pending'}';
  bool get _settled => const {'paid', 'failed', 'refunded'}.contains(_status);

  Future<void> _load() async {
    try {
      final json = await context
          .read<ApiClient>()
          .get('me/payments/${widget.paymentId}');
      if (!mounted) return;
      setState(() {
        _payment = (json['data'] as Map).cast<String, dynamic>();
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _error = e.isNotFound
            ? 'This payment was not found on your account. Sign in with the account you paid from.'
            : e.message);
      }
      return;
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Could not reach the server. Check your connection.');
      }
      return;
    }
    // The bank can take a minute to confirm: ask again for up to two.
    if (!_settled && _tries++ < 40) {
      _poll = Timer(const Duration(seconds: 3), _load);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _payment;
    final purpose = '${p?['purpose'] ?? ''}';
    final (IconData icon, Color color, String title, String body) =
        switch (_status) {
      'paid' => (
          Icons.check_circle_rounded,
          Palette.tulsi,
          'Payment successful',
          switch (purpose) {
            'puja_booking' ||
            'event_ticket' =>
              'Your booking is confirmed. Its code is under My seva bookings; show it at the temple counter.',
            'donation' => 'Your offering has reached the temple. Thank you.',
            _ => 'Thank you. It is active on your account.',
          },
        ),
      'failed' || 'refunded' => (
          Icons.error_rounded,
          Palette.kumkum,
          'Payment not completed',
          '${p?['failure_reason'] ?? 'No money was taken.'} If money did leave your account, it is confirmed or refunded automatically.',
        ),
      _ => (
          Icons.hourglass_top_rounded,
          Palette.gold,
          'Confirming your payment…',
          'This can take a minute while the bank confirms.'
        ),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              if (_error != null) ...[
                const Icon(Icons.cloud_off_rounded,
                    size: 56, color: Palette.kumkum),
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Try again')),
              ] else if (p == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (_settled)
                  Icon(icon, size: 72, color: color)
                else
                  const Center(
                      child: SizedBox.square(
                          dimension: 56, child: CircularProgressIndicator())),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('${p['description'] ?? ''} · ${p['amount'] ?? ''}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 12),
                Text(body,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
                const SizedBox(height: 24),
                if (_status == 'paid' &&
                    (purpose == 'puja_booking' || purpose == 'event_ticket'))
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const BookingsScreen())),
                    icon: const Icon(Icons.confirmation_number_rounded),
                    label: const Text('My seva bookings'),
                  ),
                if (_status == 'paid' && purpose == 'donation')
                  FilledButton.icon(
                    onPressed: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                            builder: (_) => const MyDonationsScreen())),
                    icon: const Icon(Icons.savings_rounded),
                    label: const Text('My hundi offerings'),
                  ),
                const SizedBox(height: 8),
                OutlinedButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: const Text('Done')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
