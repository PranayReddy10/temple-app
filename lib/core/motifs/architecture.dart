import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/palette.dart';

/// A tiered gopuram silhouette, drawn as a skyline along the bottom of its box.
class GopuramPainter extends CustomPainter {
  const GopuramPainter({required this.color, this.tiers = 5, this.opacity = 1});

  final Color color;
  final int tiers;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: opacity);
    final w = size.width;
    final h = size.height;
    final path = Path()..moveTo(0, h);
    // Left wall.
    path.lineTo(0, h * 0.55);
    path.lineTo(w * 0.18, h * 0.55);
    // Central tower.
    final baseW = w * 0.64;
    final left = (w - baseW) / 2;
    var y = h * 0.55;
    var currentLeft = left;
    var currentRight = left + baseW;
    final tierH = (h * 0.55 - h * 0.08) / tiers;
    for (var i = 0; i < tiers; i++) {
      final inset = baseW * 0.07;
      path.lineTo(currentLeft, y);
      path.lineTo(currentLeft, y - tierH * 0.8);
      path.lineTo(currentLeft + inset, y - tierH * 0.8);
      path.lineTo(currentLeft + inset, y - tierH);
      currentLeft += inset;
      y -= tierH;
      // Store right side for later by drawing symmetric later.
      currentRight -= inset;
    }
    // Kalasha crown.
    final cx = w / 2;
    path.lineTo(cx - w * 0.06, y);
    path.lineTo(cx - w * 0.06, y - h * 0.03);
    path.lineTo(cx - w * 0.02, y - h * 0.03);
    path.lineTo(cx, y - h * 0.08);
    path.lineTo(cx + w * 0.02, y - h * 0.03);
    path.lineTo(cx + w * 0.06, y - h * 0.03);
    path.lineTo(cx + w * 0.06, y);
    // Right side, mirrored.
    var rLeft = currentRight;
    var ry = y;
    for (var i = 0; i < tiers; i++) {
      final inset = baseW * 0.07;
      path.lineTo(rLeft, ry);
      path.lineTo(rLeft, ry + tierH * 0.2);
      path.lineTo(rLeft + inset, ry + tierH * 0.2);
      path.lineTo(rLeft + inset, ry + tierH);
      rLeft += inset;
      ry += tierH;
    }
    path.lineTo(w * 0.82, h * 0.55);
    path.lineTo(w, h * 0.55);
    path.lineTo(w, h);
    path.close();
    canvas.drawPath(path, paint);

    // Small shrine niches along the wall.
    final niche = Paint()..color = Colors.black.withValues(alpha: 0.12 * opacity);
    for (var i = 0; i < 4; i++) {
      final nx = w * 0.03 + i * w * 0.04;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(nx, h * 0.68, w * 0.02, h * 0.16), Radius.circular(w * 0.01)), niche);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w - nx - w * 0.02, h * 0.68, w * 0.02, h * 0.16), Radius.circular(w * 0.01)), niche);
    }
  }

  @override
  bool shouldRepaint(GopuramPainter old) => old.color != color || old.tiers != tiers || old.opacity != opacity;
}

/// A kolam / rangoli lattice of dots and loops, used as a section divider.
class KolamPainter extends CustomPainter {
  const KolamPainter({required this.color, this.dense = false});

  final Color color;
  final bool dense;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    final dot = Paint()..color = color;
    final step = dense ? 16.0 : 24.0;
    final cy = size.height / 2;
    final n = (size.width / step).floor();
    final startX = (size.width - n * step) / 2 + step / 2;
    for (var i = 0; i < n; i++) {
      final x = startX + i * step;
      canvas.drawCircle(Offset(x, cy), 1.6, dot);
      final r = step * 0.42;
      final path = Path()
        ..moveTo(x - r, cy)
        ..quadraticBezierTo(x - r, cy - r, x, cy - r)
        ..quadraticBezierTo(x + r, cy - r, x + r, cy)
        ..quadraticBezierTo(x + r, cy + r, x, cy + r)
        ..quadraticBezierTo(x - r, cy + r, x - r, cy);
      canvas.drawPath(path, stroke);
      if (i < n - 1) {
        canvas.drawLine(Offset(x + r, cy), Offset(x + step - r, cy), stroke);
      }
    }
  }

  @override
  bool shouldRepaint(KolamPainter old) => old.color != color || old.dense != dense;
}

