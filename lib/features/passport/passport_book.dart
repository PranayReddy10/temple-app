import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/widgets/temple_widgets.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/sound_effects.dart';
import '../../core/state/photo_store.dart';
import '../../core/state/sync_service.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/app_image.dart';
import 'stamp_widget.dart';
import 'visit_detail_screen.dart';

/// The Passport as a book: a leather cover, the holder's data page, then
/// visa pages where each visit gets its photo and the temple's ink stamp.
/// Pages turn with a drag or the arrows, folding over at the spine.
class PassportBook extends StatefulWidget {
  const PassportBook({super.key, required this.passport});

  final PassportController passport;

  /// Visits per visa page, as in a real passport: two stamps a page.
  static const perPage = 2;

  /// The size pages are designed at, in the proportions of a passport.
  static const pageSize = Size(300, 416);

  @override
  State<PassportBook> createState() => _PassportBookState();
}

class _PassportBookState extends State<PassportBook> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  double _pos = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController.unbounded(vsync: this)..addListener(() => setState(() => _pos = _anim.value));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// The page last settled on, so a turn that springs back is silent.
  int _page = 0;

  void _settle(double target, int count) {
    final t = target.clamp(0.0, (count - 1).toDouble());
    if (t.round() != _page) {
      _page = t.round();
      SoundEffects.play(context, SoundEffects.pageTurn, volume: 0.9);
    }
    _anim.value = _pos;
    _anim.animateTo(t, duration: Duration(milliseconds: (220 + 260 * (t - _pos).abs()).round().clamp(220, 700)), curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    // Oldest first, like a real passport filling from the front.
    final visits = widget.passport.visits.reversed.toList();
    final visaPages = math.max(1, (visits.length / PassportBook.perPage).ceil() + (visits.length % PassportBook.perPage == 0 ? 1 : 0));
    // Cover, data page, visa pages, and the back cover.
    final count = 3 + visaPages;
    if (_pos > count - 1) _pos = (count - 1).toDouble();

    Widget content(int i) {
      if (i == 0) return const _Cover();
      if (i == 1) return _IdentityPage(passport: widget.passport);
      if (i == count - 1) return _BackCover(passport: widget.passport);
      final from = (i - 2) * PassportBook.perPage;
      final slice = visits.skip(from).take(PassportBook.perPage).toList();
      return _VisaPage(number: i - 1, visits: slice, firstIndex: from);
    }

    // Every page is laid out at one design size and scaled to the space,
    // like print: a small phone gets a smaller book, never a cramped one.
    // The page's own text is not scaled again by the system text size.
    Widget page(int i) => FittedBox(
          child: SizedBox(
            width: PassportBook.pageSize.width,
            height: PassportBook.pageSize.height,
            child: MediaQuery.withNoTextScaling(child: content(i)),
          ),
        );

    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: dark ? Palette.ebony : const Color(0xFFE9DFCF),
      child: LayoutBuilder(
        builder: (context, box) {
          const controls = 56.0;
          final maxH = box.maxHeight - controls - 24;
          const ratio = 300 / 416;
          final width = math.max(120.0, math.min(box.maxWidth - 32, maxH * ratio));
          final height = width / ratio;
          final i = _pos.floor().clamp(0, count - 1);
          final f = (_pos - i).clamp(0.0, 1.0);
          return Column(
            children: [
              const SizedBox(height: 12),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) => _anim.stop(),
                    onHorizontalDragUpdate: (d) => setState(() => _pos = (_pos - d.delta.dx / width).clamp(0.0, (count - 1).toDouble())),
                    onHorizontalDragEnd: (d) {
                      final v = d.primaryVelocity ?? 0;
                      _settle(v < -250 ? _pos.floorToDouble() + 1 : v > 250 ? _pos.ceilToDouble() - 1 : _pos.roundToDouble(), count);
                    },
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: Stack(
                        children: [
                          // The page underneath, shaded near the spine while
                          // the one above is still over it.
                          if (i + 1 < count)
                            Positioned.fill(
                              child: Stack(
                                children: [
                                  Positioned.fill(child: page(i + 1)),
                                  Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)), color: Colors.black.withValues(alpha: 0.25 * (1 - f)))))),
                                ],
                              ),
                            ),
                          // The page being turned, folding about the spine.
                          Positioned.fill(
                            child: Transform(
                              alignment: Alignment.centerLeft,
                              transform: Matrix4.identity()
                                ..setEntry(3, 2, 0.0011)
                                ..rotateY(-f * math.pi / 2),
                              child: Stack(
                                children: [
                                  Positioned.fill(child: page(i)),
                                  if (f > 0) Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)), gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.35 * f)]))))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: controls,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(tooltip: 'Previous page', onPressed: _pos <= 0 ? null : () => _settle(_pos.ceilToDouble() - 1, count), icon: const Icon(Icons.chevron_left_rounded)),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 130,
                      child: Text(
                        i == 0 && f < 0.5
                            ? s('passport_open_hint')
                            : _pos.round() == count - 1
                                ? s('back_cover')
                                : '${s('page')} ${(_pos.round())} / ${count - 2}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton.filledTonal(tooltip: 'Next page', onPressed: _pos >= count - 1 ? null : () => _settle(_pos.floorToDouble() + 1, count), icon: const Icon(Icons.chevron_right_rounded)),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: s('passport_all_pages'),
                      icon: const Icon(Icons.grid_view_rounded),
                      onPressed: () async {
                        final to = await Navigator.of(context).push<int>(MaterialPageRoute(
                          builder: (_) => _Overview(
                            count: count,
                            current: _pos.round(),
                            page: page,
                            label: (k) => k == 0 ? s('cover') : k == 1 ? s('data_page') : k == count - 1 ? s('back_cover') : '${s('page')} $k',
                          ),
                        ));
                        if (to != null && mounted) _settle(to.toDouble(), count);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Leather cover with a gold-blocked emblem and title.
class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) {
    const gold = Palette.gold;
    // The premium plan's gold edition: black leather, the same gilt.
    final premium = context.watch<AuthController>().devotee?.entitlements.premiumPassport ?? false;
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(4), right: Radius.circular(12)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: premium ? const [Color(0xFF1B1512), Color(0xFF0B0908), Color(0xFF2A1F14)] : const [Color(0xFF6E1423), Color(0xFF4A0D18), Color(0xFF5C1020)],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(4, 8))],
      ),
      child: Stack(
        children: [
          // Leather grain.
          const Positioned.fill(child: Opacity(opacity: 0.10, child: CustomPaint(painter: _GrainPainter()))),
          // Spine.
          Positioned(left: 0, top: 0, bottom: 0, width: 14, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent])))),
          // Blind-tooled double border.
          Positioned.fill(child: Padding(padding: const EdgeInsets.all(14), child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: gold.withValues(alpha: 0.55), width: 1.2), borderRadius: BorderRadius.circular(6))))),
          Positioned.fill(child: Padding(padding: const EdgeInsets.all(19), child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: gold.withValues(alpha: 0.3), width: 0.8), borderRadius: BorderRadius.circular(4))))),
          LayoutBuilder(
            builder: (context, box) {
              final u = box.maxWidth / 300;
              TextStyle gilt(double size, {double spacing = 3, String family = 'NotoSerif'}) => TextStyle(color: gold, fontSize: size * u, letterSpacing: spacing * u, fontFamily: family, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), offset: Offset(0, 1 * u), blurRadius: 1)]);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: 28 * u, vertical: 32 * u),
                child: Column(
                  children: [
                    Text('भारत तीर्थ', style: gilt(15, spacing: 2, family: 'NotoSansDevanagari')),
                    SizedBox(height: 4 * u),
                    FittedBox(fit: BoxFit.scaleDown, child: Text('BHARAT TIRTHA', maxLines: 1, style: gilt(11, spacing: 4))),
                    const Spacer(),
                    Container(
                      width: 118 * u,
                      height: 118 * u,
                      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold, width: 2 * u)),
                      padding: EdgeInsets.all(8 * u),
                      child: Container(
                        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold.withValues(alpha: 0.6), width: 1 * u)),
                        child: Center(child: MotifIcon(Motif.kalasha, size: 64 * u, color: gold, secondary: gold.withValues(alpha: 0.6))),
                      ),
                    ),
                    const Spacer(),
                    Text('तीर्थ पासपोर्ट', style: gilt(20, spacing: 2, family: 'NotoSansDevanagari')),
                    SizedBox(height: 6 * u),
                    FittedBox(fit: BoxFit.scaleDown, child: Text('TEMPLE PASSPORT', maxLines: 1, style: gilt(19, spacing: 4))),
                    SizedBox(height: 18 * u),
                    // The e-passport chip symbol.
                    Container(
                      width: 34 * u,
                      height: 22 * u,
                      decoration: BoxDecoration(border: Border.all(color: gold, width: 1.5 * u), borderRadius: BorderRadius.circular(3 * u)),
                      child: Center(child: Container(width: 10 * u, height: 10 * u, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold, width: 1.5 * u)))),
                    ),
                    SizedBox(height: 10 * u),
                    Text(premium ? 'GOLD EDITION · ${Brand.name.toUpperCase()}' : Brand.name.toUpperCase(), style: gilt(8, spacing: 3, family: 'NotoSans')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The back cover: leather again, with the holder's passport code blocked
/// in gold, so the closed book can be shown at a counter as it is.
class _BackCover extends StatelessWidget {
  const _BackCover({required this.passport});

  final PassportController passport;

  @override
  Widget build(BuildContext context) {
    const gold = Palette.gold;
    final s = S.of(context);
    final d = context.watch<AuthController>().devotee;
    final url = d?.passportUrl;
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12), right: Radius.circular(4)),
        gradient: const LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF6E1423), Color(0xFF4A0D18), Color(0xFF5C1020)]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(4, 8))],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: Opacity(opacity: 0.10, child: CustomPaint(painter: _GrainPainter()))),
          // The spine is on the right when the book is turned over.
          Positioned(right: 0, top: 0, bottom: 0, width: 14, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: [Colors.black.withValues(alpha: 0.45), Colors.transparent])))),
          Positioned.fill(child: Padding(padding: const EdgeInsets.all(14), child: DecoratedBox(decoration: BoxDecoration(border: Border.all(color: gold.withValues(alpha: 0.55), width: 1.2), borderRadius: BorderRadius.circular(6))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 30, 28, 26),
            child: Column(
              children: [
                const MotifIcon(Motif.lotus, size: 34, color: gold),
                const SizedBox(height: 10),
                Text(s('back_cover_verse'), textAlign: TextAlign.center, style: const TextStyle(color: gold, fontSize: 11.5, fontFamily: 'NotoSerif', fontStyle: FontStyle.italic, height: 1.4)),
                const Spacer(),
                if (url != null) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: const Color(0xFFFBF5E8), borderRadius: BorderRadius.circular(10), border: Border.all(color: gold, width: 1.5)),
                    child: QrImageView(
                      data: url,
                      size: 132,
                      padding: EdgeInsets.zero,
                      backgroundColor: const Color(0xFFFBF5E8),
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF4A0D18)),
                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF2B2118)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(s('back_cover_scan'), textAlign: TextAlign.center, style: TextStyle(color: gold.withValues(alpha: 0.9), fontSize: 9.5, letterSpacing: 0.5, fontFamily: 'NotoSans')),
                ] else
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: gold.withValues(alpha: 0.7), width: 1.5)),
                    child: const Center(child: MotifIcon(Motif.om, size: 56, color: gold)),
                  ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _BackFigure(value: '${passport.stampCount}', label: s('stamps')),
                    const SizedBox(width: 22),
                    _BackFigure(value: '${passport.visits.length}', label: s('visits')),
                    const SizedBox(width: 22),
                    _BackFigure(value: '${passport.statesVisited.length}', label: 'States'),
                  ],
                ),
                const SizedBox(height: 14),
                Text(Brand.name.toUpperCase(), style: const TextStyle(color: gold, fontSize: 8, letterSpacing: 3, fontFamily: 'NotoSans', fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackFigure extends StatelessWidget {
  const _BackFigure({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value, style: const TextStyle(color: Palette.gold, fontSize: 18, fontFamily: 'NotoSerif', fontWeight: FontWeight.w600)),
          Text(label.toUpperCase(), style: TextStyle(color: Palette.gold.withValues(alpha: 0.75), fontSize: 7.5, letterSpacing: 1.5, fontFamily: 'NotoSans')),
        ],
      );
}

/// Every page of the book at once, cover to back cover. Tapping one turns
/// the book to it.
class _Overview extends StatelessWidget {
  const _Overview({required this.count, required this.current, required this.page, required this.label});

  final int count;
  final int current;
  final Widget Function(int) page;
  final String Function(int) label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? Palette.ebony : const Color(0xFFE9DFCF),
      appBar: AppBar(title: Text(S.of(context)('passport_all_pages'))),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisSpacing: 18, crossAxisSpacing: 14, childAspectRatio: 300 / 416 * 0.88),
        itemCount: count,
        itemBuilder: (context, k) => GestureDetector(
          onTap: () => Navigator.of(context).pop(k),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: k == current ? theme.colorScheme.primary : Colors.transparent, width: 2.5),
                  ),
                  padding: const EdgeInsets.all(3),
                  // The page is drawn as it is in the book, but not
                  // touchable here: a tap picks the page.
                  child: AbsorbPointer(child: page(k)),
                ),
              ),
              const SizedBox(height: 6),
              Text(label(k), style: theme.textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

/// Paper for the inside pages: guilloche lines, a watermark and a folio.
class _Paper extends StatelessWidget {
  const _Paper({required this.child, this.folio, this.header});

  final Widget child;
  final int? folio;
  final String? header;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFBF5E8),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(3), right: Radius.circular(10)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(3, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _GuillochePainter(color: Color(0xFFC9B48E)))),
          Positioned.fill(child: Center(child: Opacity(opacity: 0.035, child: LayoutBuilder(builder: (context, b) => MotifIcon(Motif.kalasha, size: b.maxWidth * 0.62, color: Palette.kumkum))))),
          // The gutter, where the page meets the spine.
          Positioned(left: 0, top: 0, bottom: 0, width: 18, child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.black.withValues(alpha: 0.18), Colors.transparent])))),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) _Header(header!),
                Expanded(child: child),
                if (folio != null) Text('$folio', textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Color(0xFF8C6E4B), fontFamily: 'NotoSerif')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "ENGLISH · देवनागरी": letter-spaced capitals, but never spaced
