import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/architecture.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/sync_service.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../certificates/certificates_screen.dart';
import '../family/family_screen.dart';
import '../photo_stamp/photo_stamp_screen.dart';
import '../qr/qr_screens.dart';
import '../temple/temple_screen.dart';
import 'stamp_widget.dart';

/// The Passport: a stamp book of temples visited, the visit log, circuit
/// collections and achievements. Styled as a bound booklet with a brass
/// cover and sandal pages.
class PassportScreen extends StatefulWidget {
  const PassportScreen({super.key});

  @override
  State<PassportScreen> createState() => _PassportScreenState();
}

class _PassportScreenState extends State<PassportScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final passport = context.watch<PassportController>();
    final devotee = context.watch<AuthController>().devotee;
    final sync = context.watch<SyncService>();
    final summary = passport.summary;
    final top = MediaQuery.paddingOf(context).top;

    return Column(
      children: [
        // Passport cover.
        Container(
          padding: EdgeInsets.fromLTRB(20, top + 12, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.deep, Color.lerp(Palette.deep, Palette.kumkum, 0.35)!]),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: Stack(
            children: [
              const Positioned.fill(child: Opacity(opacity: 0.08, child: CustomPaint(painter: LatticePainter(color: Palette.gold, cell: 28)))),
              Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(shape: BoxShape.circle, gradient: Palette.brass),
                        child: const Center(child: MotifIcon(Motif.kalasha, size: 32, color: Palette.deep)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('TEMPLE PASSPORT', style: theme.textTheme.labelSmall?.copyWith(color: Palette.gold, letterSpacing: 3)),
                            Text(devotee?.name ?? s('guest'), style: theme.textTheme.headlineSmall?.copyWith(color: Palette.sandal)),
                          ],
                        ),
                      ),
                      IconButton(tooltip: s('scan_qr'), color: Palette.gold, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QrScanScreen())), icon: const Icon(Icons.qr_code_scanner_rounded)),
                      IconButton(tooltip: s('my_qr'), color: Palette.gold, onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MyQrScreen())), icon: const Icon(Icons.qr_code_2_rounded)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat(value: '${summary?.stamps ?? passport.verifiedStamps}', label: 'Verified'),
                      _Stat(value: '${summary?.templesVisited ?? passport.stampCount}', label: 'Temples'),
                      _Stat(value: '${summary?.visitsRecorded ?? passport.visits.length}', label: s('visits')),
                      _Stat(value: '${summary?.statesCovered ?? passport.statesVisited.length}', label: 'States'),
                    ],
                  ),
                  if (devotee != null || sync.pendingCount > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(sync.pendingCount > 0 ? Icons.cloud_upload_outlined : Icons.cloud_done_rounded, size: 13, color: Palette.gold),
                        const SizedBox(width: 5),
                        Expanded(child: Text(sync.pendingCount > 0 ? '${sync.pendingCount} waiting to reach your account' : devotee == null ? '' : 'In sync with your account', style: theme.textTheme.labelSmall?.copyWith(color: Palette.sandal.withValues(alpha: 0.8)))),
                        if (devotee != null) InkWell(onTap: sync.isFlushing ? null : () => sync.sync(), child: const Icon(Icons.sync_rounded, size: 16, color: Palette.gold)),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: theme.textTheme.labelLarge,
          tabs: [Tab(text: s('stamps')), Tab(text: s('visits')), Tab(text: s('collections')), Tab(text: s('achievements')), Tab(text: s('family')), Tab(text: s('certificates'))],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _StampsPage(passport: passport),
              _VisitsPage(passport: passport),
              _CollectionsPage(passport: passport),
              _AchievementsPage(passport: passport),
              const FamilyScreen(embedded: true),
              const CertificatesScreen(embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Palette.gold)),
            FittedBox(fit: BoxFit.scaleDown, child: Text(label.toUpperCase(), maxLines: 1, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Palette.sandal.withValues(alpha: 0.8), letterSpacing: 1.2))),
          ],
        ),
      );
}

class _StampsPage extends StatelessWidget {
  const _StampsPage({required this.passport});

