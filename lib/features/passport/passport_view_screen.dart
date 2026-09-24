import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/passport_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/temple_door.dart';
import '../temple/temple_screen.dart';
import 'stamp_widget.dart';

/// Someone else's passport, opened by scanning the code they showed.
///
/// Only what they share: a name, a photo and the visits they left public.
/// The server decides that, not this screen.
class PassportViewScreen extends StatefulWidget {
  const PassportViewScreen({super.key, required this.code});

  final String code;

  @override
  State<PassportViewScreen> createState() => _PassportViewScreenState();
}

class _PassportViewScreenState extends State<PassportViewScreen> {
  PublicPassport? _passport;

  /// A string key, or the server's own message; turned into words in build.
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await context.read<ApiClient>().get('passports/${widget.code}');
      _passport = PublicPassport.fromJson(json['data'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      _error = e.isNotFound ? 'passport_not_found' : e.message;
    } catch (_) {
      _error = 'passport_offline';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// A public visit, shaped for the stamp widget.
  static Visit _asVisit(RemoteVisit r) => Visit(
        templeSlug: r.templeSlug,
        templeName: r.templeName,
        deitySlug: SampleData.bySlug(r.templeSlug)?.deity?.slug,
        visitedAt: DateTime.tryParse(r.visitedOn ?? '') ?? DateTime.now(),
        city: r.city,
        verification: switch (r.method) { 'gps' => Verification.gps, 'qr' => Verification.qr, 'staff' => Verification.staff, _ => Verification.manual },
        localKey: 'public-${r.id}',
        remoteId: r.id,
        remoteVerified: r.isVerified,
      );

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final p = _passport;
    return Scaffold(
      appBar: AppBar(title: Text(s('passport'))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : p == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const MotifIcon(Motif.kalasha, size: 64, color: Palette.stone),
                        const SizedBox(height: 16),
                        Text(s(_error ?? 'passport_offline'), textAlign: TextAlign.center, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _load, child: Text(s('retry'))),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _Cover(passport: p)),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                        sliver: SliverToBoxAdapter(child: Text(s('stamps'), style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif'))),
                      ),
                      if (p.visits.isEmpty)
                        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32), child: Text(s('passport_none_shared'), textAlign: TextAlign.center, style: theme.textTheme.bodyMedium)))
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.78),
                            delegate: SliverChildBuilderDelegate(
                              childCount: p.visits.length,
                              (context, i) {
                                final v = _asVisit(p.visits[i]);
                                final day = DayTheme.forDeity(v.deitySlug);
                                return InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: v.templeSlug.isEmpty ? null : () => enterTemple(context, TempleScreen(slug: v.templeSlug, preview: SampleData.bySlug(v.templeSlug)), accent: day.accent),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(color: const Color(0xFFFBF5E8), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2D3B8))),
                                    child: Column(
                                      children: [
                                        Expanded(child: FittedBox(child: Opacity(opacity: v.isVerified ? 0.95 : 0.6, child: StampWidget(visit: v, inked: v.isVerified)))),
                                        const SizedBox(height: 6),
                                        Text(v.templeName, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'NotoSerif', fontSize: 12.5, color: Color(0xFF2B2118), height: 1.2)),
                                        const SizedBox(height: 4),
                                        FittedBox(child: VerificationBadge(verification: v.isVerified ? v.verification : Verification.manual, compact: true)),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.passport});

  final PublicPassport passport;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final joined = DateTime.tryParse(passport.joinedAt ?? '');
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF6E1423), Color(0xFF4A0D18)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: Opacity(opacity: 0.08, child: CustomPaint(painter: LatticePainter(color: Palette.gold, cell: 26)))),
          Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: Palette.gold,
                    child: ClipOval(
                      child: SizedBox.expand(
                        child: passport.avatarUrl != null
                            ? AppImage(passport.avatarUrl!, decodeWidth: 128, placeholder: _initial(passport.name))
                            : _initial(passport.name),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TEMPLE PASSPORT', style: theme.textTheme.labelSmall?.copyWith(color: Palette.gold, letterSpacing: 3)),
                        Text(passport.name, style: theme.textTheme.headlineSmall?.copyWith(color: Palette.sandal, fontFamily: 'NotoSerif')),
                        Text(
                          [if (passport.homeState != null) passport.homeState!, if (joined != null) '${s('member_since')} ${joined.year}'].join(' · '),
                          style: theme.textTheme.bodySmall?.copyWith(color: Palette.sandal.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  _Stat(value: passport.stamps, label: s('stamps')),
                  _Stat(value: passport.templesVisited, label: 'Temples'),
                  _Stat(value: passport.visitsRecorded, label: s('visits')),
                  _Stat(value: passport.statesCovered, label: 'States'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _initial(String name) => Center(child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(), style: const TextStyle(fontSize: 26, color: Palette.deep, fontFamily: 'NotoSerif')));
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text('$value', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Palette.gold)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label.toUpperCase(), maxLines: 1, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Palette.sandal.withValues(alpha: 0.8), letterSpacing: 1.2))),
          ],
        ),
      );
}
