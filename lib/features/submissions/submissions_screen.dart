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

/// Help & support: requests about the app or the account, reports about a
/// temple record, and new-temple suggestions, all filed through `/support`.
///
/// Filing needs no account. A request written with no signal is kept and
/// sent when the device is next online; the reference the editors return
/// is the handle to quote, and their replies arrive in the thread.
class SubmissionsScreen extends StatelessWidget {
  const SubmissionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<SubmissionsController>();
    final sync = context.watch<SyncService>();
    final open = ctl.all.where((x) => x.isOpen).toList();
    final closed = ctl.all.where((x) => !x.isOpen).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(s('submissions')),
        actions: [IconButton(tooltip: 'Send pending and refresh', onPressed: sync.isFlushing ? null : () => sync.sync(), icon: sync.isFlushing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.sync_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => newRequest(context), icon: const Icon(Icons.support_agent_rounded), label: Text(s('new_request'))),
      body: ctl.all.isEmpty
          ? EmptyShrine(
              motif: Motif.lotus,
              message: 'Something wrong with a temple record, your account, or the app? Send a request and the editors reply here. Reports about a temple can also be filed from its page.',
              action: Wrap(spacing: 8, children: [OutlinedButton(onPressed: () => newRequest(context), child: Text(s('new_request'))), OutlinedButton(onPressed: () => submit(context), child: Text(s('add_temple')))]),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              children: [
                if (ctl.pending.isNotEmpty)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    color: Palette.saffron.withValues(alpha: 0.12),
                    child: ListTile(
                      leading: sync.isFlushing ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.schedule_send_rounded, color: Palette.saffron),
                      title: Text(sync.isFlushing ? 'Sending…' : '${ctl.pending.length} not sent yet'),
                      subtitle: Text(ctl.pending.any((p) => p.sendError != null) ? 'The server refused one. Open it to see why.' : 'They go as soon as the app is online.', style: theme.textTheme.bodySmall),
                      trailing: TextButton(onPressed: sync.isFlushing ? null : () => sync.sync(), child: const Text('Send now')),
                    ),
                  ),
                if (open.isNotEmpty) const SectionHeader(title: 'Open', motif: Motif.diya),
                for (final sub in open) _TicketCard(sub: sub),
                if (closed.isNotEmpty) const SectionHeader(title: 'Answered', motif: Motif.bell),
                for (final sub in closed) _TicketCard(sub: sub),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: () => submit(context), icon: const Icon(Icons.add_location_alt_rounded), label: Text(s('add_temple'))),
              ],
            ),
    );
  }

  /// A request about the app or the account.
  static Future<void> newRequest(BuildContext context) async {
    final ctl = context.read<SubmissionsController>();
    final auth = context.read<AuthController>();
    final subject = TextEditingController();
    final text = TextEditingController();
    final who = TextEditingController(text: auth.devotee?.name);
    final email = TextEditingController(text: auth.devotee?.email);
    var category = 'app_problem';
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
                Text(S.of(context)('new_request'), style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [for (final c in Submission.categories.where((c) => c.$1 != 'wrong_information' && c.$1 != 'duplicate' && c.$1 != 'inappropriate_content')) ChoiceChip(label: Text(c.$2), selected: category == c.$1, onSelected: (_) => setSheet(() => category = c.$1))],
                ),
                const SizedBox(height: 4),
                Text(Submission.categories.firstWhere((c) => c.$1 == category).$3, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 12),
                TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
                const SizedBox(height: 10),
                TextField(controller: text, maxLines: 5, decoration: const InputDecoration(labelText: 'What happened, or what you need')),
                if (!auth.isSignedIn) ...[
                  const SizedBox(height: 10),
                  TextField(controller: who, decoration: const InputDecoration(labelText: 'Your name')),
                  const SizedBox(height: 10),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email, so we can reply (optional)')),
                ],
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send')),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    if (subject.text.trim().isEmpty || text.text.trim().isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a subject and a few words about what happened, then send.')));
      return;
    }
    await ctl.add(kind: 'support', templeName: '', field: Submission.categories.firstWhere((c) => c.$1 == category).$2, text: text.text.trim(), category: category, subject: subject.text.trim(), reporterName: who.text.trim().isEmpty ? null : who.text.trim(), reporterEmail: email.text.trim().isEmpty ? null : email.text.trim());
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending. Replies appear in Help & support.')));
  }

  /// A report about a temple record, or a new-temple suggestion.
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
                Text('Editors verify every report against an official or primary source before anything is published.', style: Theme.of(context).textTheme.bodySmall),
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
    if (ok != true) return;
    if (name.text.trim().isEmpty || text.text.trim().isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add the temple and what should change, then send.')));
      return;
    }
    await ctl.add(kind: temple == null ? 'new_temple' : 'correction', templeSlug: temple?.slug, templeId: temple?.id, templeName: name.text.trim(), field: temple == null ? 'New temple' : field, text: text.text.trim(), reporterName: who.text.trim().isEmpty ? null : who.text.trim(), reporterEmail: email.text.trim().isEmpty ? null : email.text.trim());
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved. It goes to the editors as soon as the app is online.')));
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.sub});

  final Submission sub;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = switch (sub.kind) { 'new_temple' => Icons.add_location_alt_rounded, 'correction' => Icons.flag_rounded, _ => Icons.support_agent_rounded };
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(sub.subject, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'NotoSerif')),
        subtitle: Text(
          [if (sub.reference != null) sub.reference!, sub.sent ? (sub.statusLabel ?? 'Sent') : (sub.sendError != null ? 'Not sent' : 'Waiting to send'), if (sub.answered) 'Answered'].join(' · '),
          style: theme.textTheme.bodySmall?.copyWith(color: sub.sendError != null && !sub.sent ? Palette.kumkum : null),
        ),
        trailing: Icon(sub.answered ? Icons.mark_email_read_rounded : sub.sent ? Icons.chevron_right_rounded : sub.sendError != null ? Icons.error_outline_rounded : Icons.schedule_send_rounded, color: sub.answered ? Palette.tulsi : sub.sendError != null && !sub.sent ? Palette.kumkum : null),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => TicketScreen(id: sub.id))),
      ),
    );
  }
}

