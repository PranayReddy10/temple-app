import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/brand.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/submissions_controller.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_widgets.dart';

/// Community contributions: corrections and new temples, kept on the device
/// and sent to the editors by email until the submissions API lands.
class SubmissionsScreen extends StatelessWidget {
  const SubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<SubmissionsController>();
    return Scaffold(
      appBar: AppBar(title: Text(s('submissions'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => submit(context), icon: const Icon(Icons.add_location_alt_rounded), label: Text(s('add_temple'))),
      body: ctl.all.isEmpty
          ? const EmptyShrine(motif: Motif.lotus, message: 'Know a temple we are missing, or a timing that changed? Suggest it from any temple page, or add a new temple here. Editors check every contribution against a source before it is published.')
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: ctl.all.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final sub = ctl.all[i];
                return Card(
                  child: ListTile(
                    leading: Icon(sub.kind == 'new_temple' ? Icons.add_location_alt_rounded : Icons.edit_note_rounded, color: theme.colorScheme.primary),
                    title: Text(sub.templeName, style: const TextStyle(fontFamily: 'NotoSerif')),
                    subtitle: Text('${sub.field}\n${sub.text}', maxLines: 3, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: sub.sent
                        ? const Tooltip(message: 'Sent to editors', child: Icon(Icons.mark_email_read_rounded, color: Palette.tulsi))
                        : IconButton(tooltip: 'Send to editors', icon: const Icon(Icons.send_rounded), onPressed: () => _send(context, sub)),
                    onLongPress: () => ctl.remove(sub.id),
                  ),
                );
              },
            ),
    );
  }

  static Future<void> _send(BuildContext context, Submission sub) async {
    final body = [
      'Kind: ${sub.kind}',
      'Temple: ${sub.templeName}${sub.templeSlug != null ? ' (${sub.templeSlug})' : ''}',
      'Field: ${sub.field}',
      '',
      sub.text,
      '',
      'Sent from ${Brand.name} app · ${sub.createdAt.toIso8601String()}',
    ].join('\n');
    final uri = Uri(scheme: 'mailto', path: Brand.supportEmail, queryParameters: {'subject': '[${Brand.name}] ${sub.kind == 'new_temple' ? 'New temple' : 'Correction'}: ${sub.templeName}', 'body': body});
    final ok = await launchUrl(uri);
    if (ok && context.mounted) await context.read<SubmissionsController>().markSent(sub.id);
  }

  /// Opens the form. With [temple] it is a correction; without, a new temple.
  static Future<void> submit(BuildContext context, {TempleSummary? temple}) async {
    final ctl = context.read<SubmissionsController>();
    final name = TextEditingController(text: temple?.name);
    final text = TextEditingController();
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
                Text('Editors verify every contribution against an official or primary source before it is published. Community submissions are never shown as official.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(controller: name, readOnly: temple != null, decoration: const InputDecoration(labelText: 'Temple name and place')),
                const SizedBox(height: 10),
                if (temple != null) Wrap(spacing: 8, runSpacing: 6, children: [for (final f in Submission.fields) ChoiceChip(label: Text(f), selected: field == f, onSelected: (_) => setSheet(() => field = f))]),
                const SizedBox(height: 10),
                TextField(controller: text, maxLines: 5, decoration: InputDecoration(labelText: temple == null ? 'Deity, location, timings, anything you know, and where it can be checked' : 'What should change, and where it can be checked')),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save submission')),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty || text.text.trim().isEmpty) return;
    final sub = await ctl.add(kind: temple == null ? 'new_temple' : 'correction', templeSlug: temple?.slug, templeName: name.text.trim(), field: temple == null ? 'New temple' : field, text: text.text.trim());
    if (!context.mounted) return;
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Saved'),
        content: const Text('Send it to the editors now by email? You can also send it later from My submissions.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Later')), FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send'))],
      ),
    );
    if (send == true && context.mounted) await _send(context, sub);
  }
}
