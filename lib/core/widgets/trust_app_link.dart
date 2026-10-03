import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../theme/palette.dart';

/// Sends a temple's own people to the Trust app, where they register the
/// temple and run its listing, sevas and bookings themselves.
Future<void> openTrustApp() => launchUrl(Uri.parse(Brand.trustAppUrl), mode: LaunchMode.externalApplication);

/// "Temple not here? Are you from its trust?" with the way to the Trust app.
class TrustAppCard extends StatelessWidget {
  const TrustAppCard({super.key, this.compact = false});

  /// A button only, for an empty search.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return OutlinedButton.icon(
        onPressed: openTrustApp,
        icon: const Icon(Icons.temple_hindu_rounded),
        label: const Text('From the temple? Get the ${Brand.trustAppName} app'),
      );
    }
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: Palette.gold.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Palette.gold.withValues(alpha: 0.5))),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: openTrustApp,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.temple_hindu_rounded, color: Palette.kumkum, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Are you from the temple\'s trust or committee?', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Register the temple in the ${Brand.trustAppName} app and manage its timings, sevas, bookings and hundi yourselves.',
                  style: theme.textTheme.bodySmall,
                ),
              ]),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.open_in_new_rounded, size: 20),
          ]),
        ),
      ),
    );
  }
}
