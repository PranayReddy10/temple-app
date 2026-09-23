import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/theme/palette.dart';

/// What a temple-issued check-in QR carries.
///
/// Accepted forms: `templepassport://checkin/<slug>`, a URL whose path ends
/// in `/temples/<slug>`, or the bare slug. Signed codes arrive with the
/// official QR network slice; the parser is where the signature check goes.
class TempleQr {
  const TempleQr(this.slug);

  final String slug;

  static TempleQr? parse(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    if (uri != null && uri.scheme == 'templepassport' && uri.host == 'checkin' && uri.pathSegments.isNotEmpty) return TempleQr(uri.pathSegments.first);
    if (uri != null && (uri.scheme == 'https' || uri.scheme == 'http')) {
      final i = uri.pathSegments.indexOf('temples');
      if (i >= 0 && i + 1 < uri.pathSegments.length) return TempleQr(uri.pathSegments[i + 1]);
      return null;
    }
    if (RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$').hasMatch(v)) return TempleQr(v);
    return null;
  }
}

/// Scans a temple QR; pops with the slug it carries.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.expectedSlug});

  final String? expectedSlug;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;
  String? _message;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final parsed = TempleQr.parse(b.rawValue ?? '');
      if (parsed == null) continue;
      if (widget.expectedSlug != null && parsed.slug != widget.expectedSlug) {
        setState(() => _message = 'That code belongs to another temple.');
        continue;
      }
      _done = true;
      Navigator.of(context).pop(parsed.slug);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s('scan_qr'))),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(border: Border.all(color: Palette.gold, width: 3), borderRadius: BorderRadius.circular(24)),
              child: const Align(alignment: Alignment.topCenter, child: SizedBox(height: 40, width: 240, child: CustomPaint(painter: ToranaPainter(color: Palette.gold, strokeWidth: 2)))),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
              child: Text(_message ?? 'Point at the temple\'s check-in code. Codes are issued by temples on the official QR network.', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The devotee's own passport code, for a temple counter to scan.
class MyQrScreen extends StatelessWidget {
  const MyQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final passport = context.watch<PassportController>();
    final d = auth.devotee;
    final payload = d == null ? 'templepassport://guest' : 'templepassport://devotee/${d.id}';
    return Scaffold(
      appBar: AppBar(title: Text(s('my_qr'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Palette.ivory, borderRadius: BorderRadius.circular(24), border: Border.all(color: Palette.gold, width: 3)),
                child: Column(
                  children: [
                    Text(Brand.name.toUpperCase(), style: const TextStyle(color: Palette.deep, letterSpacing: 3, fontSize: 11, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    QrImageView(
                      data: payload,
                      size: 220,
                      backgroundColor: Palette.ivory,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Palette.kumkum),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Palette.deep),
                      embeddedImage: null,
                    ),
                    const SizedBox(height: 12),
                    Text(d?.name ?? s('guest'), style: const TextStyle(color: Palette.deep, fontFamily: 'NotoSerif', fontSize: 20)),
                    Text('${passport.stampCount} ${s('stamps').toLowerCase()}', style: const TextStyle(color: Palette.deep, fontSize: 12)),
                    const SizedBox(height: 6),
                    const MotifIcon(Motif.kalasha, size: 26, color: Palette.kumkum),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                d == null ? 'Sign in so a temple counter can credit stamps to your account.' : 'Show this at a temple counter on the official QR Passport network to have your visit recorded.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