/// A scalloped torana arch, the sort that frames a sanctum doorway.
class ToranaPainter extends CustomPainter {
  const ToranaPainter({required this.color, this.strokeWidth = 3, this.scallops = 9});

  final Color color;
  final double strokeWidth;
  final int scallops;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final w = size.width;
    final h = size.height;
    final path = Path()..moveTo(0, h);
    path.lineTo(0, h * 0.45);
    // Arch as a series of scallops along a semi-ellipse.
    final arcW = w;
    final arcH = h * 0.45;
    for (var i = 0; i <= scallops; i++) {
      final t0 = i / scallops;
      final a0 = math.pi + t0 * math.pi;
      final p = Offset(arcW / 2 + math.cos(a0) * arcW / 2, arcH + math.sin(a0) * arcH);
      if (i == 0) {
        path.lineTo(p.dx, p.dy);
      } else {
        final t1 = (i - 0.5) / scallops;
        final a1 = math.pi + t1 * math.pi;
        final ctrl = Offset(arcW / 2 + math.cos(a1) * arcW / 2 * 1.02, arcH + math.sin(a1) * arcH * 1.35);
        path.quadraticBezierTo(ctrl.dx, ctrl.dy, p.dx, p.dy);
      }
    }
    path.lineTo(w, h);
    canvas.drawPath(path, paint);
    // Hanging bells at the ends.
    final bell = Paint()..color = color;
    canvas.drawCircle(Offset(w * 0.5, h * 0.04 + strokeWidth), strokeWidth * 1.2, bell);
  }

  @override
  bool shouldRepaint(ToranaPainter old) => old.color != color || old.strokeWidth != strokeWidth;
}

/// A subtle carved-stone texture: repeating lotus-diamond lattice.
class LatticePainter extends CustomPainter {
  const LatticePainter({required this.color, this.cell = 28});

  final Color color;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (var y = 0.0; y < size.height + cell; y += cell) {
      for (var x = 0.0; x < size.width + cell; x += cell) {
        final path = Path()
          ..moveTo(x, y - cell / 2)
          ..lineTo(x + cell / 2, y)
          ..lineTo(x, y + cell / 2)
          ..lineTo(x - cell / 2, y)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawCircle(Offset(x, y), 1.2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(LatticePainter old) => old.color != color || old.cell != cell;
}

/// One leaf of a temple door: teak planks, brass studs, a central strap
/// and a lion-face knocker. `hinge` decides which edge carries the hinges.
class DoorLeafPainter extends CustomPainter {
  const DoorLeafPainter({required this.hingeOnLeft, this.accent = Palette.gold});

  final bool hingeOnLeft;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = Palette.teakWood.createShader(rect));

    // Plank seams.
    final seam = Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..strokeWidth = 1.5;
    final planks = 4;
    for (var i = 1; i < planks; i++) {
      final x = size.width * i / planks;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), seam);
    }
    // Grain.
    final grain = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    final rnd = math.Random(hingeOnLeft ? 3 : 7);
    for (var i = 0; i < 40; i++) {
      final x = rnd.nextDouble() * size.width;
      final y0 = rnd.nextDouble() * size.height;
      canvas.drawLine(Offset(x, y0), Offset(x + rnd.nextDouble() * 6 - 3, y0 + 40 + rnd.nextDouble() * 80), grain);
    }

