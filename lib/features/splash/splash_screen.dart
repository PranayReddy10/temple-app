import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/day_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../shell/shell_screen.dart';

/// The doors of the temple are shut when the app opens. A bell rings (the
/// title fades in on brass), and the doors swing open onto today's deity.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final enabled = context.read<AppSettings>().doorAnimations;
      if (!enabled) {
        _c.value = 1;
        _finish();
        return;
      }
      _c.forward().whenComplete(_finish);
    });
  }

  void _finish() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const ShellScreen(),
      transitionDuration: Duration.zero,
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = context.watch<DayController>().theme;
    final theme = Theme.of(context);
    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          // Hold the doors shut for the first 45% while the title glows,
          // then open over the remaining time.
          final open = ((_c.value - 0.45) / 0.55).clamp(0.0, 1.0);
          final titleOpacity = (_c.value / 0.3).clamp(0.0, 1.0) * (1 - open);
          return Stack(
            fit: StackFit.expand,
            children: [
              TempleDoorReveal(
                progress: open,
                accent: day.accent,
                child: _Sanctum(day: day),
              ),
              IgnorePointer(
                child: Opacity(
                  opacity: titleOpacity,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass),
                          child: const MotifIcon(Motif.om, size: 48, color: Palette.deep),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          Brand.name,
                          style: theme.textTheme.headlineMedium?.copyWith(color: Palette.sandal, fontFamily: 'NotoSerif', letterSpacing: 1),
                        ),
                        const SizedBox(height: 6),
                        Text(Brand.tagline, style: theme.textTheme.bodyMedium?.copyWith(color: Palette.gold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// What lies behind the doors: the day's deity, its motif and mantra.
class _Sanctum extends StatelessWidget {
  const _Sanctum({required this.day});

  final DayTheme day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(alignment: Alignment.bottomCenter, child: GopuramBand(color: day.accent, height: 220, opacity: 0.18, tiers: 7)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MotifIcon(day.motif, size: 120, color: day.accent, secondary: day.secondary),
                const SizedBox(height: 20),
                Text(day.sanskritDay, style: theme.textTheme.labelLarge?.copyWith(color: day.accent, letterSpacing: 3)),
                const SizedBox(height: 4),
                Text(day.deityName, style: theme.textTheme.displaySmall),
                const SizedBox(height: 14),
                Text(day.mantra, style: theme.textTheme.titleLarge),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
