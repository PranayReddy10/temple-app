import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/submissions_controller.dart';
import '../../core/state/sync_service.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_widgets.dart';

/// Reports and suggestions, filed through `/support`. Filing needs no
/// account; a report written with no signal is sent when the device is next
/// online, and the reference the editors return is shown once it is.
class SubmissionsScreen extends StatelessWidget {
  const SubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<SubmissionsController>();
    final sync = context.watch<SyncService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(s('submissions')),
        actions: [IconButton(tooltip: 'Send pending and refresh', onPressed: sync.isFlushing ? null : () => sync.sync(), icon: sync.isFlushing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => submit(context), icon: const Icon(Icons.add_location_alt_rounded), label: Text(s('add_temple'))),
      body: ctl.all.isEmpty
          ? const EmptyShrine(motif: Motif.lotus, message: 'Know a temple we are missing, or a timing that changed? Report it from any temple page, or suggest a new temple here. Editors check every report against a source before anything is published.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: ctl.all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final sub = ctl.all[i];
                final answered = sub.replies.any((m) => m.fromStaff) || sub.resolution != null;
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        leading: Icon(sub.kind == 'new_temple' ? Icons.add_location_alt_rounded : Icons.flag_rounded, color: theme.colorScheme.primary),
                        title: Text(sub.subject, style: const TextStyle(fontFamily: 'NotoSerif')),
                        subtitle: Text(sub.text, maxLines: 3, overflow: TextOverflow.ellipsis),
                        trailing: sub.sent
                            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(answered ? Icons.mark_email_read_rounded : Icons.check_circle_outline_rounded, color: answered ? Palette.tulsi : theme.colorScheme.primary), Text(sub.reference!, style: theme.textTheme.labelSmall)])
                            : const Tooltip(message: 'Waiting to send', child: Icon(Icons.schedule_send_rounded)),
                        onLongPress: () => ctl.remove(sub.id),
                      ),
                      if (sub.statusLabel != null || !sub.sent)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                          child: Text(sub.sent ? 'Status: ${sub.statusLabel}' : 'Kept on this device. It is sent the next time the app is online.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                        ),
                      if (sub.resolution != null)
                        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text('Editors: ${sub.resolution}', style: theme.textTheme.bodySmall?.copyWith(color: Palette.tulsi))),
                      for (final m in sub.replies.where((m) => m.fromStaff))
                        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 10), child: Text('${m.author ?? 'Editors'}: ${m.body}', style: theme.textTheme.bodySmall)),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /// Opens the form. With [temple] it is a report about that record;
  /// without, a suggestion for a temple we do not have.
  static Future<void> submit(BuildContext context, {TempleSummary? temple}) async {
    final ctl = context.read<SubmissionsController>();
    final auth = context.read<AuthController>();
    final name = TextEditingController(text: temple?.name);
    final text = TextEditingController();
    final who = TextEditingController(text: auth.devotee?.name);
    final email = TextEditingController(text: auth.devotee?.email);
    var field = temple == null ? 'Other' : Submission.fields.first;
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
                Text(temple == null ? S.of(context)('add_temple') : S.of(context)('suggest_edit'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Editors verify every report against an official or primary source before anything is published. Community reports are never shown as official.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(controller: name, readOnly: temple != null, decoration: const InputDecoration(labelText: 'Temple name and place')),
                const SizedBox(height: 10),
                if (temple != null) Wrap(spacing: 8, runSpacing: 6, children: [for (final f in Submission.fields) ChoiceChip(label: Text(f), selected: field == f, onSelected: (_) => setSheet(() => field = f))]),
                const SizedBox(height: 10),
                TextField(controller: text, maxLines: 5, decoration: InputDecoration(labelText: temple == null ? 'Deity, location, timings, anything you know, and where it can be checked' : 'What is wrong, what it should say, and where it can be checked')),
                if (!auth.isSignedIn) ...[
                  const SizedBox(height: 10),
                  TextField(controller: who, decoration: const InputDecoration(labelText: 'Your name')),
                  const SizedBox(height: 10),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email, if you want a reply (optional)')),
                ],
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send to editors')),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || text.text.trim().isEmpty) return;
    await ctl.add(
      kind: temple == null ? 'new_temple' : 'correction',
      templeSlug: temple?.slug,
      templeId: temple?.id,
      templeName: name.text.trim(),
      field: temple == null ? 'New temple' : field,
      text: text.text.trim(),
      reporterName: who.text.trim().isEmpty ? null : who.text.trim(),
      reporterEmail: email.text.trim().isEmpty ? null : email.text.trim(),
    );
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved. It goes to the editors as soon as the app is online.')));
  }
}
