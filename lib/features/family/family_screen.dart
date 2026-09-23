import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/family_controller.dart';
import '../../core/state/passport_controller.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_widgets.dart';
import '../passport/stamp_widget.dart';

/// Family Passport: everyone who travels with the devotee, each with their
/// own stamp count and the stamps they shared.
class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key, this.embedded = false});

  /// Inside the Passport tabs there is no app bar of its own.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final family = context.watch<FamilyController>();
    final passport = context.watch<PassportController>();
    final body = family.members.isEmpty
          ? EmptyShrine(motif: Motif.kalasha, message: 'Add the people who travel with you. Each check-in can name who came, and everyone collects stamps.', action: FilledButton.icon(onPressed: () => editMember(context), icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(s('add_member'))))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: family.members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final m = family.members[i];
                final stamps = passport.stampsFor(m.id);
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: MemberAvatar(member: m, size: 46),
                        title: Text(m.name, style: const TextStyle(fontFamily: 'NotoSerif')),
                        subtitle: Text('${m.relation} · ${stamps.length} ${stamps.length == 1 ? 'stamp' : 'stamps'}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => v == 'edit' ? editMember(context, m) : family.remove(m.id),
                          itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'remove', child: Text('Remove'))],
                        ),
                      ),
                      if (stamps.isNotEmpty)
                        SizedBox(
                          height: 110,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            itemCount: stamps.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 4),
                            itemBuilder: (context, j) => StampWidget(visit: stamps[j], size: 96),
                          ),
                        )
                      else
                        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 14), child: Text('No stamps yet. Tick ${m.name} at your next check-in.', style: theme.textTheme.bodySmall)),
                    ],
                  ),
                );
              },
            );
    if (embedded) {
      return Stack(
        children: [
          body,
          if (family.members.isNotEmpty) Positioned(right: 16, bottom: 16, child: FloatingActionButton.small(heroTag: 'family-add', onPressed: () => editMember(context), child: const Icon(Icons.person_add_alt_1_rounded))),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(s('family_passport'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => editMember(context), icon: const Icon(Icons.person_add_alt_1_rounded), label: Text(s('add_member'))),
      body: body,
    );
  }

  static Future<void> editMember(BuildContext context, [FamilyMember? existing]) async {
    final family = context.read<FamilyController>();
    final name = TextEditingController(text: existing?.name);
    var relation = existing?.relation ?? FamilyController.relations.first;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? S.of(context)('add_member') : 'Edit ${existing.name}', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(controller: name, autofocus: true, decoration: InputDecoration(labelText: S.of(context)('name'))),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 6, children: [for (final r in FamilyController.relations) ChoiceChip(label: Text(r), selected: relation == r, onSelected: (_) => setSheet(() => relation = r))]),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(S.of(context)('save'))),
            ],
          ),
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    if (existing == null) {
      await family.add(name.text.trim(), relation);
    } else {
      await family.update(existing.copyWith(name: name.text.trim(), relation: relation));
    }
  }
}

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.member, this.size = 40, this.selected = false});

  final FamilyMember member;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: member.color,
          border: Border.all(color: selected ? Palette.gold : Colors.transparent, width: 3),
          boxShadow: [BoxShadow(color: member.color.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Center(child: Text(member.initials, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36))),
      );
}
