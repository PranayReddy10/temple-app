import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/platform.dart';
import '../../core/state/app_config_controller.dart';
import '../../core/theme/palette.dart';

/// Sits above every screen and applies what the admin panel decided:
/// maintenance covers the app, a version below the minimum must update, and
/// a newer version is offered once in a popup that can be dismissed.
class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  bool _offered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app is when maintenance ends or an update lands.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<AppConfigController>().load();
  }

  void _maybeOffer(AppConfigController c) {
    if (_offered || !c.shouldOfferUpdate) return;
    _offered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      final s = S.of(ctx);
      showDialog<void>(
        context: ctx,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.system_update_rounded),
          title: Text(c.config.updateTitle ?? s('update_title')),
          content: Text([
            if (c.config.latestVersion != null) '${s('version')} ${c.config.latestVersion}',
            c.config.updateMessage ?? s('update_body'),
          ].join('\n\n')),
          actions: [
            TextButton(
              onPressed: () {
                c.dismissUpdate();
                Navigator.of(context).pop();
              },
              child: Text(s('later')),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _openStore(c.config);
              },
              child: Text(s('update_now')),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<AppConfigController>();
    _maybeOffer(c);
    final cfg = c.config;
    if (cfg.maintenance) return _Blocker(config: cfg, maintenance: true, onRetry: c.load);
    if (cfg.updateRequired) return _Blocker(config: cfg, maintenance: false, onRetry: c.load);
    return widget.child;
  }
}

Future<void> _openStore(AppConfig c) async {
  final url = c.storeUrl;
  if (url == null || url.isEmpty) return;
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Full-screen maintenance notice, or the "please update" wall.
class _Blocker extends StatefulWidget {
  const _Blocker({required this.config, required this.maintenance, required this.onRetry});

  final AppConfig config;
  final bool maintenance;
  final Future<void> Function() onRetry;

  @override
  State<_Blocker> createState() => _BlockerState();
}

class _BlockerState extends State<_Blocker> {
  bool _checking = false;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final c = widget.config;
    final until = DateTime.tryParse(c.maintenanceUntil ?? '')?.toLocal();
    final title = widget.maintenance ? (c.maintenanceTitle ?? s('maintenance_title')) : (c.updateTitle ?? s('update_required_title'));
    final body = widget.maintenance ? (c.maintenanceMessage ?? s('maintenance_body')) : (c.updateMessage ?? s('update_required_body'));
    return Scaffold(
      backgroundColor: Palette.deep,
      body: Stack(
        children: [
          const Positioned.fill(child: Opacity(opacity: 0.07, child: CustomPaint(painter: LatticePainter(color: Palette.gold, cell: 30)))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass),
                      child: MotifIcon(widget.maintenance ? Motif.diya : Motif.kalasha, size: 56, color: Palette.deep),
                    ),
                    const SizedBox(height: 24),
                    Text(title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(color: Palette.sandal, fontFamily: 'NotoSerif')),
                    const SizedBox(height: 12),
                    Text(body, textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(color: Palette.sandal.withValues(alpha: 0.85), height: 1.5)),
                    if (widget.maintenance && until != null) ...[
                      const SizedBox(height: 12),
                      Text('${s('maintenance_until')} ${until.day}/${until.month} ${until.hour.toString().padLeft(2, '0')}:${until.minute.toString().padLeft(2, '0')}', style: theme.textTheme.bodyMedium?.copyWith(color: Palette.gold)),
                    ],
                    const SizedBox(height: 28),
                    if (!widget.maintenance && (c.storeUrl ?? '').isNotEmpty)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: Palette.gold, foregroundColor: Palette.deep),
                        onPressed: () => _openStore(c),
                        icon: const Icon(Icons.system_update_rounded),
                        label: Text(s('update_now')),
                      ),
                    const SizedBox(height: 8),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Palette.gold),
                      onPressed: _checking
                          ? null
                          : () async {
                              setState(() => _checking = true);
                              await widget.onRetry();
                              if (mounted) setState(() => _checking = false);
                            },
                      child: _checking ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.gold)) : Text(s('retry')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