/// Devanagari, whose joined letters come apart when tracked.
class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final parts = text.split(' · ');
    const base = TextStyle(fontSize: 9, color: Color(0xFF8C6E4B), fontWeight: FontWeight.w700);
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: parts.first, style: base.copyWith(letterSpacing: 2.5)),
        if (parts.length > 1) TextSpan(text: '  ·  ${parts.skip(1).join(' · ')}', style: base.copyWith(fontSize: 10, fontFamily: 'NotoSansDevanagari')),
      ]),
      textAlign: TextAlign.center,
    );
  }
}

/// The data page: photo, particulars and a machine-readable zone.
class _IdentityPage extends StatelessWidget {
  const _IdentityPage({required this.passport});

  final PassportController passport;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final auth = context.watch<AuthController>();
    final d = auth.devotee;
    final name = d?.name ?? s('guest');
    final number = d?.id == null ? 'TP·GUEST' : 'TP${d!.id.toString().padLeft(7, '0')}';
    final issued = DateTime.tryParse(d?.joinedAt ?? '') ?? passport.visits.lastOrNull?.visitedAt ?? DateTime.now();
    final local = auth.localAvatarPath;
    const ink = Color(0xFF2B2118);
    const label = TextStyle(fontSize: 7.5, letterSpacing: 1, color: Color(0xFF8C6E4B), fontWeight: FontWeight.w700);
    const value = TextStyle(fontSize: 12, color: ink, fontFamily: 'NotoSerif', fontWeight: FontWeight.w600);

