import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Symbols drawn by hand rather than shipped as images: they scale to any
/// size, tint to any day's colour and weigh nothing on a patchy network.
enum Motif { sun, trishul, gada, peacock, shankhaChakra, lotus, namam, om, diya, bell, kalasha }

class MotifIcon extends StatelessWidget {
  const MotifIcon(this.motif, {super.key, this.size = 48, this.color, this.secondary});

  final Motif motif;
  final double size;
  final Color? color;
  final Color? secondary;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: MotifPainter(motif, c, secondary ?? c.withValues(alpha: 0.5))),
    );
  }
}

class MotifPainter extends CustomPainter {
  const MotifPainter(this.motif, this.color, this.secondary);

  final Motif motif;
  final Color color;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    canvas.save();
    canvas.translate((size.width - s) / 2, (size.height - s) / 2);
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    final soft = Paint()..color = secondary;
    switch (motif) {
      case Motif.sun:
        _sun(canvas, s, stroke, fill, soft);
      case Motif.trishul:
        _trishul(canvas, s, stroke, fill, soft);
      case Motif.gada:
        _gada(canvas, s, stroke, fill, soft);
      case Motif.peacock:
        _peacock(canvas, s, stroke, fill, soft);
      case Motif.shankhaChakra:
        _shankhaChakra(canvas, s, stroke, fill, soft);
      case Motif.lotus:
        _lotus(canvas, s, stroke, fill, soft);
      case Motif.namam:
        _namam(canvas, s, stroke, fill, soft);
      case Motif.om:
        _om(canvas, s, fill);
      case Motif.diya:
        _diya(canvas, s, stroke, fill, soft);
      case Motif.bell:
        _bell(canvas, s, stroke, fill, soft);
      case Motif.kalasha:
        _kalasha(canvas, s, stroke, fill, soft);
    }
    canvas.restore();
  }

  void _sun(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    final centre = Offset(s / 2, s / 2);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      final p1 = centre + Offset(math.cos(a), math.sin(a)) * s * 0.30;
      final p2 = centre + Offset(math.cos(a), math.sin(a)) * s * (i.isEven ? 0.46 : 0.40);
      c.drawLine(p1, p2, stroke);
    }
    c.drawCircle(centre, s * 0.22, soft);
    c.drawCircle(centre, s * 0.22, stroke);
    c.drawCircle(centre, s * 0.09, fill);
  }

  void _trishul(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    final cx = s / 2;
    // Crescent moon behind.
    c.drawCircle(Offset(cx + s * 0.02, s * 0.26), s * 0.16, soft);
    c.drawCircle(Offset(cx + s * 0.08, s * 0.22), s * 0.14, Paint()..color = Colors.transparent..blendMode = BlendMode.clear);
    // Shaft.
    c.drawLine(Offset(cx, s * 0.40), Offset(cx, s * 0.95), stroke);
    // Central prong.
    c.drawLine(Offset(cx, s * 0.08), Offset(cx, s * 0.42), stroke);
    // Side prongs as curved paths.
    final left = Path()
      ..moveTo(cx - s * 0.26, s * 0.10)
      ..quadraticBezierTo(cx - s * 0.30, s * 0.42, cx, s * 0.44);
    final right = Path()
      ..moveTo(cx + s * 0.26, s * 0.10)
      ..quadraticBezierTo(cx + s * 0.30, s * 0.42, cx, s * 0.44);
    c.drawPath(left, stroke);
    c.drawPath(right, stroke);
    // Damaru knot.
    c.drawCircle(Offset(cx, s * 0.52), s * 0.05, fill);
  }

  void _gada(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    final cx = s / 2;
    c.drawLine(Offset(cx, s * 0.42), Offset(cx, s * 0.92), stroke);
    c.drawCircle(Offset(cx, s * 0.92), s * 0.05, fill);
    c.drawCircle(Offset(cx, s * 0.30), s * 0.22, soft);
    c.drawCircle(Offset(cx, s * 0.30), s * 0.22, stroke);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final p = Offset(cx, s * 0.30) + Offset(math.cos(a), math.sin(a)) * s * 0.14;
      c.drawCircle(p, s * 0.03, fill);
    }
    c.drawCircle(Offset(cx, s * 0.30), s * 0.05, fill);
  }

  void _peacock(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    final cx = s / 2;
    // Feather stem.
    final stem = Path()
      ..moveTo(cx - s * 0.20, s * 0.92)
      ..quadraticBezierTo(cx, s * 0.55, cx + s * 0.05, s * 0.28);
    c.drawPath(stem, stroke);
    // Eye of the feather.
    final eye = Path()
      ..moveTo(cx + s * 0.05, s * 0.08)
      ..cubicTo(cx + s * 0.32, s * 0.14, cx + s * 0.30, s * 0.42, cx + s * 0.05, s * 0.46)
      ..cubicTo(cx - s * 0.20, s * 0.42, cx - s * 0.22, s * 0.14, cx + s * 0.05, s * 0.08)
      ..close();
    c.drawPath(eye, soft);
    c.drawPath(eye, stroke);
    c.drawOval(Rect.fromCenter(center: Offset(cx + s * 0.05, s * 0.27), width: s * 0.16, height: s * 0.22), fill);
    // Barbs.
    for (var i = 0; i < 6; i++) {
      final t = 0.35 + i * 0.1;
      final p = Offset(cx - s * 0.20 + (s * 0.25) * (t - 0.35) / 0.6 * 1.0, s * 0.92 - (s * 0.64) * (t - 0.35) / 0.6);
      c.drawLine(p, p + Offset(-s * 0.09, -s * 0.02), stroke..strokeWidth = s * 0.03);
      c.drawLine(p, p + Offset(s * 0.09, -s * 0.05), stroke);
    }
    // Flute.
    c.drawLine(Offset(cx - s * 0.40, s * 0.62), Offset(cx + s * 0.06, s * 0.86), stroke..strokeWidth = s * 0.07);
  }

  void _shankhaChakra(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    // Chakra on the right, shankha on the left.
    final chakra = Offset(s * 0.68, s * 0.45);
    c.drawCircle(chakra, s * 0.24, soft);
    c.drawCircle(chakra, s * 0.24, stroke);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      c.drawLine(chakra + Offset(math.cos(a), math.sin(a)) * s * 0.07, chakra + Offset(math.cos(a), math.sin(a)) * s * 0.24, stroke);
    }
    c.drawCircle(chakra, s * 0.07, fill);
    final shankha = Path()
      ..moveTo(s * 0.10, s * 0.80)
      ..cubicTo(s * 0.05, s * 0.45, s * 0.22, s * 0.20, s * 0.34, s * 0.30)
      ..cubicTo(s * 0.44, s * 0.40, s * 0.40, s * 0.60, s * 0.30, s * 0.66)
      ..lineTo(s * 0.32, s * 0.86)
      ..close();
    c.drawPath(shankha, soft);
    c.drawPath(shankha, stroke);
  }

  void _lotus(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    final base = Offset(s / 2, s * 0.82);
    Path petal(double angle, double len, double width) {
      final tip = base + Offset(math.sin(angle), -math.cos(angle)) * len;
      final side = Offset(math.cos(angle), math.sin(angle)) * width;
      return Path()
        ..moveTo(base.dx, base.dy)
        ..quadraticBezierTo(base.dx + side.dx * 0.9 + (tip.dx - base.dx) * 0.5, base.dy + side.dy * 0.9 + (tip.dy - base.dy) * 0.5, tip.dx, tip.dy)
        ..quadraticBezierTo(base.dx - side.dx * 0.9 + (tip.dx - base.dx) * 0.5, base.dy - side.dy * 0.9 + (tip.dy - base.dy) * 0.5, base.dx, base.dy)
        ..close();
    }

    for (final a in [-1.1, 1.1, -0.7, 0.7]) {
      c.drawPath(petal(a, s * 0.55, s * 0.16), soft);
      c.drawPath(petal(a, s * 0.55, s * 0.16), stroke);
    }
    for (final a in [-0.35, 0.35, 0.0]) {
      c.drawPath(petal(a, s * 0.70, s * 0.15), fill);
    }
    c.drawArc(Rect.fromCenter(center: base, width: s * 0.7, height: s * 0.26), 0, math.pi, false, stroke);
  }

  void _namam(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    // The Vaishnava tilak: a white U with a red central line.
    final u = Path()
      ..moveTo(s * 0.28, s * 0.12)
      ..lineTo(s * 0.28, s * 0.62)
      ..quadraticBezierTo(s * 0.28, s * 0.90, s * 0.50, s * 0.90)
      ..quadraticBezierTo(s * 0.72, s * 0.90, s * 0.72, s * 0.62)
      ..lineTo(s * 0.72, s * 0.12);
    c.drawPath(u, stroke..strokeWidth = s * 0.11);
    c.drawLine(Offset(s * 0.50, s * 0.14), Offset(s * 0.50, s * 0.72), Paint()
      ..color = secondary
      ..strokeWidth = s * 0.09
      ..strokeCap = StrokeCap.round);
  }

  void _om(Canvas c, double s, Paint fill) {
    final tp = TextPainter(
      text: TextSpan(text: 'ॐ', style: TextStyle(fontSize: s * 0.82, color: color, height: 1, fontFamily: 'NotoSansDevanagari', fontFamilyFallback: const ['NotoSerif', 'NotoSans'])),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, Offset((s - tp.width) / 2, (s - tp.height) / 2));
  }

  void _diya(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    final bowl = Path()
      ..moveTo(s * 0.12, s * 0.60)
      ..quadraticBezierTo(s * 0.50, s * 0.98, s * 0.88, s * 0.60)
      ..close();
    c.drawPath(bowl, fill);
    c.drawLine(Offset(s * 0.12, s * 0.60), Offset(s * 0.88, s * 0.60), stroke);
    final flame = Path()
      ..moveTo(s * 0.50, s * 0.12)
      ..quadraticBezierTo(s * 0.70, s * 0.36, s * 0.50, s * 0.56)
      ..quadraticBezierTo(s * 0.30, s * 0.36, s * 0.50, s * 0.12)
      ..close();
    c.drawPath(flame, soft);
    c.drawPath(flame.shift(Offset.zero), Paint()
      ..color = secondary.withValues(alpha: 0.9)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.06));
  }

  void _bell(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    final body = Path()
      ..moveTo(s * 0.22, s * 0.70)
      ..lineTo(s * 0.22, s * 0.45)
      ..quadraticBezierTo(s * 0.22, s * 0.16, s * 0.50, s * 0.16)
      ..quadraticBezierTo(s * 0.78, s * 0.16, s * 0.78, s * 0.45)
      ..lineTo(s * 0.78, s * 0.70)
      ..close();
    c.drawPath(body, soft);
    c.drawPath(body, stroke);
    c.drawLine(Offset(s * 0.16, s * 0.72), Offset(s * 0.84, s * 0.72), stroke);
    c.drawCircle(Offset(s * 0.50, s * 0.84), s * 0.07, fill);
    c.drawLine(Offset(s * 0.50, s * 0.04), Offset(s * 0.50, s * 0.16), stroke);
  }

  void _kalasha(Canvas c, double s, Paint stroke, Paint fill, Paint soft) {
    final pot = Path()
      ..moveTo(s * 0.34, s * 0.44)
      ..quadraticBezierTo(s * 0.10, s * 0.70, s * 0.30, s * 0.92)
      ..lineTo(s * 0.70, s * 0.92)
      ..quadraticBezierTo(s * 0.90, s * 0.70, s * 0.66, s * 0.44)
      ..close();
    c.drawPath(pot, soft);
    c.drawPath(pot, stroke);
    c.drawLine(Offset(s * 0.30, s * 0.44), Offset(s * 0.70, s * 0.44), stroke);
    c.drawCircle(Offset(s * 0.50, s * 0.30), s * 0.13, fill);
    for (final dx in [-0.22, -0.11, 0.0, 0.11, 0.22]) {
      final leaf = Path()
        ..moveTo(s * 0.50, s * 0.38)
        ..quadraticBezierTo(s * (0.50 + dx * 0.8), s * 0.10, s * (0.50 + dx * 1.6), s * 0.12)
        ..quadraticBezierTo(s * (0.50 + dx * 1.1), s * 0.26, s * 0.50, s * 0.38);
      c.drawPath(leaf, Paint()..color = secondary);
    }
  }

  @override
  bool shouldRepaint(MotifPainter old) => old.motif != motif || old.color != color || old.secondary != secondary;
}
