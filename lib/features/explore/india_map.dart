import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/theme/day_theme.dart';

/// A hand-drawn outline of India with each temple plotted as a lamp in its
/// deity's colour. Tapping a lamp opens that temple.
///
/// It is not a slippy map: it needs no tiles, no key and no network, which
/// is what an offline pilgrim actually has. A tile map arrives in a later
/// slice; this stays as the offline fallback.
class IndiaMap extends StatelessWidget {
  const IndiaMap({super.key, required this.temples, required this.onTap});

  final List<TempleSummary> temples;
  final void Function(TempleSummary) onTap;

  // Bounding box of the subcontinent used for the equirectangular projection.
  static const double minLat = 6.5, maxLat = 37.5, minLng = 67.5, maxLng = 97.5;

  static Offset project(double lat, double lng, Size size) => Offset(
        (lng - minLng) / (maxLng - minLng) * size.width,
        (1 - (lat - minLat) / (maxLat - minLat)) * size.height,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final located = temples.where((t) => t.location.hasCoordinates).toList();
    return AspectRatio(
      aspectRatio: 1 / 1.08,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);
            return Stack(
              children: [
                Positioned.fill(child: Opacity(opacity: 0.35, child: CustomPaint(painter: LatticePainter(color: theme.colorScheme.primary.withValues(alpha: 0.3), cell: 26)))),
                Positioned.fill(child: CustomPaint(painter: _OutlinePainter(color: theme.colorScheme.primary))),
                for (final t in located)
                  Positioned(
                    left: project(t.location.latitude!, t.location.longitude!, size).dx - 11,
                    top: project(t.location.latitude!, t.location.longitude!, size).dy - 11,
                    child: _Lamp(temple: t, onTap: () => onTap(t)),
                  ),
                Positioned(
                  left: 14,
                  bottom: 12,
                  child: Text(
                    '${located.length} temples',
                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), letterSpacing: 1),
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

class _Lamp extends StatelessWidget {
  const _Lamp({required this.temple, required this.onTap});

  final TempleSummary temple;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = DayTheme.forDeity(temple.deity?.slug).accent;
    return Tooltip(
      message: temple.name,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: c,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)],
          ),
        ),
      ),
    );
  }
}

/// A simplified coastline, drawn in lat/lng and projected at paint time.
class _OutlinePainter extends CustomPainter {
  const _OutlinePainter({required this.color});

  final Color color;

  static const List<List<double>> _coast = [
    [35.5, 74.0], [36.5, 76.0], [35.0, 78.5], [33.0, 79.0], [32.0, 79.5], [30.5, 81.0], [28.5, 84.0], [27.5, 88.0], [28.0, 89.5],
    [27.0, 92.0], [28.2, 96.0], [27.0, 97.0], [25.0, 95.0], [23.5, 94.5], [22.0, 93.0], [24.0, 92.0], [25.2, 90.0], [24.5, 88.5],
    [22.0, 89.0], [21.5, 87.0], [20.0, 86.8], [19.0, 85.0], [17.5, 83.5], [16.0, 81.5], [15.0, 80.2], [13.5, 80.3], [12.0, 80.0],
    [10.5, 79.8], [9.3, 79.0], [8.1, 77.5], [8.5, 76.8], [10.0, 76.2], [12.0, 75.0], [14.5, 74.2], [16.5, 73.3], [18.5, 72.9],
    [20.5, 72.7], [22.0, 72.6], [21.0, 71.0], [20.8, 70.0], [22.3, 68.9], [23.5, 68.5], [24.0, 70.0], [24.5, 71.0], [27.0, 70.0],
    [28.5, 71.0], [30.0, 73.5], [32.0, 75.0], [33.5, 74.0], [34.5, 73.8], [35.5, 74.0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < _coast.length; i++) {
      final p = IndiaMap.project(_coast[i][0], _coast[i][1], size);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.08));
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round,
    );
    // Sri Lanka, for orientation.
    final sl = IndiaMap.project(7.8, 80.7, size);
    canvas.drawOval(Rect.fromCenter(center: sl, width: size.width * 0.05, height: size.height * 0.07), Paint()..color = color.withValues(alpha: 0.15));
    // Compass rose.
    final c = Offset(size.width - 28, 28);
    canvas.drawCircle(c, 12, Paint()..color = color.withValues(alpha: 0.12));
    for (var i = 0; i < 4; i++) {
      final a = i * math.pi / 2 - math.pi / 2;
      canvas.drawLine(c, c + Offset(math.cos(a), math.sin(a)) * 12, Paint()..color = color..strokeWidth = i == 0 ? 2 : 1);
    }
  }

  @override
  bool shouldRepaint(_OutlinePainter old) => old.color != color;
}
