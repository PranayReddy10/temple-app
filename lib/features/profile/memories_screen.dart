import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/passport_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/widgets/temple_widgets.dart';
import '../photo_stamp/photo_stamp_screen.dart';

/// Every photo a devotee has attached to a visit, newest first, each opening
/// its Photo Stamp card.
class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final passport = context.watch<PassportController>();
    final memories = passport.visits.where((v) => v.photoPath != null).toList();
    final byMonth = <String, List<Visit>>{};
    for (final v in memories) {
      byMonth.putIfAbsent(_month(v.visitedAt), () => []).add(v);
    }
    return Scaffold(
      appBar: AppBar(title: Text(s('memories'))),
      body: memories.isEmpty
          ? EmptyShrine(motif: Motif.lotus, message: s('no_memories'))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                for (final e in byMonth.entries) ...[
                  Padding(padding: const EdgeInsets.fromLTRB(0, 16, 0, 10), child: Text(e.key, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif'))),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82),
                    itemCount: e.value.length,
                    itemBuilder: (context, i) => _MemoryTile(visit: e.value[i]),
                  ),
                ],
              ],
            ),
    );
  }

  static String _month(DateTime d) => '${const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][d.month - 1]} ${d.year}';
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final day = DayTheme.forDeity(visit.deitySlug);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoStampScreen(visit: visit))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (kIsWeb) TempleImage(deitySlug: visit.deitySlug) else Image.file(File(visit.photoPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => TempleImage(deitySlug: visit.deitySlug)),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 22, 10, 10),
                decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black87])),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [MotifIcon(day.motif, size: 12, color: Colors.white), const SizedBox(width: 4), Text(day.deityName.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 9, letterSpacing: 1.5))]),
                    Text(visit.templeName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontFamily: 'NotoSerif', fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${visit.visitedAt.day}/${visit.visitedAt.month}/${visit.visitedAt.year}', style: const TextStyle(color: Colors.white70, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
