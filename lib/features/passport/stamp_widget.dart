import 'package:flutter/material.dart';

import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/passport_controller.dart';
import '../../core/theme/day_theme.dart';

/// A circular ink stamp for one temple: serrated ring, ring text with the
/// temple's name, the deity's motif in the centre and the date below.
class StampWidget extends StatelessWidget {
  const StampWidget({super.key, required this.visit, this.size = 132, this.inked = true});

  final Visit visit;
  final double size;
  final bool inked;

  @override
  Widget build(BuildContext context) {
    final day = DayTheme.forDeity(visit.deitySlug);
    final color = inked ? day.accent : Theme.of(context).colorScheme.outline;
    final date = '${visit.visitedAt.day.toString().padLeft(2, '0')}.${visit.visitedAt.month.toString().padLeft(2, '0')}.${visit.visitedAt.year}';
    return Transform.rotate(
      angle: -0.06,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(size: Size.square(size), painter: StampRingPainter(color: color, label: _short(visit.templeName))),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MotifIcon(day.motif, size: size * 0.30, color: color, secondary: color.withValues(alpha: 0.5)),
                SizedBox(height: size * 0.02),
                Text(
                  (visit.city ?? '').toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: size * 0.07, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
                Text(date, style: TextStyle(color: color, fontSize: size * 0.07, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _short(String name) {
    var n = name.split(',').first.trim();
    for (final w in ['Temple', 'Swamy', 'Sri', 'Shree', 'Sree']) {
      n = n.replaceAll(RegExp('\\b$w\\b'), '').trim();
    }
    n = n.replaceAll(RegExp(r'\s+'), ' ');
    return n.length > 22 ? n.substring(0, 22) : n;
  }
}

/// Plays the stamp being pressed into the page: scales down from above and
/// lands with a small bounce.
class StampLanding extends StatefulWidget {
  const StampLanding({super.key, required this.visit, this.size = 180});

  final Visit visit;
  final double size;

  @override
  State<StampLanding> createState() => _StampLandingState();
}

class _StampLandingState extends State<StampLanding> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = Curves.elasticOut.transform(_c.value);
          final scale = 2.2 - 1.2 * t;
          return Opacity(opacity: _c.value.clamp(0.0, 1.0), child: Transform.scale(scale: scale, child: child));
        },
        child: StampWidget(visit: widget.visit, size: widget.size),
      );
}
