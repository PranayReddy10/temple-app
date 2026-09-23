import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/memories_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/state/sync_service.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/temple_widgets.dart';
import '../explore/search_screen.dart';
import '../photo_stamp/photo_stamp_screen.dart';

/// Memories: the devotee's own writing about visits, private by default,
/// and the photos attached to visits. Both live on the device and sync to
/// the account when signed in.
class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final passport = context.watch<PassportController>();
    final memories = context.watch<MemoriesController>();
    final sync = context.watch<SyncService>();
    final photos = passport.visits.where((v) => v.photoPath != null || v.remotePhoto != null).toList();
    final written = memories.all;
    return Scaffold(
      appBar: AppBar(title: Text(s('memories'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => write(context), icon: const Icon(Icons.edit_note_rounded), label: const Text('Write a memory')),
      body: written.isEmpty && photos.isEmpty
          ? EmptyShrine(motif: Motif.lotus, message: s('no_memories'), action: OutlinedButton(onPressed: () => write(context), child: const Text('Write a memory')))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                if (sync.pendingCount > 0)
                  Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('${sync.pendingCount} change${sync.pendingCount == 1 ? '' : 's'} waiting to reach your account.', style: theme.textTheme.bodySmall)),
                if (written.isNotEmpty) ...[
                  const SectionHeader(title: 'Written', motif: Motif.om),
                  for (final m in written) _MemoryCard(memory: m),
                ],
                if (photos.isNotEmpty) ...[
                  const SectionHeader(title: 'Photos', motif: Motif.lotus),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82),
                    itemCount: photos.length,
                    itemBuilder: (context, i) => _PhotoTile(visit: photos[i]),
                  ),
                ],
              ],
            ),
    );
  }

  /// The editor. With [existing] it edits; with [visit] it is prefilled for
  /// that visit's temple and date.
  static Future<void> write(BuildContext context, {MemoryEntry? existing, Visit? visit}) async {
    final ctl = context.read<MemoriesController>();
    final title = TextEditingController(text: existing?.title);
    final body = TextEditingController(text: existing?.body);
    var date = existing?.happenedOn ?? visit?.visitedAt ?? DateTime.now();
    var private = existing?.isPrivate ?? true;
    TempleSummary? temple = visit != null ? SampleData.bySlug(visit.templeSlug) : null;
    var templeName = existing?.templeName ?? visit?.templeName;
    var templeSlug = existing?.templeSlug ?? visit?.templeSlug;
    var templeId = existing?.templeId ?? visit?.templeId ?? temple?.id;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(existing == null ? 'Write a memory' : 'Edit memory', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Your own words about a visit. Private unless you choose otherwise.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title (optional)')),
                const SizedBox(height: 10),
                TextField(controller: body, maxLines: 6, autofocus: existing == null, decoration: const InputDecoration(labelText: 'What you want to remember')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: existing != null
                            ? null
                            : () async {
                                final picked = await Navigator.of(context).push<TempleSummary>(MaterialPageRoute(builder: (_) => const SearchScreen(picker: true, title: 'Which temple?')));
                                if (picked != null) {
                                  setSheet(() {
                                    templeName = picked.name;
                                    templeSlug = picked.slug;
                                    templeId = picked.id;
                                  });
                                }
                              },
                        icon: const Icon(Icons.temple_hindu_rounded, size: 16),
                        label: Text(templeName?.split(',').first ?? 'Temple (optional)', maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final p = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(1950), lastDate: DateTime.now());
                        if (p != null) setSheet(() => date = p);
                      },
                      icon: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: Text('${date.day}/${date.month}/${date.year}'),
                    ),
                  ],
                ),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Keep private'), subtitle: const Text('Only you can read it'), value: private, onChanged: (v) => setSheet(() => private = v)),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(S.of(context)('save'))),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || body.text.trim().isEmpty) return;
    if (existing == null) {
      await ctl.add(title: title.text.trim().isEmpty ? null : title.text.trim(), body: body.text.trim(), happenedOn: date, templeSlug: templeSlug, templeName: templeName, templeId: templeId, visitKey: visit?.localKey, isPrivate: private);
    } else {
      await ctl.update(existing.copyWith(title: title.text.trim().isEmpty ? null : title.text.trim(), body: body.text.trim(), happenedOn: date, isPrivate: private));
    }
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.memory});

  final MemoryEntry memory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = DayTheme.forDeity(SampleData.bySlug(memory.templeSlug ?? '')?.deity?.slug);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => MemoriesScreen.write(context, existing: memory),
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(title: const Text('Delete this memory?'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete'))]),
          );
          if (ok == true && context.mounted) await context.read<MemoriesController>().remove(memory);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MotifIcon(day.motif, size: 18, color: day.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(memory.title ?? memory.templeName ?? 'A memory', style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif'))),
                  Icon(memory.isPrivate ? Icons.lock_rounded : Icons.public_rounded, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Icon(memory.remoteId != null ? Icons.cloud_done_rounded : Icons.cloud_upload_outlined, size: 14, color: memory.remoteId != null ? Palette.tulsi : theme.colorScheme.outline),
                ],
              ),
              const SizedBox(height: 6),
              Text(memory.body, maxLines: 6, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
              const SizedBox(height: 6),
              Text([if (memory.templeName != null && memory.title != null) memory.templeName!, '${memory.happenedOn.day}/${memory.happenedOn.month}/${memory.happenedOn.year}'].join(' · '), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.65))),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    final day = DayTheme.forDeity(visit.deitySlug);
    final remote = visit.remotePhoto;
    Widget image;
    if (visit.photoPath != null && !kIsWeb) {
      image = Image.file(File(visit.photoPath!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => remote?.originalUrl != null ? AppImage(remote!.originalUrl!, placeholder: TempleImage(deitySlug: visit.deitySlug)) : TempleImage(deitySlug: visit.deitySlug));
    } else if (remote?.originalUrl != null) {
      image = AppImage(remote!.originalUrl!, placeholder: TempleImage(deitySlug: visit.deitySlug), decodeWidth: 600);
    } else {
      image = TempleImage(deitySlug: visit.deitySlug);
    }
    return GestureDetector(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PhotoStampScreen(visit: visit))),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
            if (remote != null)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                  child: Text(remote.statusLabel ?? remote.status ?? 'uploaded', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                ),
              ),
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