    Widget field(String l, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l.toUpperCase(), style: label), Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: value)]),
        );

    final gender = switch (d?.gender) { 'male' => 'M', 'female' => 'F', 'other' => 'X', _ => '—' };
    final mrzName = name.toUpperCase().replaceAll(RegExp('[^A-Z ]'), '').trim().replaceAll(RegExp(r'\s+'), '<');
    String pad(String v) => (v.length >= 36 ? v.substring(0, 36) : v.padRight(36, '<'));
    final mrz1 = pad('P<BHT$mrzName<<');
    final mrz2 = pad('${number.replaceAll('·', '<')}<<${passport.stampCount.toString().padLeft(3, '0')}<<${_ymd(issued)}');

    return _Paper(
      header: 'TEMPLE PASSPORT · तीर्थ पासपोर्ट',
      folio: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 82,
                    height: 104,
                    decoration: BoxDecoration(color: const Color(0xFFE8DCC6), border: Border.all(color: const Color(0xFF8C6E4B), width: 0.8)),
                    child: local != null && !kIsWeb
                        ? Image.file(File(local), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 56, color: Color(0xFF8C6E4B)))
                        : d?.avatarUrl != null
                            ? AppImage(d!.avatarUrl!, decodeWidth: 240, placeholder: const Icon(Icons.person_rounded, size: 56, color: Color(0xFF8C6E4B)))
                            : const Icon(Icons.person_rounded, size: 56, color: Color(0xFF8C6E4B)),
                  ),
                  const SizedBox(height: 6),
                  // Signature line.
                  SizedBox(width: 82, child: Text(name.split(' ').first, textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'NotoSerif', fontStyle: FontStyle.italic, fontSize: 13, color: Color(0xFF1F3A68)))),
                  Container(width: 82, height: 0.8, color: const Color(0xFF8C6E4B)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Expanded(child: field('Type', 'P')), Expanded(flex: 2, child: field('Passport No.', number))]),
                    field('Name / नाम', name),
                    Row(children: [Expanded(child: field('Sex', gender)), Expanded(flex: 2, child: field('Home state', d?.homeState ?? '—'))]),
                    field('Date of issue', _dmy(issued)),
                    Row(children: [Expanded(child: field('Stamps', '${passport.stampCount}')), Expanded(child: field('Visits', '${passport.visits.length}'))]),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(child: Opacity(opacity: 0.8, child: MotifIcon(Motif.lotus, size: 30, color: Palette.kumkum.withValues(alpha: 0.6)))),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            color: const Color(0xFFF2EADA),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('$mrz1\n$mrz2', style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Courier', 'NotoSans'], fontSize: 11, letterSpacing: 1.2, color: ink, height: 1.4)),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  static String _dmy(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${const ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'][d.month - 1]} ${d.year}';
  static String _ymd(DateTime d) => '${(d.year % 100).toString().padLeft(2, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