  final PassportController passport;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final stamps = passport.stamps;
    if (stamps.isEmpty) return EmptyShrine(motif: Motif.kalasha, message: s('no_stamps'));
    // The page: sandal paper with faint lattice, stamps in a loose grid.
    return Container(
      color: Theme.of(context).brightness == Brightness.dark ? Palette.darkStone : Palette.ivory,
      child: Stack(
        children: [
          const Positioned.fill(child: Opacity(opacity: 0.25, child: CustomPaint(painter: LatticePainter(color: Palette.stone, cell: 40)))),
          GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 20, crossAxisSpacing: 12, childAspectRatio: 0.92),
            itemCount: stamps.length,
            itemBuilder: (context, i) {
              final v = stamps[i];
              return GestureDetector(
                onTap: () => enterTemple(context, TempleScreen(slug: v.templeSlug, preview: SampleData.bySlug(v.templeSlug)), accent: DayTheme.forDeity(v.deitySlug).accent),
                child: Column(
                  children: [
                    Expanded(child: Center(child: StampWidget(visit: v, size: 140))),
                    Text(v.templeName, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium?.copyWith(fontFamily: 'NotoSerif')),
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

class _VisitsPage extends StatelessWidget {
  const _VisitsPage({required this.passport});

  final PassportController passport;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final visits = passport.visits;
    if (visits.isEmpty) return EmptyShrine(motif: Motif.diya, message: s('no_stamps'));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: visits.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final v = visits[i];
        final day = DayTheme.forDeity(v.deitySlug);
        return Dismissible(
          key: ValueKey('${v.templeSlug}-${v.visitedAt.toIso8601String()}'),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            decoration: BoxDecoration(color: theme.colorScheme.error, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
          ),
          confirmDismiss: (_) async => await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Remove this visit?'),
                  content: Text('The stamp for ${v.templeName} is kept only while a visit remains.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep')),
                    FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
                  ],
                ),
              ) ??
              false,
          onDismissed: (_) => passport.remove(v),
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              leading: v.photoPath != null && !kIsWeb
                  ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.file(File(v.photoPath!), width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => MotifIcon(day.motif, size: 40, color: day.accent)))
                  : MotifIcon(day.motif, size: 40, color: day.accent, secondary: day.secondary),
              title: Text(v.templeName, style: const TextStyle(fontFamily: 'NotoSerif')),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_date(v.visitedAt)}${v.city != null ? ' · ${v.city}' : ''}${v.note != null ? '\n${v.note}' : ''}'),
                  const SizedBox(height: 4),
                  Row(children: [VerificationBadge(verification: v.verification, compact: true), if (v.members.isNotEmpty) ...[const SizedBox(width: 6), Icon(Icons.group_rounded, size: 14, color: theme.colorScheme.outline), Text(' ${v.members.length}', style: theme.textTheme.labelSmall)]]),
                ],
              ),
              isThreeLine: true,
              trailing: IconButton(
                tooltip: s('photo_stamp'),
                icon: const Icon(Icons.auto_awesome_rounded),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoStampScreen(visit: v))),
              ),
              onTap: () => enterTemple(context, TempleScreen(slug: v.templeSlug, preview: SampleData.bySlug(v.templeSlug)), accent: day.accent),
            ),
          ),
        );
      },
    );
  }

  static String _date(DateTime d) => '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
}

class _CollectionsPage extends StatelessWidget {
  const _CollectionsPage({required this.passport});

  final PassportController passport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final server = passport.summary?.circuits;
    if (server != null && server.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        itemCount: server.length + 1,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == server.length) return Text('Counted against verified visits, and against the temples recorded so far, not the whole circuit.', style: theme.textTheme.bodySmall);
          final c = server[i];
          final accent = switch (c.slug) { 'jyotirlinga' => DayTheme.all[1].accent, 'shakti-peetha' => DayTheme.all[5].accent, 'divya-desam' => DayTheme.all[4].accent, _ => theme.colorScheme.primary };
          final motif = switch (c.slug) { 'jyotirlinga' => Motif.trishul, 'shakti-peetha' => Motif.lotus, 'divya-desam' => Motif.shankhaChakra, 'sapta-puri' => Motif.om, _ => Motif.kalasha };
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20), border: Border.all(color: accent.withValues(alpha: 0.4))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MotifIcon(motif, size: 36, color: accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.name, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif'))),
                    Text('${c.collected} / ${c.recorded}', style: theme.textTheme.titleMedium?.copyWith(color: accent)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${c.collected} of ${c.recorded} recorded${c.total != null ? ' · ${c.total} in all' : ''}', style: theme.textTheme.bodySmall),
                const SizedBox(height: 10),
                ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: c.recorded == 0 ? 0 : c.collected / c.recorded, minHeight: 8, color: accent, backgroundColor: accent.withValues(alpha: 0.15))),
              ],
            ),
          );
        },
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      itemCount: Collection.all.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final c = Collection.all[i];
        // Progress from bundled categories; live category membership lands
        // in the stamp record once the detail endpoint is cached offline.
        final done = passport.stamps.where((v) => SampleData.bySlug(v.templeSlug)?.categorySlugs.contains(c.categorySlug) ?? false).length;
        final motif = switch (c.slug) {
          'jyotirlinga' => Motif.trishul,
          'shakti-peetha' => Motif.lotus,
          'divya-desam' => Motif.shankhaChakra,
          'sapta-puri' => Motif.om,
          _ => Motif.kalasha,
        };
        final accent = switch (c.slug) {
          'jyotirlinga' => DayTheme.all[1].accent,
          'shakti-peetha' => DayTheme.all[5].accent,
          'divya-desam' => DayTheme.all[4].accent,
          _ => theme.colorScheme.primary,
        };
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20), border: Border.all(color: accent.withValues(alpha: 0.4))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MotifIcon(motif, size: 36, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif')),
                        Text(c.description, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                  Text('$done / ${c.target}', style: theme.textTheme.titleMedium?.copyWith(color: accent)),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: c.target == 0 ? 0 : done / c.target, minHeight: 8, color: accent, backgroundColor: accent.withValues(alpha: 0.15)),
              ),
              if (done >= c.target) ...[
                const SizedBox(height: 8),
                Row(children: [const Icon(Icons.workspace_premium_rounded, color: Palette.gold, size: 18), const SizedBox(width: 6), Text('Circuit complete', style: theme.textTheme.labelMedium?.copyWith(color: Palette.gold))]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _AchievementsPage extends StatelessWidget {
  const _AchievementsPage({required this.passport});

  final PassportController passport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.95),
      itemCount: Achievement.all.length,
      itemBuilder: (context, i) {
        final a = Achievement.all[i];
        final earned = a.test(passport);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: earned ? Palette.brass : null,
            color: earned ? null : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: earned ? Palette.gold : theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(earned ? Icons.workspace_premium_rounded : Icons.lock_outline_rounded, color: earned ? Palette.deep : theme.colorScheme.outline, size: 30),
              const Spacer(),
              Text(a.title, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif', color: earned ? Palette.deep : null)),
              const SizedBox(height: 4),
              Text(a.description, style: theme.textTheme.bodySmall?.copyWith(color: earned ? Palette.deep.withValues(alpha: 0.8) : null)),
            ],
          ),
        );
      },
    );
  }
}
