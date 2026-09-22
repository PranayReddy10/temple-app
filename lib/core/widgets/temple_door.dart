import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../motifs/architecture.dart';
import '../state/app_settings.dart';
import '../theme/palette.dart';

/// Two teak door leaves that swing open to reveal [child].
///
/// [progress] runs 0 (shut) to 1 (fully open). The leaves rotate on their
/// outer hinges with a little perspective, a warm glow leaks through the
/// widening gap first, and the frame is a scalloped torana in the accent.
class TempleDoorReveal extends StatelessWidget {
  const TempleDoorReveal({super.key, required this.progress, required this.child, this.accent = Palette.gold, this.showFrame = true});

  final double progress;
  final Widget child;
  final Color accent;
  final bool showFrame;

  @override
  Widget build(BuildContext context) {
    final t = Curves.easeInOutCubic.transform(progress.clamp(0.0, 1.0));
    final angle = t * math.pi / 2 * 1.05;
    final glow = (1 - t).clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (t < 1) ...[
          // Light spilling through the gap.
          IgnorePointer(
            child: Opacity(
              opacity: glow * 0.9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [accent.withValues(alpha: 0.55), Colors.transparent],
                    radius: 0.35 + t * 0.6,
                  ),
                ),
              ),
            ),
          ),
          _Leaf(angle: angle, left: true, accent: accent),
          _Leaf(angle: angle, left: false, accent: accent),
          if (showFrame)
            IgnorePointer(
              child: Opacity(
                opacity: glow,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: double.infinity,
                    height: 120,
                    child: CustomPaint(painter: ToranaPainter(color: accent, strokeWidth: 4, scallops: 11)),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _Leaf extends StatelessWidget {
  const _Leaf({required this.angle, required this.left, required this.accent});

  final double angle;
  final bool left;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: left ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.5,
        heightFactor: 1,
        child: Transform(
          alignment: left ? Alignment.centerLeft : Alignment.centerRight,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(left ? -angle : angle),
          child: IgnorePointer(
            child: CustomPaint(painter: DoorLeafPainter(hingeOnLeft: left, accent: accent)),
          ),
        ),
      ),
    );
  }
}

/// A page route whose entrance is a temple door opening onto the new page.
///
/// Used everywhere a devotee "enters" something: a temple profile, a deity's
/// day, the passport. The reverse transition closes the doors again.
class TempleDoorRoute<T> extends PageRoute<T> {
  TempleDoorRoute({required this.builder, this.accent = Palette.gold, super.settings, this.enabled = true});

  final WidgetBuilder builder;
  final Color accent;
  final bool enabled;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => true;

  @override
  Duration get transitionDuration => enabled ? const Duration(milliseconds: 900) : const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration => enabled ? const Duration(milliseconds: 600) : const Duration(milliseconds: 200);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) => builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    if (!enabled) return FadeTransition(opacity: animation, child: child);
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => TempleDoorReveal(progress: animation.value, accent: accent, child: child),
    );
  }
}

/// Pushes [page] behind opening temple doors, honouring the user's
/// animation preference.
Future<T?> enterTemple<T>(BuildContext context, Widget page, {Color? accent}) {
  final enabled = context.read<AppSettings>().doorAnimations;
  final color = accent ?? Theme.of(context).colorScheme.primary;
  return Navigator.of(context).push<T>(TempleDoorRoute<T>(builder: (_) => page, accent: color, enabled: enabled));
}
