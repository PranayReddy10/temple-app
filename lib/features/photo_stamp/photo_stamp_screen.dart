import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/passport_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_widgets.dart';
import '../passport/stamp_widget.dart';

/// Photo Stamp: compose a visit photo into a temple-themed memory card with
/// the passport stamp, then save or share it. The original photo is never
/// altered; the card is rendered separately.
class PhotoStampScreen extends StatefulWidget {
  const PhotoStampScreen({super.key, required this.visit});

  final Visit visit;

  @override
  State<PhotoStampScreen> createState() => _PhotoStampScreenState();
}

class _PhotoStampScreenState extends State<PhotoStampScreen> {
  final _cardKey = GlobalKey();
  late String? _photoPath = widget.visit.photoPath;
  int _frame = 0;
  bool _sharing = false;

  Future<void> _pick(ImageSource source) async {
    final x = await ImagePicker().pickImage(source: source, maxWidth: 2400);
    if (x == null || !mounted) return;
    setState(() => _photoPath = x.path);
    await context.read<PassportController>().attachPhoto(widget.visit, x.path);
  }

  Future<File?> _render() async {
    final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/stamp-${widget.visit.templeSlug}-${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(bytes.buffer.asUint8List());
    return file;
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final file = await _render();
      if (file == null) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Darshan at ${widget.visit.templeName} · ${Brand.name}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final day = DayTheme.forDeity(widget.visit.deitySlug);
    return Scaffold(
      appBar: AppBar(title: Text(s('photo_stamp'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: _MemoryCard(visit: widget.visit, photoPath: _photoPath, day: day, frame: _frame),
            ),
          ),
          const SizedBox(height: 16),
          Text('Frame', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Torana')),
              ButtonSegment(value: 1, label: Text('Gopuram')),
              ButtonSegment(value: 2, label: Text('Kolam')),
            ],
            selected: {_frame},
            onSelectionChanged: (v) => setState(() => _frame = v.first),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_library_rounded), label: const Text('Gallery'))),
              const SizedBox(width: 10),
              if (!kIsWeb) Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_rounded), label: const Text('Camera'))),
            ],
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _sharing ? null : _share,
            icon: _sharing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.ios_share_rounded),
            label: Text(s('share')),
          ),
          const SizedBox(height: 12),
          Text('Your original photo is kept untouched. The card is rendered separately and can be shared or saved from the share sheet.', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.visit, required this.photoPath, required this.day, required this.frame});

  final Visit visit;
  final String? photoPath;
  final DayTheme day;
  final int frame;

  @override
  Widget build(BuildContext context) {
    final date = '${visit.visitedAt.day} ${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][visit.visitedAt.month - 1]} ${visit.visitedAt.year}';
    return Container(
      width: 320,
      height: 420,
      decoration: BoxDecoration(
        color: Palette.deep,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: day.accent.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 12))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photoPath != null && !kIsWeb)
            Image.file(File(photoPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => TempleImage(deitySlug: visit.deitySlug, motifSize: 120))
          else
            TempleImage(deitySlug: visit.deitySlug, motifSize: 120),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: const [0, 0.5, 1], colors: [Colors.black.withValues(alpha: 0.35), Colors.transparent, Colors.black.withValues(alpha: 0.7)]),
            ),
          ),
          if (frame == 0) const Positioned(left: 0, right: 0, top: 0, child: SizedBox(height: 70, child: CustomPaint(painter: ToranaPainter(color: Palette.gold, strokeWidth: 3, scallops: 13)))),
          if (frame == 1) const Positioned(left: 0, right: 0, bottom: 0, child: SizedBox(height: 150, child: CustomPaint(painter: GopuramPainter(color: Palette.gold, opacity: 0.28, tiers: 7)))),
          if (frame == 2) ...[
            const Positioned(left: 0, right: 0, top: 8, child: SizedBox(height: 28, child: CustomPaint(painter: KolamPainter(color: Palette.gold)))),
            const Positioned(left: 0, right: 0, bottom: 8, child: SizedBox(height: 28, child: CustomPaint(painter: KolamPainter(color: Palette.gold)))),
          ],
          Positioned(right: 14, top: 44, child: StampWidget(visit: visit, size: 110)),
          Positioned(
            left: 18,
            right: 18,
            bottom: frame == 2 ? 44 : 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MotifIcon(day.motif, size: 18, color: Palette.gold, secondary: day.secondary),
                    const SizedBox(width: 6),
                    Text(day.deityName.toUpperCase(), style: const TextStyle(color: Palette.gold, fontSize: 10, letterSpacing: 2.5, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(visit.templeName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.sandal, fontFamily: 'NotoSerif', fontSize: 20, fontWeight: FontWeight.w600, height: 1.15)),
                const SizedBox(height: 2),
                Text([visit.city, visit.state].whereType<String>().join(', '), style: const TextStyle(color: Palette.sandal, fontSize: 12)),
                Text(date, style: TextStyle(color: Palette.sandal.withValues(alpha: 0.8), fontSize: 11)),
                if (visit.note != null) ...[const SizedBox(height: 6), Text('“${visit.note}”', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.sandal, fontStyle: FontStyle.italic, fontSize: 12))],
                const SizedBox(height: 8),
                Text(Brand.name.toUpperCase(), style: TextStyle(color: Palette.gold.withValues(alpha: 0.8), fontSize: 9, letterSpacing: 3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