/// A visa page: up to two visits, each a photo with the stamp pressed over
/// its corner. Empty slots invite the next pilgrimage.
class _VisaPage extends StatelessWidget {
  const _VisaPage({required this.number, required this.visits, required this.firstIndex});

  final int number;
  final List<Visit> visits;
  final int firstIndex;

  @override
  Widget build(BuildContext context) {
    return _Paper(
      header: 'VISAS · यात्रा मुद्राएँ',
      folio: number + 1,
      child: Column(
        children: [
          for (var k = 0; k < PassportBook.perPage; k++) ...[
            if (k > 0) Container(height: 0.6, margin: const EdgeInsets.symmetric(vertical: 4), color: const Color(0xFFC9B48E)),
            Expanded(child: k < visits.length ? _VisitEntry(visit: visits[k], ordinal: firstIndex + k + 1) : _EmptySlot(first: firstIndex + k == 0)),
          ],
        ],
      ),
    );
  }
}

class _VisitEntry extends StatelessWidget {
  const _VisitEntry({required this.visit, required this.ordinal});

  final Visit visit;
  final int ordinal;

  Future<void> _addPhoto(BuildContext context) async {
    final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000);
    if (x == null || !context.mounted) return;
    final passport = context.read<PassportController>();
    final signedIn = context.read<AuthController>().isSignedIn;
    final sync = context.read<SyncService>();
    final path = await PhotoStore.keep(x, folder: 'passport');
    await passport.attachPhoto(visit, path);
    if (signedIn) {
      final updated = passport.byKey(visit.localKey) ?? visit;
      await sync.queuePhoto(updated, photoPath: path);
    }
  }

  @override
  Widget build(BuildContext context) {
    // A little tilt that differs stamp to stamp but never changes.
    final tilt = ((visit.localKey.hashCode % 17) - 8) / 100;
    final remote = visit.remotePhoto?.originalUrl;
    Widget? image;
    if (visit.photoPath != null && !kIsWeb) {
      image = Image.file(File(visit.photoPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => remote != null ? AppImage(remote, decodeWidth: 400) : TempleImage(deitySlug: visit.deitySlug, motifSize: 30));
    } else if (remote != null) {
      image = AppImage(remote, decodeWidth: 400);
    }
    return LayoutBuilder(
      builder: (context, box) {
        final photoW = box.maxWidth * 0.46;
        final photoH = math.min(box.maxHeight - 14, photoW * 1.15);
        final stamp = math.min(box.maxHeight * 0.72, box.maxWidth * 0.40);
        return GestureDetector(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => VisitDetailScreen(visitKey: visit.localKey))),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // The photo, taped in.
              Positioned(
                left: 2,
                top: 6,
                child: Transform.rotate(
                  angle: -tilt / 2,
                  child: Container(
                    width: photoW,
                    height: photoH,
                    padding: const EdgeInsets.fromLTRB(5, 5, 5, 16),
                    decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(1, 2))]),
                    child: image != null
                        ? ClipRect(child: image)
                        : InkWell(
                            onTap: () => _addPhoto(context),
                            child: const CustomPaint(
                              painter: _DashedRectPainter(color: Color(0xFFB39A74)),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add_a_photo_rounded, color: Color(0xFF8C6E4B), size: 22),
                                    SizedBox(height: 4),
                                    Text('Add photo', style: TextStyle(fontSize: 10, color: Color(0xFF8C6E4B), fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
              // Tape.
              Positioned(left: photoW * 0.3, top: 0, child: Transform.rotate(angle: -0.12, child: Container(width: photoW * 0.4, height: 12, color: const Color(0xFFEFE3C2).withValues(alpha: 0.85)))),
              // Particulars, written in.
              Positioned(
                left: photoW + 14,
                right: 0,
                top: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('№ $ordinal', style: const TextStyle(fontSize: 9, color: Color(0xFF8C6E4B), fontWeight: FontWeight.w700, letterSpacing: 1)),
                    Text(visit.templeName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'NotoSerif', fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2B2118), height: 1.2)),
                    if (visit.city != null) Text(visit.city!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, color: Color(0xFF5B4A3A))),
                  ],
                ),
              ),
              // The stamp, pressed over the photo's corner.
              Positioned(
                left: photoW - stamp * 0.28,
                bottom: 0,
                child: IgnorePointer(
                  child: Transform.rotate(
                    angle: tilt,
                    child: Opacity(opacity: visit.isVerified ? 0.9 : 0.65, child: StampWidget(visit: visit, size: stamp, inked: visit.isVerified)),
                  ),
                ),
              ),
              if (!visit.isVerified)
                const Positioned(
                  right: 0,
                  bottom: 2,
                  child: Text('SELF-RECORDED', style: TextStyle(fontSize: 7.5, letterSpacing: 1, color: Color(0xFF8C6E4B), fontWeight: FontWeight.w800)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.first});

  final bool first;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFFC9B48E), width: 1.5)),
            child: const Center(child: Icon(Icons.approval_rounded, color: Color(0xFFC9B48E), size: 36)),
          ),
          const SizedBox(height: 8),
          Text(
            first ? S.of(context)('passport_first_stamp') : S.of(context)('passport_next_stamp'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF8C6E4B), fontFamily: 'NotoSerif', fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    const dash = 5.0, gap = 4.0;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += dash + gap) {
        canvas.drawLine(a + dir * d, a + dir * math.min(d + dash, len), p);
      }
    }

    line(Offset.zero, Offset(size.width, 0));
    line(Offset(size.width, 0), Offset(size.width, size.height));
    line(Offset(size.width, size.height), Offset(0, size.height));
    line(Offset(0, size.height), Offset.zero);
  }

  @override
  bool shouldRepaint(_DashedRectPainter old) => old.color != color;
}

/// Fine interlaced waves, the security print of a passport page.
class _GuillochePainter extends CustomPainter {
  const _GuillochePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    for (var row = 0; row < 26; row++) {
      final y0 = size.height * row / 25;
      for (final phase in [0.0, math.pi]) {
        final path = Path()..moveTo(0, y0);
        for (var x = 0.0; x <= size.width; x += 4) {
          path.lineTo(x, y0 + math.sin(x / size.width * math.pi * 6 + phase + row * 0.5) * 7);
        }
        canvas.drawPath(path, p);
      }
    }
    // A rosette in the middle.
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.shortestSide * 0.36;
    final ring = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    for (var k = 0; k < 24; k++) {
      final a = k * math.pi / 12;
      canvas.drawCircle(c + Offset(math.cos(a), math.sin(a)) * r * 0.45, r * 0.55, ring);
    }
  }

  @override
  bool shouldRepaint(_GuillochePainter old) => old.color != color;
}

/// Speckle for the leather cover.
class _GrainPainter extends CustomPainter {
  const _GrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final p = Paint()..color = Colors.black;
    for (var k = 0; k < 1400; k++) {
      canvas.drawCircle(Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height), rnd.nextDouble() * 1.1, p);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}