    // Horizontal brass straps.
    final strapPaint = Paint()..shader = Palette.brass.createShader(rect);
    final strapH = math.max(10.0, size.height * 0.018);
    for (final f in [0.12, 0.38, 0.62, 0.88]) {
      final y = size.height * f;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, y - strapH / 2, size.width, strapH), Radius.circular(strapH / 3)),
        strapPaint,
      );
      // Studs along the strap.
      final studs = math.max(3, (size.width / 34).floor());
      for (var i = 0; i < studs; i++) {
        final x = size.width * (i + 0.5) / studs;
        canvas.drawCircle(Offset(x, y), strapH * 0.65, Paint()..color = const Color(0xFF5A4409));
        canvas.drawCircle(Offset(x - 1, y - 1), strapH * 0.45, Paint()..color = const Color(0xFFF7E29C));
      }
    }

    // Carved panels between the straps.
    final carve = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final f in [0.20, 0.46, 0.70]) {
      final r = Rect.fromLTWH(size.width * 0.18, size.height * f, size.width * 0.64, size.height * 0.12);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), carve);
      // Lotus bud inside.
      final c = r.center;
      final bud = Path()
        ..moveTo(c.dx, c.dy - r.height * 0.32)
        ..quadraticBezierTo(c.dx + r.height * 0.28, c.dy, c.dx, c.dy + r.height * 0.32)
        ..quadraticBezierTo(c.dx - r.height * 0.28, c.dy, c.dx, c.dy - r.height * 0.32);
      canvas.drawPath(bud, Paint()..color = accent.withValues(alpha: 0.55));
    }

    // Knocker ring on the free edge.
    final knockerX = hingeOnLeft ? size.width * 0.86 : size.width * 0.14;
    final knockerY = size.height * 0.50;
    canvas.drawCircle(Offset(knockerX, knockerY), size.width * 0.06, Paint()..color = const Color(0xFF6B5210));
    canvas.drawCircle(Offset(knockerX, knockerY), size.width * 0.06, Paint()
      ..shader = Palette.brass.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.025);
    canvas.drawCircle(Offset(knockerX, knockerY + size.width * 0.075), size.width * 0.035, Paint()..shader = Palette.brass.createShader(rect));

    // Hinges on the hinge edge.
    final hingeX = hingeOnLeft ? 0.0 : size.width - 8;
    for (final f in [0.12, 0.62]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(hingeX, size.height * f - 22, 8, 44), const Radius.circular(3)),
        Paint()..color = const Color(0xFF2B2007),
      );
    }

    // Edge shadow toward the middle seam for depth.
    final shadowRect = hingeOnLeft
        ? Rect.fromLTWH(size.width - 14, 0, 14, size.height)
        : Rect.fromLTWH(0, 0, 14, size.height);
    canvas.drawRect(
      shadowRect,
      Paint()
        ..shader = LinearGradient(
          begin: hingeOnLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: hingeOnLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.45)],
        ).createShader(shadowRect),
    );
  }

  @override
  bool shouldRepaint(DoorLeafPainter old) => old.hingeOnLeft != hingeOnLeft || old.accent != accent;
}

/// A circular passport stamp with serrated edge, ring text and a motif hole.
class StampRingPainter extends CustomPainter {
  const StampRingPainter({required this.color, required this.label, this.teeth = 36});

  final Color color;
  final String label;
  final int teeth;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    final path = Path();
    for (var i = 0; i < teeth * 2; i++) {
      final a = i * math.pi / teeth;
      final rr = i.isEven ? r : r * 0.94;
      final p = c + Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(path, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2);
    canvas.drawCircle(c, r * 0.80, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
    canvas.drawCircle(c, r * 0.56, Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);

    // Ring text along the top arc.
    final text = label.toUpperCase();
    final style = TextStyle(color: color, fontSize: r * 0.16, fontWeight: FontWeight.w700, letterSpacing: 1.5);
    final totalAngle = math.pi * 1.2;
    var angle = -math.pi / 2 - totalAngle / 2;
    for (var i = 0; i < text.length; i++) {
      final tp = TextPainter(text: TextSpan(text: text[i], style: style), textDirection: TextDirection.ltr)..layout();
      final step = totalAngle / math.max(1, text.length - 1);
      canvas.save();
      final pos = c + Offset(math.cos(angle), math.sin(angle)) * r * 0.68;
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle + math.pi / 2);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
      angle += step;
    }
  }

  @override
  bool shouldRepaint(StampRingPainter old) => old.color != color || old.label != label;
}
