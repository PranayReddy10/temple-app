import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_client.dart';
import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/theme/palette.dart';
import '../temple/temple_screen.dart';

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

/// What a scan found: the temple, the code as scanned, and whether the
/// server confirmed it. [verified] is null when the phone was offline; the
/// server checks the code again when the visit syncs.
class QrScanResult {
  const QrScanResult({required this.slug, required this.raw, this.verified, this.templeName});

  final String slug;
  final String raw;
  final bool? verified;
  final String? templeName;
}

/// Scans a temple QR and checks with the server that it is one we issued;
/// pops with a [QrScanResult].
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.expectedSlug});

  final String? expectedSlug;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;
  bool _checking = false;
  String? _message;
  bool _bad = false;
  final Set<String> _refused = {};

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_done || _checking) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue ?? '';
      if (raw.isEmpty || _refused.contains(raw)) continue;
      final parsed = TempleQr.parse(raw);
      if (parsed == null) {
        _refused.add(raw);
        setState(() {
          _bad = true;
          _message = 'That is not a temple check-in code.';
        });
        continue;
      }
      if (widget.expectedSlug != null && parsed.slug != widget.expectedSlug) {
        _refused.add(raw);
        setState(() {
          _bad = true;
          _message = 'That code belongs to another temple.';
        });
        continue;
      }
      setState(() {
        _checking = true;
        _bad = false;
        _message = 'Checking the code…';
      });
      bool? verified;
      String? name;
      try {
        final json = await context.read<ApiClient>().post('qr/verify', {'code': raw});
        final data = json['data'] as Map<String, dynamic>;
        verified = data['valid'] == true;
        name = (data['temple'] as Map?)?['name']?.toString();
        if (!verified) {
          _refused.add(raw);
          if (mounted) {
            setState(() {
              _checking = false;
              _bad = true;
              _message = 'Not a genuine code. ${data['reason'] ?? ''}'.trim();
            });
          }
          return;
        }
      } catch (_) {
        // Offline at the gate: accept it now; the server checks the
        // signature again when the visit is sent.
        verified = null;
      }
      if (!mounted) return;
      _done = true;
      Navigator.of(context).pop(QrScanResult(slug: parsed.slug, raw: raw, verified: verified, templeName: name));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s('scan_qr')),
        actions: [IconButton(tooltip: 'Where is the code?', onPressed: () => _explain(context), icon: const Icon(Icons.help_outline_rounded))],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(onDetect: _onDetect),
          Center(
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(border: Border.all(color: _bad ? Palette.kumkum : Palette.gold, width: 3), borderRadius: BorderRadius.circular(24)),
              child: const Align(alignment: Alignment.topCenter, child: SizedBox(height: 40, width: 240, child: CustomPaint(painter: ToranaPainter(color: Palette.gold, strokeWidth: 2)))),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: _bad ? Palette.kumkum.withValues(alpha: 0.85) : Colors.black54, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  if (_checking) const Padding(padding: EdgeInsets.only(right: 12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
                  Expanded(child: Text(_message ?? s('qr_where'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _explain(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(S.of(context)('qr_help_title'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Text(S.of(context)('qr_help_body'), style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
            ],
          ),
        ),
      );
}

/// Scan from anywhere (Home, Passport): opens the temple the code belongs
/// to, with its check-in already started as a QR one.
Future<void> scanTempleAndCheckIn(BuildContext context) async {
  final result = await Navigator.of(context).push<QrScanResult>(MaterialPageRoute(builder: (_) => const QrScanScreen()));
  if (result == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TempleScreen(slug: result.slug, initialQr: result)));
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
