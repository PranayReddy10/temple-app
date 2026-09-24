import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/app_settings.dart';
import '../../core/state/day_controller.dart';
import '../../core/state/mantra_player.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../shell/shell_screen.dart';

/// The welcome. The temple doors are shut; a brass ghanta hangs between
/// them, swings and rings twice, and the doors open onto today's deity as
/// marigold petals fall. A tap anywhere skips it.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 3600);

  /// Where in the timeline the doors start and finish opening.
  static const _openFrom = 0.42;

  late final AnimationController _c = AnimationController(vsync: this, duration: _duration);
  ap.AudioPlayer? _bell;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<AppSettings>();
      if (!settings.doorAnimations) {
        _c.value = 1;
        _finish();
        return;
      }
      if (settings.templeSounds && !context.read<MantraPlayer>().muted) _ring();
      _c.forward().whenComplete(_finish);
    });
  }

  Future<void> _ring() async {
    try {
      _bell = ap.AudioPlayer();
      await _bell!.setReleaseMode(ap.ReleaseMode.release);
      await _bell!.play(ap.AssetSource('sounds/temple_bell.wav'), volume: 0.9);
    } catch (_) {
      // No audio device, or a platform without the plugin: the welcome is
      // just as good silent.
    }
  }

  void _finish() {
    if (!mounted || _finished) return;
    _finished = true;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => const ShellScreen(),
      transitionDuration: const Duration(milliseconds: 350),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    // Let the bell ring out over the home screen rather than cutting it.
    final bell = _bell;
    if (bell != null) Future.delayed(const Duration(seconds: 4), bell.dispose);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final day = context.watch<DayController>().theme;
    final theme = Theme.of(context);
    return Scaffold(
      // Same teak as the native launch window, so there is no flash between.
      backgroundColor: Palette.deep,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          _c.stop();
          _finish();
        },
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final v = _c.value;
            final open = ((v - _openFrom) / (1 - _openFrom)).clamp(0.0, 1.0);
            final titleIn = (v / 0.18).clamp(0.0, 1.0);
            // Gone before the gap is wide enough to show the deity's name.
            final titleOpacity = titleIn * (1 - (open * 6).clamp(0.0, 1.0));
            // The bell swings from each strike and settles; it rises away
            // as the doors part.
            final sinceStrike = v < 0.26 ? v : v - 0.26;
            final swing = math.sin(sinceStrike * 34) * math.exp(-sinceStrike * 7) * 0.32;
            final bellOpacity = 1 - (open * 1.8).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                TempleDoorReveal(
                  progress: open,
                  accent: day.accent,
                  child: _Sanctum(day: day, arrived: open),
                ),
                // Petals, once the doors begin to part.
                if (open > 0) IgnorePointer(child: CustomPaint(painter: _PetalsPainter(progress: open))),
                // The ghanta, hanging from the lintel.
                if (bellOpacity > 0)
                  IgnorePointer(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: bellOpacity,
                        child: Transform.rotate(
                          angle: swing,
                          alignment: Alignment.topCenter,
                          child: SizedBox(width: 90, height: 240, child: CustomPaint(painter: _GhantaPainter(glow: (1 - sinceStrike * 5).clamp(0.0, 1.0)))),
                        ),
                      ),
                    ),
                  ),
                IgnorePointer(
                  child: Opacity(
                    opacity: titleOpacity,
                    child: Align(
                      alignment: const Alignment(0, 0.35),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.translate(
                              offset: Offset(0, 12 * (1 - titleIn)),
                              child: Text('स्वागतम्', style: theme.textTheme.displaySmall?.copyWith(color: Palette.gold, fontFamily: 'NotoSansDevanagari', shadows: const [Shadow(color: Colors.black54, blurRadius: 8)])),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              Brand.name,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(color: Palette.sandal, fontFamily: 'NotoSerif', letterSpacing: 1, shadows: const [Shadow(color: Colors.black54, blurRadius: 6)]),
                            ),
                            const SizedBox(height: 6),
                            Text(Brand.tagline, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium?.copyWith(color: Palette.gold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A brass temple bell on its chain, lit from the strike.
class _GhantaPainter extends CustomPainter {
  const _GhantaPainter({required this.glow});

  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final chain = Paint()
      ..color = Palette.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    // Chain links down from the lintel.
    for (var y = 0.0; y < size.height * 0.52; y += 12) {
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, y + 6), width: y ~/ 12 % 2 == 0 ? 7 : 4, height: 11), chain);
    }
    final top = size.height * 0.52;
    final w = size.width * 0.78;
    final h = size.height * 0.36;
    // Crown knob.
    canvas.drawCircle(Offset(cx, top + 4), 7, Paint()..shader = Palette.brass.createShader(Rect.fromCircle(center: Offset(cx, top + 4), radius: 7)));
    // Body: a flared bell.
    final body = Path()
      ..moveTo(cx - w * 0.22, top + 10)
      ..quadraticBezierTo(cx - w * 0.30, top + h * 0.55, cx - w * 0.5, top + h * 0.92)
      ..lineTo(cx + w * 0.5, top + h * 0.92)
      ..quadraticBezierTo(cx + w * 0.30, top + h * 0.55, cx + w * 0.22, top + 10)
      ..quadraticBezierTo(cx, top + 2, cx - w * 0.22, top + 10)
      ..close();
    final rect = Rect.fromLTWH(cx - w / 2, top, w, h);
    if (glow > 0) {
      canvas.drawCircle(Offset(cx, top + h * 0.6), w * (0.7 + glow * 0.4), Paint()
        ..color = Palette.turmeric.withValues(alpha: 0.35 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    }
    canvas.drawPath(body, Paint()..shader = const LinearGradient(colors: [Color(0xFF8A6A1F), Color(0xFFF2D16B), Color(0xFFC9A227), Color(0xFF7A5A14)], stops: [0, 0.35, 0.6, 1]).createShader(rect));
    // Rim and bands.
    final band = Paint()
      ..color = const Color(0xFF6B4E12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawLine(Offset(cx - w * 0.5, top + h * 0.92), Offset(cx + w * 0.5, top + h * 0.92), band..strokeWidth = 4);
    canvas.drawLine(Offset(cx - w * 0.33, top + h * 0.62), Offset(cx + w * 0.33, top + h * 0.62), band..strokeWidth = 1.5);
    canvas.drawLine(Offset(cx - w * 0.25, top + h * 0.3), Offset(cx + w * 0.25, top + h * 0.3), band);
    // Clapper.
    canvas.drawLine(Offset(cx, top + h * 0.5), Offset(cx, top + h * 1.05), Paint()
      ..color = const Color(0xFF6B4E12)
      ..strokeWidth = 2.5);
    canvas.drawCircle(Offset(cx, top + h * 1.08), 6, Paint()..color = const Color(0xFF8A6A1F));
  }

  @override
  bool shouldRepaint(_GhantaPainter old) => old.glow != glow;
}

/// Marigold and rose petals drifting down over the opened doors.
class _PetalsPainter extends CustomPainter {
  const _PetalsPainter({required this.progress});

  final double progress;

  static const _colors = [Color(0xFFF2A516), Color(0xFFE8751A), Color(0xFFF7C948), Color(0xFFC2185B), Color(0xFFFF9800)];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    for (var k = 0; k < 36; k++) {
      final x0 = rnd.nextDouble() * size.width;
      final delay = rnd.nextDouble() * 0.45;
      final speed = 0.8 + rnd.nextDouble() * 0.7;
      final drift = (rnd.nextDouble() - 0.5) * 60;
      final spin = rnd.nextDouble() * math.pi * 2;
      final color = _colors[k % _colors.length];
      final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (t <= 0) continue;
      final y = -20 + t * speed * (size.height + 40);
      final x = x0 + math.sin(t * math.pi * 3 + k) * 18 + drift * t;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(spin + t * math.pi * 2.5);
      canvas.drawOval(const Rect.fromLTWH(-6, -3.5, 12, 7), Paint()..color = color.withValues(alpha: 0.9 * (1 - t * 0.4)));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PetalsPainter old) => old.progress != progress;
}

/// What lies behind the doors: the day's deity, its motif and mantra.
class _Sanctum extends StatelessWidget {
  const _Sanctum({required this.day, this.arrived = 1});

  final DayTheme day;

  /// How far the doors have opened, for easing the deity into view.
  final double arrived;

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
                Transform.scale(scale: 0.85 + 0.15 * arrived, child: MotifIcon(day.motif, size: 120, color: day.accent, secondary: day.secondary)),
                const SizedBox(height: 20),
                Text(day.sanskritDay, style: theme.textTheme.labelLarge?.copyWith(color: day.accent, letterSpacing: 3)),
                const SizedBox(height: 4),
                Text(day.deityName, style: theme.textTheme.displaySmall),
                const SizedBox(height: 14),
                Text(day.mantra, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
                const SizedBox(height: 18),
                Text('Welcome to the temple', style: theme.textTheme.bodyMedium?.copyWith(color: day.accent, letterSpacing: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
