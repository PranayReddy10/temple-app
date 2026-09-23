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
import '../auth/auth_screen.dart';
import '../passport/passport_view_screen.dart';
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

/// What a devotee's own passport QR carries: a random code, never the
/// account id. Accepted as the server's `…/passport/<code>` link, the app's
/// `templepassport://passport/<code>`, or the bare code.
class PassportCode {
  const PassportCode._();

  static final _token = RegExp(r'^[A-Za-z0-9]{16,32}$');

  static String? parse(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    if (uri != null && uri.hasScheme) {
      final segments = [if (uri.scheme == 'templepassport' && uri.host.isNotEmpty) uri.host, ...uri.pathSegments.where((p) => p.isNotEmpty)];
      final i = segments.indexOf('passport');
      if (i < 0 || i + 1 >= segments.length) return null;
      return _token.hasMatch(segments[i + 1]) ? segments[i + 1] : null;
    }
    // A bare slug like "kashi-vishwanath" has a hyphen; a code never does.
    return _token.hasMatch(v) ? v : null;
  }
}

/// A scanned devotee passport, from a scanner that accepts them.
class PassportScanResult {
  const PassportScanResult(this.code);

  final String code;
}

/// Scans a temple QR and checks with the server that it is one we issued;
/// pops with a [QrScanResult]. With [allowPassports], a devotee's passport
/// code is accepted too and pops with a [PassportScanResult].
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key, this.expectedSlug, this.allowPassports = false});

  final String? expectedSlug;
  final bool allowPassports;

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  bool _done = false;
  bool _checking = false;
  String? _message;
  bool _bad = false;
  final Set<String> _refused = {};

  void _refuse(String raw, String message) {
    _refused.add(raw);
    setState(() {
      _bad = true;
      _message = message;
    });
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_done || _checking) return;
    final s = S.of(context);
    for (final b in capture.barcodes) {
      final raw = b.rawValue ?? '';
      if (raw.isEmpty || _refused.contains(raw)) continue;
      final passport = PassportCode.parse(raw);
      if (passport != null) {
        if (!widget.allowPassports) {
          _refuse(raw, s('qr_is_passport'));
          continue;
        }
        _done = true;
        Navigator.of(context).pop(PassportScanResult(passport));
        return;
      }
      final parsed = TempleQr.parse(raw);
      if (parsed == null) {
        _refuse(raw, widget.allowPassports ? s('qr_not_ours') : 'That is not a temple check-in code.');
        continue;
      }
      if (widget.expectedSlug != null && parsed.slug != widget.expectedSlug) {
        _refuse(raw, 'That code belongs to another temple.');
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
        title: Text(widget.allowPassports ? s('scan_any_qr') : s('scan_qr')),
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
                  Expanded(child: Text(_message ?? (widget.allowPassports ? s('qr_where_any') : s('qr_where')), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white))),
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

/// Scan from anywhere (Home, Passport). A temple's code opens the temple
/// with its check-in already started as a QR one; a devotee's passport code
/// opens their passport.
Future<void> scanCode(BuildContext context) async {
  final result = await Navigator.of(context).push<Object>(MaterialPageRoute(builder: (_) => const QrScanScreen(allowPassports: true)));
  if (result == null || !context.mounted) return;
  if (result is PassportScanResult) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PassportViewScreen(code: result.code)));
  } else if (result is QrScanResult) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TempleScreen(slug: result.slug, initialQr: result)));
  }
}

/// The devotee's own passport code: another devotee scans it to see the
/// passport; a temple counter scans it to see it and mark today's visit.
class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensure());
  }

  Future<void> _ensure() async {
    final auth = context.read<AuthController>();
    if (!auth.isSignedIn || auth.devotee?.passportUrl != null) return;
    setState(() => _loading = true);
    await auth.passportUrl();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = auth.devotee?.passportUrl == null ? S.of(context)('my_qr_offline') : null;
    });
  }

  Future<void> _reset() async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s('my_qr_reset')),
        content: Text(s('my_qr_reset_body')),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(s('keep'))),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(s('my_qr_reset'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loading = true);
    try {
      await context.read<AuthController>().resetPassportCode();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('my_qr_reset_done'))));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('my_qr_offline'))));
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final auth = context.watch<AuthController>();
    final passport = context.watch<PassportController>();
    final d = auth.devotee;
    final url = d?.passportUrl;
    return Scaffold(
      appBar: AppBar(
        title: Text(s('my_qr')),
        actions: [
          if (url != null)
            PopupMenuButton<String>(
              onSelected: (_) => _reset(),
              itemBuilder: (_) => [PopupMenuItem(value: 'reset', child: Text(s('my_qr_reset')))],
            ),
        ],
      ),
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
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: url != null
                          ? QrImageView(
                              data: url,
                              size: 220,
                              backgroundColor: Palette.ivory,
                              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Palette.kumkum),
                              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Palette.deep),
                            )
                          : Center(
                              child: _loading
                                  ? const CircularProgressIndicator()
                                  : const Icon(Icons.qr_code_2_rounded, size: 120, color: Color(0x33000000)),
                            ),
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
                d == null ? s('my_qr_guest') : _error ?? s('my_qr_note'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
              if (d == null) ...[
                const SizedBox(height: 12),
                FilledButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen())), child: Text(s('sign_in'))),
              ],
              if (_error != null && d != null) ...[
                const SizedBox(height: 12),
                OutlinedButton(onPressed: _ensure, child: Text(s('retry'))),
              ],
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => scanCode(context),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(s('scan_friend_passport')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
