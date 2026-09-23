import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/brand.dart';
import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/yatra_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_widgets.dart';

/// A certificate the devotee has earned: a completed circuit or yatra.
class Certificate {
  const Certificate({required this.id, required this.title, required this.subtitle, required this.detail, required this.motif, required this.accent, required this.earnedOn});

  final String id;
  final String title;
  final String subtitle;
  final String detail;
  final Motif motif;
  final Color accent;
  final DateTime earnedOn;

  static List<Certificate> earned(PassportController passport, YatraController yatras) {
    final out = <Certificate>[];
    for (final c in Collection.all) {
      final done = passport.stamps.where((v) => SampleData.bySlug(v.templeSlug)?.categorySlugs.contains(c.categorySlug) ?? false).toList();
      if (done.length >= c.target) {
        out.add(Certificate(
          id: 'circuit-${c.slug}',
          title: c.name,
          subtitle: 'Circuit completed',
          detail: '${c.target} temples · ${c.description}',
          motif: switch (c.slug) { 'jyotirlinga' => Motif.trishul, 'shakti-peetha' => Motif.lotus, 'divya-desam' => Motif.shankhaChakra, _ => Motif.kalasha },
          accent: switch (c.slug) { 'jyotirlinga' => DayTheme.all[1].accent, 'shakti-peetha' => DayTheme.all[5].accent, _ => Palette.saffron },
          earnedOn: done.map((v) => v.visitedAt).reduce((a, b) => a.isAfter(b) ? a : b),
        ));
      }
    }
    for (final y in yatras.yatras.where((y) => y.isComplete)) {
      out.add(Certificate(
        id: 'yatra-${y.id}',
        title: y.name,
        subtitle: 'Yatra completed',
        detail: '${y.stopCount} temples over ${y.days.length} ${y.days.length == 1 ? 'day' : 'days'}',
        motif: DayTheme.forDeity(y.deitySlug).motif,
        accent: DayTheme.forDeity(y.deitySlug).accent,
        earnedOn: y.startDate ?? y.createdAt,
      ));
    }
    return out..sort((a, b) => b.earnedOn.compareTo(a.earnedOn));
  }
}

class CertificatesScreen extends StatelessWidget {
  const CertificatesScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final certs = Certificate.earned(context.watch<PassportController>(), context.watch<YatraController>());
    final name = context.watch<AuthController>().devotee?.name ?? s('guest');
    final body = certs.isEmpty
          ? EmptyShrine(motif: Motif.kalasha, message: s('no_certificates'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              itemCount: certs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 20),
              itemBuilder: (context, i) => _CertificateTile(cert: certs[i], name: name),
            );
    if (embedded) return body;
    return Scaffold(appBar: AppBar(title: Text(s('certificates'))), body: body);
  }
}

class _CertificateTile extends StatefulWidget {
  const _CertificateTile({required this.cert, required this.name});

  final Certificate cert;
  final String name;

  @override
  State<_CertificateTile> createState() => _CertificateTileState();
}

class _CertificateTileState extends State<_CertificateTile> {
  final _key = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await boundary.toImage(pixelRatio: 3);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/certificate-${widget.cert.id}.png');
      await f.writeAsBytes(bytes!.buffer.asUint8List());
      await Share.shareXFiles([XFile(f.path)], text: '${widget.cert.title} · ${Brand.name}');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not share: $e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          RepaintBoundary(key: _key, child: CertificateCard(cert: widget.cert, name: widget.name)),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _sharing ? null : _share, icon: const Icon(Icons.ios_share_rounded), label: Text(S.of(context)('share'))),
        ],
      );
}

/// The certificate itself: sandal paper, brass border, gopuram watermark.
class CertificateCard extends StatelessWidget {
  const CertificateCard({super.key, required this.cert, required this.name});

  final Certificate cert;
  final String name;

  @override
  Widget build(BuildContext context) {
    final date = '${cert.earnedOn.day} ${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][cert.earnedOn.month - 1]} ${cert.earnedOn.year}';
    return AspectRatio(
      aspectRatio: 1.4,
      child: Container(
        decoration: BoxDecoration(color: Palette.ivory, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: cert.accent.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 8))]),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const Opacity(opacity: 0.35, child: CustomPaint(painter: LatticePainter(color: Palette.stone, cell: 22))),
            Positioned(left: 0, right: 0, bottom: 0, child: SizedBox(height: 90, child: CustomPaint(painter: GopuramPainter(color: cert.accent, opacity: 0.12, tiers: 7)))),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: Palette.gold, width: 3), borderRadius: BorderRadius.circular(8)),
                child: Container(margin: const EdgeInsets.all(3), decoration: BoxDecoration(border: Border.all(color: cert.accent, width: 1), borderRadius: BorderRadius.circular(6))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(26, 22, 26, 20),
              child: Column(
                children: [
                  Text(Brand.name.toUpperCase(), style: const TextStyle(color: Palette.deep, fontSize: 9, letterSpacing: 4, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(cert.subtitle.toUpperCase(), style: TextStyle(color: cert.accent, fontSize: 10, letterSpacing: 2.5, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  MotifIcon(cert.motif, size: 40, color: cert.accent),
                  const SizedBox(height: 6),
                  Text(cert.title, textAlign: TextAlign.center, style: const TextStyle(color: Palette.deep, fontFamily: 'NotoSerif', fontSize: 22, fontWeight: FontWeight.w600, height: 1.1)),
                  const SizedBox(height: 4),
                  Text('conferred upon', style: TextStyle(color: Palette.deep.withValues(alpha: 0.7), fontSize: 10, fontStyle: FontStyle.italic)),
                  Text(name, style: const TextStyle(color: Palette.deep, fontFamily: 'NotoSerif', fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(cert.detail, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Palette.deep.withValues(alpha: 0.8), fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(date, style: const TextStyle(color: Palette.deep, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
                ],
              ),
            ),
            Positioned(right: 18, bottom: 16, child: Container(width: 34, height: 34, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass), child: const Center(child: MotifIcon(Motif.om, size: 20, color: Palette.deep)))),
          ],
        ),
      ),
    );
  }
}