/// One ticket as a thread: what was sent, the editors' replies, and a box
/// to reply. Replying reopens a resolved ticket, as on the server.
class TicketScreen extends StatefulWidget {
  const TicketScreen({super.key, required this.id});

  final String id;

  @override
  State<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends State<TicketScreen> {
  final _reply = TextEditingController();

  @override
  void dispose() {
    _reply.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<SubmissionsController>();
    final auth = context.watch<AuthController>();
    final sync = context.watch<SyncService>();
    final sub = ctl.byId(widget.id);
    if (sub == null) return Scaffold(appBar: AppBar(), body: const EmptyShrine(motif: Motif.lotus, message: 'This request was removed.'));
    final canReply = sub.reference != null && auth.isSignedIn;
    return Scaffold(
      appBar: AppBar(
        title: Text(sub.reference ?? 'Request'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                await ctl.remove(sub.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
            itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Remove from this device'))],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                Text(sub.subject, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Chip(label: Text(sub.field.isEmpty ? sub.category : sub.field), visualDensity: VisualDensity.compact),
                    Chip(label: Text(sub.sent ? (sub.statusLabel ?? 'Sent') : 'Waiting to send'), visualDensity: VisualDensity.compact, backgroundColor: sub.answered ? Palette.tulsi.withValues(alpha: 0.15) : null),
                    if (sub.templeName.isNotEmpty) Chip(avatar: const Icon(Icons.temple_hindu_rounded, size: 14), label: Text(sub.templeName, maxLines: 1, overflow: TextOverflow.ellipsis), visualDensity: VisualDensity.compact),
                  ],
                ),
                const SizedBox(height: 14),
                _Bubble(body: sub.text, author: sub.reporterName ?? auth.devotee?.name ?? 'You', mine: true, when: sub.createdAt.toIso8601String()),
                for (final m in sub.replies) _Bubble(body: m.body, author: m.author ?? (m.fromStaff ? 'Editors' : 'You'), mine: !m.fromStaff, when: m.createdAt),
                if (sub.resolution != null)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Palette.tulsi.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16), border: Border.all(color: Palette.tulsi.withValues(alpha: 0.5))),
                    child: Row(children: [const Icon(Icons.verified_rounded, color: Palette.tulsi), const SizedBox(width: 10), Expanded(child: Text('Resolved: ${sub.resolution}', style: theme.textTheme.bodyMedium))]),
                  ),
                if (!sub.sent)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: (sub.sendError != null ? Palette.kumkum : Palette.saffron).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: (sub.sendError != null ? Palette.kumkum : Palette.saffron).withValues(alpha: 0.4))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(sub.sendError != null ? 'Not sent: ${sub.sendError}' : 'Kept on this device. It goes the moment the app is online.', style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: sync.isFlushing ? null : () => sync.resendSupport(sub.id),
                          icon: sync.isFlushing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
                          label: Text(sync.isFlushing ? 'Sending…' : 'Send now'),
                        ),
                      ],
                    ),
                  ),
                if (sub.sent && !auth.isSignedIn) Padding(padding: const EdgeInsets.only(top: 12), child: Text('Sign in with the account this was filed from to see replies here and answer them. Quote ${sub.reference} in any email.', style: theme.textTheme.bodySmall)),
              ],
            ),
          ),
          if (canReply)
            Container(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 12),
              decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerHighest, border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant))),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _reply, minLines: 1, maxLines: 4, decoration: InputDecoration(hintText: s('reply')))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: () async {
                      final body = _reply.text.trim();
                      if (body.isEmpty) return;
                      _reply.clear();
                      await ctl.reply(sub, body, author: auth.devotee?.name ?? 'You');
                    },
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.body, required this.author, required this.mine, this.when});

  final String body;
  final String author;
  final bool mine;
  final String? when;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = when == null ? '' : (DateTime.tryParse(when!)?.toLocal().toString().substring(0, 16) ?? '');
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: 10, left: mine ? 40 : 0, right: mine ? 0 : 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? theme.colorScheme.primary.withValues(alpha: 0.14) : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$author${date.isEmpty ? '' : ' · $date'}', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
            const SizedBox(height: 4),
            SelectableText(body, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
          ],
        ),
      ),
    );
  }
}
