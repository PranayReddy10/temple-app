import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_client.dart';
import '../../core/api/seva_repository.dart';
import '../../core/brand.dart';
import '../../core/models/seva.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/state/location_controller.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/temple_widgets.dart';
import '../auth/auth_screen.dart';
import '../media/in_app_browser.dart';
import 'raise_drive_screen.dart';
import 'seva_widgets.dart';

/// One seva drive: the place before (and after), the plan, who is coming, and
/// — once staff have verified the work — how to donate.
///
/// The organiser sees the same page with their tools on it: add after-photos,
/// mark it done, see volunteers, confirm donations, change the arrangements.
class SevaDriveScreen extends StatefulWidget {
  const SevaDriveScreen({super.key, required this.driveId, this.initial});

  final int driveId;
  final SevaDrive? initial;

  @override
  State<SevaDriveScreen> createState() => _SevaDriveScreenState();
}

class _SevaDriveScreenState extends State<SevaDriveScreen> {
  late final SevaRepository _repo = SevaRepository(context.read<ApiClient>());
  late SevaDrive? _drive = widget.initial;
  String? _error;
  bool _busy = false;

  /// Which photographs the gallery shows.
  String _stage = 'before';

  /// Who is coming, loaded for the organiser only.
  List<SevaVolunteer>? _volunteers;

  @override
  void initState() {
    super.initState();
    if (widget.initial?.isDone == true && widget.initial!.after.isNotEmpty) _stage = 'after';
    _reload();
  }

  Future<void> _reload() async {
    try {
      final d = await _repo.show(widget.driveId);
      if (!mounted) return;
      setState(() {
        _drive = d;
        _error = null;
        if (d.after.isEmpty) _stage = 'before';
      });
      if (d.isOrganiser && d.signups > 0) {
        final v = await _repo.volunteers(d.id);
        if (mounted) setState(() => _volunteers = v);
      } else if (mounted && _volunteers != null) {
        setState(() => _volunteers = null);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e is ApiException ? e.message : 'Could not load this drive.');
    }
  }

  /// Runs a change, shows what went wrong in words, and reloads.
  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      await _reload();
      if (done != null) _toast(done);
    } catch (e) {
      _toast(_explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _explain(Object e) {
    if (e is ApiException) return e.errors.values.expand((v) => v).firstOrNull ?? e.message;
    return 'Could not reach the server. Try again when you are online.';
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<bool> _ensureSignedIn() async {
    if (context.read<AuthController>().isSignedIn) return true;
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
    if (!mounted) return false;
    final ok = context.read<AuthController>().isSignedIn;
    if (ok) await _reload();
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    final d = _drive;
    if (d == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null ? const DiyaLoader() : EmptyShrine(motif: Motif.diya, message: _error!, action: OutlinedButton(onPressed: _reload, child: const Text('Try again'))),
      );
    }
    final theme = Theme.of(context);
    final media = (_stage == 'after' ? d.after : d.before);
    return Scaffold(
      bottomNavigationBar: _bottomBar(d),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 320,
              backgroundColor: Palette.deep,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: 'Share',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: () => Share.share('${d.title}\nby ${d.organiserName ?? Brand.name}\n${d.where} · ${sevaDateRange(d)}\nJoin hands on ${Brand.name}.'),
                ),
                if (!d.isOrganiser)
                  PopupMenuButton<String>(
                    tooltip: 'More',
                    onSelected: (v) {
                      if (v == 'report') _report(d);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'report', child: ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.flag_rounded, color: Palette.kumkum), title: Text('Report this drive'))),
                    ],
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _Gallery(media: media, cause: d.cause.value, stage: _stage),
              ),
              bottom: d.after.isEmpty
                  ? null
                  : PreferredSize(
                      preferredSize: const Size.fromHeight(52),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: SegmentedButton<String>(
                          style: SegmentedButton.styleFrom(backgroundColor: Colors.black45, foregroundColor: Colors.white, selectedBackgroundColor: Palette.gold, selectedForegroundColor: Palette.deep),
                          segments: [
                            ButtonSegment(value: 'before', label: Text('Before · ${d.before.length}')),
                            ButtonSegment(value: 'after', label: Text('After · ${d.after.length}')),
                          ],
                          selected: {_stage},
                          onSelectionChanged: (s) => setState(() => _stage = s.first),
                        ),
                      ),
                    ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        SevaPill(text: d.cause.label, color: Palette.deep, icon: sevaCauseIcon(d.cause.value)),
                        SevaPill(text: d.statusLabel, color: sevaStatusColor(d.status), icon: d.isVerified ? Icons.verified_rounded : null),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(d.title, style: theme.textTheme.headlineSmall?.copyWith(fontFamily: 'NotoSerif', fontWeight: FontWeight.w700, height: 1.2)),
                    const SizedBox(height: 14),
                    _OrganiserAndDates(drive: d),
                    const SizedBox(height: 14),
                    _Stats(drive: d),
                    if (d.isMisleading) _MisleadingBanner(note: d.misleadingNote),
                    const SizedBox(height: 20),
                    SevaProgressSteps(drive: d),
                    if (d.isOrganiser) _OrganiserNotice(drive: d),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(child: _facts(d)),
            if (d.donations.open) SliverToBoxAdapter(child: _DonateCard(drive: d, onReport: () => _reportDonation(d))),
            if (d.completionNote != null) SliverToBoxAdapter(child: _Prose(title: 'What was done', icon: Icons.task_alt_rounded, text: d.completionNote!, color: Palette.tulsi)),
            SliverToBoxAdapter(child: _Prose(title: 'The place now', icon: Icons.report_rounded, text: d.problem, color: Palette.kumkum)),
            SliverToBoxAdapter(child: _Prose(title: 'The plan', icon: Icons.checklist_rounded, text: d.plan, color: Palette.saffron)),
            if (d.whatToBring != null && d.whatToBring!.trim().isNotEmpty) SliverToBoxAdapter(child: _Bring(text: d.whatToBring!)),
            if (d.isOrganiser && (_volunteers?.isNotEmpty ?? false)) SliverToBoxAdapter(child: _WhoIsComing(drive: d, volunteers: _volunteers!)),
            if (d.isOrganiser) SliverToBoxAdapter(child: _organiserTools(d)),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  // --- The facts: when, where, who is coming ---

  Widget _facts(SevaDrive d) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(20), border: Border.all(color: theme.colorScheme.outlineVariant)),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.event_rounded, color: Palette.saffron),
              title: Text(sevaDateRange(d), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(d.endsAt == null ? 'One day' : (d.isMultiDay ? 'From ${sevaDate(d.startsAt)}\nTo ${sevaDate(d.endsAt!)}' : 'One day')),
              isThreeLine: d.isMultiDay,
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            ListTile(
              leading: const Icon(Icons.place_rounded, color: Palette.kumkum),
              title: Text(d.where, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text([
                if (context.watch<LocationController?>()?.labelTo(d.latitude, d.longitude) case final away?) '📍 $away',
                if (d.address != null) d.address!,
                if (d.meetingPoint != null) 'Meet: ${d.meetingPoint}',
                if (d.templeName != null) 'At ${d.templeName}',
              ].join('\n').ifEmpty('No address given')),
              isThreeLine: d.address != null || d.meetingPoint != null || d.hasCoordinates,
              trailing: IconButton.filledTonal(
                tooltip: 'Directions',
                icon: const Icon(Icons.directions_rounded),
                onPressed: () {
                  final dest = d.hasCoordinates ? '${d.latitude},${d.longitude}' : Uri.encodeComponent([d.placeName, d.address, d.city, d.state].whereType<String>().join(', '));
                  launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$dest'), mode: LaunchMode.externalApplication);
                },
              ),
            ),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.groups_rounded, color: Palette.tulsi),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          d.volunteersNeeded == null ? '${d.volunteersJoined} volunteers joining' : '${d.volunteersJoined} of ${d.volunteersNeeded} volunteers',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (d.isOrganiser && d.signups > 0) TextButton(onPressed: () => _showVolunteers(d), child: const Text('See who')),
                    ],
                  ),
                  if (d.volunteerProgress != null) ...[
                    const SizedBox(height: 10),
                    ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: d.volunteerProgress, minHeight: 8, color: Palette.tulsi, backgroundColor: Palette.tulsi.withValues(alpha: 0.15))),
                  ],
                ],
              ),
            ),
            if (d.contactPhone != null) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.call_rounded, color: Palette.ash),
                title: Text(d.contactPhone!),
                subtitle: Text(d.isOrganiser ? 'Shown to volunteers who join' : 'The organiser, for volunteers'),
                trailing: IconButton(icon: const Icon(Icons.phone_forwarded_rounded), onPressed: () => launchUrl(Uri(scheme: 'tel', path: d.contactPhone!.replaceAll(' ', '')))),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- Bottom bar: join, leave ---

  Widget? _bottomBar(SevaDrive d) {
    if (d.isOrganiser) return null;
    final Widget button;
    if (d.hasJoined && d.isOpen) {
      button = OutlinedButton.icon(onPressed: _busy ? null : () => _leave(d), icon: const Icon(Icons.check_circle_rounded, color: Palette.tulsi), label: const Text("You're going · Can't make it?"));
    } else if (d.isOpen) {
      button = FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Palette.saffron, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: _busy ? null : () => _join(d),
        icon: const Icon(Icons.volunteer_activism_rounded),
        label: const Text('Join hands'),
      );
    } else if (d.donations.open) {
      button = FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: Palette.tulsi, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
        onPressed: d.donations.upiLink == null ? null : () => _payUpi(d),
        icon: const Icon(Icons.currency_rupee_rounded),
        label: const Text('Donate by UPI'),
      );
    } else {
      return null;
    }
    return SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 12), child: SizedBox(width: double.infinity, child: button)));
  }

  Future<void> _join(SevaDrive d) async {
    if (!await _ensureSignedIn()) return;
    var party = 1;
    final note = TextEditingController();
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Join this drive', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('${sevaDate(d.startsAt)} · ${d.where}', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Expanded(child: Text('How many of you are coming?')),
                  IconButton.outlined(onPressed: party > 1 ? () => setSheet(() => party--) : null, icon: const Icon(Icons.remove_rounded)),
                  SizedBox(width: 40, child: Text('$party', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge)),
                  IconButton.outlined(onPressed: party < 20 ? () => setSheet(() => party++) : null, icon: const Icon(Icons.add_rounded)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: note, maxLength: 255, decoration: const InputDecoration(labelText: 'A note for the organiser (optional)', hintText: 'I can bring a ladder and two brooms')),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text("I'll be there"))),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    await _run(() => _repo.join(d.id, partySize: party, note: note.text.trim()), done: 'You have joined. The organiser\'s number is now on this page.');
  }

  Future<void> _leave(SevaDrive d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this drive?'),
        content: const Text('The organiser will see one fewer person coming.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Stay')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Leave'))],
      ),
    );
    if (ok == true) await _run(() => _repo.leave(d.id), done: 'You have left the drive.');
  }

  // --- Donations ---

  Future<void> _payUpi(SevaDrive d) async {
    final link = d.donations.upiLink;
    if (link == null) return;
    final ok = await launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok) {
      await Clipboard.setData(ClipboardData(text: d.donations.upiId ?? ''));
      _toast('No UPI app answered. The UPI ID is copied — paste it in your payment app.');
    }
  }

  Future<void> _reportDonation(SevaDrive d) async {
    if (!await _ensureSignedIn()) return;
    final amount = TextEditingController();
    final ref = TextEditingController();
    final message = TextEditingController();
    var anonymous = false;
    if (!mounted) return;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('I sent a donation', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('The money went straight to the organiser. Tell them so they can confirm it — confirmed amounts count towards the goal.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 16),
                TextField(controller: amount, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
                const SizedBox(height: 10),
                TextField(controller: ref, decoration: const InputDecoration(labelText: 'UPI reference number (optional)', helperText: 'The 12-digit number your UPI app shows')),
                const SizedBox(height: 10),
                TextField(controller: message, maxLength: 255, decoration: const InputDecoration(labelText: 'A message (optional)')),
                SwitchListTile(contentPadding: EdgeInsets.zero, value: anonymous, onChanged: (v) => setSheet(() => anonymous = v), title: const Text('Keep my name private')),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send to the organiser'))),
              ],
            ),
          ),
        ),
      ),
    );
    final value = int.tryParse(amount.text.trim());
    if (ok != true) return;
    if (value == null || value < 1) {
      _toast('Enter the amount you sent.');
      return;
    }
    await _run(() => _repo.reportDonation(d.id, amount: value, upiRef: ref.text.trim(), message: message.text.trim(), anonymous: anonymous), done: 'Thank you. The organiser will confirm it.');
  }

  // --- Reporting ---

  Future<void> _report(SevaDrive d) async {
    final auth = context.read<AuthController>();
    var reason = 'misleading';
    final details = TextEditingController();
    final name = TextEditingController(text: auth.devotee?.name);
    final email = TextEditingController(text: auth.devotee?.email);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Report this drive', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('The team reviews every report and can mark a drive misleading or take it down. The organiser is not told who reported it.', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final r in SevaRepository.reportReasons)
                      ChoiceChip(label: Text(r.$2), selected: reason == r.$1, onSelected: (_) => setSheet(() => reason = r.$1)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: details, maxLines: 4, maxLength: 2000, decoration: const InputDecoration(labelText: 'What is wrong?', hintText: 'The after photos are from a different temple…', alignLabelWithHint: true)),
                if (!auth.isSignedIn) ...[
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Your name')),
                  const SizedBox(height: 8),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email, so we can reply (optional)')),
                ],
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: Palette.kumkum), onPressed: () => Navigator.of(context).pop(true), icon: const Icon(Icons.flag_rounded), label: const Text('Send report'))),
              ],
            ),
          ),
        ),
      ),
    );
    if (ok != true) return;
    if (details.text.trim().length < 10) {
      _toast('Add a few words about what is wrong, so the team can check it.');
      return;
    }
    if (!auth.isSignedIn && name.text.trim().isEmpty) {
      _toast('Add your name, or sign in, to send a report.');
      return;
    }
    setState(() => _busy = true);
    try {
      final ref = await _repo.report(d, reason: reason, details: details.text.trim(), name: name.text.trim(), email: email.text.trim());
      _toast(ref == null ? 'Report sent. Thank you.' : 'Report sent — reference $ref. Replies appear in Help & support.');
    } catch (e) {
      _toast(_explain(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --- Organiser tools ---

  Widget _organiserTools(SevaDrive d) {
    final theme = Theme.of(context);
    final canAddAfter = (d.isOpen || d.isDone) && d.startsAt.isBefore(DateTime.now());
    final tools = <Widget>[
      if (d.canEdit) _Tool(icon: Icons.add_photo_alternate_rounded, label: 'Add before photos', onTap: () => _addMedia(d, 'before')),
      if (canAddAfter) _Tool(icon: Icons.photo_library_rounded, label: 'Add after photos', color: Palette.tulsi, onTap: () => _addMedia(d, 'after')),
      if (d.canComplete) _Tool(icon: Icons.task_alt_rounded, label: 'Mark as done', color: Palette.tulsi, onTap: () => _complete(d)),
      if (d.canEdit) _Tool(icon: Icons.edit_rounded, label: d.isOpen ? 'Change arrangements' : 'Edit drive', onTap: () => _edit(d)),
      if (d.signups > 0) _Tool(icon: Icons.groups_rounded, label: 'Volunteers (${d.signups})', onTap: () => _showVolunteers(d)),
      if (d.myUpiId != null) _Tool(icon: Icons.receipt_long_rounded, label: 'Donations', onTap: () => _showDonations(d)),
      if (d.isPending || d.isOpen || d.isRejected) _Tool(icon: Icons.cancel_rounded, label: 'Cancel drive', color: Palette.kumkum, onTap: () => _cancel(d)),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Palette.gold.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: Palette.gold.withValues(alpha: 0.4))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [const Icon(Icons.star_rounded, color: Palette.gold), const SizedBox(width: 8), Text('Your drive', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
            if (d.isOpen && !canAddAfter) Padding(padding: const EdgeInsets.only(top: 6), child: Text('After the drive, come back here to add the after photographs and mark it done.', style: theme.textTheme.bodySmall)),
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: tools),
            if (_busy) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Future<void> _addMedia(SevaDrive d, String stage) async {
    final upload = await pickSevaMedia(context, title: stage == 'after' ? 'After the drive' : 'Before the drive');
    if (upload == null || upload.isEmpty) return;
    await _run(() => _repo.addMedia(d.id, stage, upload), done: 'Added.');
    if (mounted && stage == 'after') setState(() => _stage = 'after');
  }

  Future<void> _complete(SevaDrive d) async {
    if (d.after.isEmpty) {
      _toast('Add at least one after photograph first, so the work can be verified.');
      return;
    }
    final note = TextEditingController();
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mark the drive as done', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('The team compares your before and after photographs and verifies the drive. Once verified, it gets a badge and your UPI ID is shown for donations.', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            TextField(controller: note, maxLines: 5, maxLength: 3000, decoration: const InputDecoration(labelText: 'What was done', hintText: '22 of us cleared the steps, removed 14 bags of plastic and washed the mandapam floor.')),
            const SizedBox(height: 8),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Send for verification'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (note.text.trim().length < 20) {
      _toast('Write a sentence or two about what was done.');
      return;
    }
    await _run(() => _repo.complete(d.id, note.text.trim()), done: 'Sent for verification.');
  }

  Future<void> _edit(SevaDrive d) async {
    final updated = await Navigator.of(context).push<SevaDrive>(MaterialPageRoute(builder: (_) => RaiseDriveScreen(existing: d)));
    if (updated != null && mounted) {
      setState(() => _drive = updated);
      _toast(d.isRejected ? 'Updated and sent back for review.' : 'Saved.');
    }
  }

  Future<void> _cancel(SevaDrive d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this drive?'),
        content: const Text('It stops being listed and volunteers can no longer join. This cannot be undone.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')), FilledButton(style: FilledButton.styleFrom(backgroundColor: Palette.kumkum), onPressed: () => Navigator.pop(context, true), child: const Text('Cancel drive'))],
      ),
    );
    if (ok == true) await _run(() => _repo.cancel(d.id), done: 'Drive cancelled.');
  }

  Future<void> _showVolunteers(SevaDrive d) async {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => FutureBuilder<List<SevaVolunteer>>(
        future: _repo.volunteers(d.id),
        builder: (context, snap) {
          if (!snap.hasData) return const SizedBox(height: 200, child: DiyaLoader());
          final list = snap.data!;
          return ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            children: [
              Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 8), child: Text('${d.volunteersJoined} people from ${list.length} sign-ups', style: Theme.of(context).textTheme.titleMedium)),
              for (final v in list)
                ListTile(
                  leading: CircleAvatar(child: Text((v.name ?? '').characters.firstOrNull?.toUpperCase() ?? '?')),
                  title: Text(v.name ?? 'A devotee'),
                  subtitle: v.note == null ? null : Text(v.note!),
                  trailing: v.partySize > 1 ? SevaPill(text: '+${v.partySize - 1}', color: Palette.saffron) : null,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDonations(SevaDrive d) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _DonationsSheet(repo: _repo, driveId: d.id),
    );
    _reload();
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

/// Pick photographs and optionally a video (or a link to one).
Future<SevaUpload?> pickSevaMedia(BuildContext context, {required String title}) async {
  final photos = <String>[];
  String? video;
  final link = TextEditingController();
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SevaMediaPicker(photos: photos, video: video, onChanged: (p, v) => setSheet(() => video = v), link: link),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Upload'))),
          ],
        ),
      ),
    ),
  );
  if (ok != true) return null;
  return SevaUpload(photos: photos, videoPath: video, videoUrl: link.text.trim());
}

/// Thumbnails of the photographs picked so far, and buttons to add more,
/// take one with the camera, add a video, or paste a link to one.
class SevaMediaPicker extends StatelessWidget {
  const SevaMediaPicker({super.key, required this.photos, required this.video, required this.onChanged, required this.link, this.max = 8});

  /// Mutated in place; [onChanged] is called after every change.
  final List<String> photos;
  final String? video;
  final void Function(List<String> photos, String? video) onChanged;
  final TextEditingController link;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Future<void> gallery() async {
      final picked = await ImagePicker().pickMultiImage(maxWidth: 2000, imageQuality: 85);
      photos.addAll(picked.map((x) => x.path).take(max - photos.length));
      onChanged(photos, video);
    }

    Future<void> camera() async {
      final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2000, imageQuality: 85);
      if (x != null && photos.length < max) photos.add(x.path);
      onChanged(photos, video);
    }

    Future<void> pickVideo() async {
      final x = await ImagePicker().pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 2));
      onChanged(photos, x?.path ?? video);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (photos.isNotEmpty)
          SizedBox(
            height: 88,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) => Stack(
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 88, height: 88, child: localImage(photos[i]))),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () {
                        photos.removeAt(i);
                        onChanged(photos, video);
                      },
                      child: const CircleAvatar(radius: 11, backgroundColor: Colors.black54, child: Icon(Icons.close_rounded, size: 14, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (photos.isNotEmpty) const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(onPressed: photos.length >= max ? null : gallery, icon: const Icon(Icons.photo_library_rounded), label: Text(photos.isEmpty ? 'Choose photos' : 'Add more (${photos.length}/$max)')),
            OutlinedButton.icon(onPressed: photos.length >= max ? null : camera, icon: const Icon(Icons.photo_camera_rounded), label: const Text('Camera')),
            OutlinedButton.icon(onPressed: pickVideo, icon: Icon(video == null ? Icons.videocam_rounded : Icons.check_circle_rounded, color: video == null ? null : Palette.tulsi), label: Text(video == null ? 'Add a video' : 'Video added')),
          ],
        ),
        const SizedBox(height: 10),
        TextField(controller: link, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Or a YouTube / Instagram link (optional)', prefixIcon: Icon(Icons.link_rounded))),
        const SizedBox(height: 4),
        Text('Videos up to 50 MB. A link uploads nothing and works on any connection.', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

class _Gallery extends StatefulWidget {
  const _Gallery({required this.media, required this.cause, required this.stage});

  final List<SevaMedia> media;
  final String cause;
  final String stage;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _page = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant _Gallery old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage && _page.hasClients) {
      _page.jumpToPage(0);
      _index = 0;
    }
  }

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.media.where((m) => m.url != null).toList();
    if (items.isEmpty) {
      return DecoratedBox(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.tulsi, Palette.deep])),
        child: Center(child: Icon(sevaCauseIcon(widget.cause), size: 96, color: Colors.white.withValues(alpha: 0.3))),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _page,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final m = items[i];
            if (m.isPhoto) return AppImage(m.url!);
            return InkWell(
              onTap: () => InAppBrowserScreen.open(context, AppImage.resolve(m.url!, context.read<ApiClient>().baseUrl), title: 'Video'),
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_circle_fill_rounded, size: 72, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(m.isLink ? 'Watch the video' : 'Play video', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.center, colors: [Color(0x88000000), Colors.transparent])))),
        Positioned(
          left: 16,
          bottom: 70,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
            child: Text('${widget.stage.toUpperCase()} · ${_index + 1}/${items.length}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
        ),
        if (items[_index].caption != null)
          Positioned(left: 16, right: 16, bottom: 96, child: Text(items[_index].caption!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 6)]))),
      ],
    );
  }
}

class _OrganiserNotice extends StatelessWidget {
  const _OrganiserNotice({required this.drive});

  final SevaDrive drive;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String text) = switch (drive.status) {
      'pending' => (Icons.hourglass_top_rounded, Palette.gold, 'Waiting for review. The team checks every drive before it is listed — usually within a day.'),
      'rejected' => (Icons.error_outline_rounded, Palette.kumkum, 'Not approved yet: ${drive.moderationNote ?? 'see the note from the team'}. Edit the drive and it goes back for review.'),
      'approved' => drive.moderationNote != null
          ? (Icons.info_outline_rounded, Palette.saffron, 'The team asked for more before verifying: ${drive.moderationNote}')
          : (Icons.campaign_rounded, Palette.tulsi, 'Live — volunteers can join. Share it to gather more hands.'),
      'completed' => (Icons.fact_check_rounded, Palette.ash, 'Sent for verification. Donations open once the team verifies your after photographs.'),
      'verified' => (Icons.verified_rounded, Palette.tulsi, drive.myUpiId == null ? 'Verified. Add a UPI ID from the web team if you need donations.' : 'Verified. Your UPI ID is shown for donations; confirm each one you receive.'),
      'blocked' => (Icons.shield_rounded, Palette.kumkum, 'Blocked by the team: ${drive.blockReason ?? 'no reason given'}. Nobody else can see it. Write to Help & support if you think this is a mistake.'),
      _ => (Icons.block_rounded, Palette.stone, 'This drive was cancelled.'),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.4))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Icon(icon, color: color), const SizedBox(width: 10), Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium))],
        ),
      ),
    );
  }
}

class _Prose extends StatelessWidget {
  const _Prose({required this.title, required this.icon, required this.text, required this.color});

  final String title;
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 3)), color: color.withValues(alpha: 0.05)),
            child: Text(text, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          ),
        ],
      ),
    );
  }
}

class _Bring extends StatelessWidget {
  const _Bring({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final items = text.split(RegExp(r'[,\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [const Icon(Icons.backpack_rounded, color: Palette.ash, size: 20), const SizedBox(width: 8), Text('Bring along', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final i in items) Chip(avatar: const Icon(Icons.check_rounded, size: 16), label: Text(i))]),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap, this.color});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ActionChip(
        avatar: Icon(icon, size: 18, color: color ?? Theme.of(context).colorScheme.primary),
        label: Text(label),
        onPressed: onTap,
      );
}

/// UPI ID, a QR any UPI app scans, a button that opens one, and the goal.
class _DonateCard extends StatelessWidget {
  const _DonateCard({required this.drive, required this.onReport});

  final SevaDrive drive;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final don = drive.donations;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.tulsi.withValues(alpha: 0.16), Palette.gold.withValues(alpha: 0.12)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Palette.tulsi.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: Palette.tulsi),
                const SizedBox(width: 8),
                Expanded(child: Text('Verified seva · support it', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              ],
            ),
            if (don.purpose != null) ...[const SizedBox(height: 6), Text(don.purpose!, style: theme.textTheme.bodyMedium)],
            if (don.goal != null) ...[
              const SizedBox(height: 12),
              Text('${rupees(don.raised ?? 0)} raised of ${rupees(don.goal!)}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: don.progress ?? 0, minHeight: 8, color: Palette.tulsi, backgroundColor: Colors.white.withValues(alpha: 0.5))),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (don.upiLink != null)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: QrImageView(data: don.upiLink!, size: 112, padding: EdgeInsets.zero),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pay to', style: theme.textTheme.labelSmall),
                      Text(don.upiName ?? drive.organiserName ?? '', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: don.upiId ?? ''));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UPI ID copied')));
                        },
                        child: Row(
                          children: [
                            Flexible(child: Text(don.upiId ?? '', style: theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w700))),
                            const SizedBox(width: 4),
                            const Icon(Icons.copy_rounded, size: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Scan with any UPI app, or tap Donate by UPI.', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Money goes directly to the organiser. ${Brand.name} verified the work, not how the money is spent.', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            if (!drive.isOrganiser) TextButton.icon(onPressed: onReport, icon: const Icon(Icons.receipt_rounded), label: const Text('I sent a donation — tell the organiser')),
          ],
        ),
      ),
    );
  }
}

class _DonationsSheet extends StatefulWidget {
  const _DonationsSheet({required this.repo, required this.driveId});

  final SevaRepository repo;
  final int driveId;

  @override
  State<_DonationsSheet> createState() => _DonationsSheetState();
}

class _DonationsSheetState extends State<_DonationsSheet> {
  List<SevaDonation>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.repo.donations(widget.driveId);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items == null) return const SizedBox(height: 220, child: DiyaLoader());
    final confirmed = items.where((d) => d.confirmed).fold<int>(0, (a, d) => a + d.amount);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
              child: Text('Donations reported · ${rupees(confirmed)} confirmed', style: Theme.of(context).textTheme.titleMedium),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text('Check each against your UPI app, then confirm it. Only confirmed amounts are shown to others.', style: Theme.of(context).textTheme.bodySmall),
            ),
            if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Nobody has reported a donation yet.', textAlign: TextAlign.center)),
            for (final d in items)
              CheckboxListTile(
                value: d.confirmed,
                onChanged: (v) async {
                  await widget.repo.confirmDonation(widget.driveId, d.id, received: v ?? false);
                  _load();
                },
                title: Text('${rupees(d.amount)} · ${d.donor ?? 'A devotee'}'),
                subtitle: Text([if (d.upiRef != null) 'Ref ${d.upiRef}', if (d.message != null) d.message!].join(' · ').ifEmpty('No reference given')),
                secondary: Icon(d.confirmed ? Icons.verified_rounded : Icons.hourglass_empty_rounded, color: d.confirmed ? Palette.tulsi : Palette.gold),
              ),
          ],
        ),
      ),
    );
  }
}


/// Title's companions: who runs it and when, big enough to read at a glance.
class _OrganiserAndDates extends StatelessWidget {
  const _OrganiserAndDates({required this.drive});

  final SevaDrive drive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = drive;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OrganiserAvatar(drive: d, radius: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ORGANISER', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    Text(d.organiserName ?? Brand.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (d.isTeam) const SevaPill(text: 'Team drive', color: Palette.tulsi, icon: Icons.verified_user_rounded),
              if (d.isOrganiser) const SevaPill(text: 'You', color: Palette.kumkum, icon: Icons.star_rounded),
            ],
          ),
          const Divider(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Palette.saffron.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(d.isMultiDay ? Icons.date_range_rounded : Icons.event_rounded, color: Palette.saffron),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.isMultiDay ? '${d.dayCount} DAYS' : 'ONE DAY', style: theme.textTheme.labelSmall?.copyWith(letterSpacing: 1.2, color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
                    Text(sevaDateRange(d), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// How many are coming, and what has been raised, for everybody.
class _Stats extends StatelessWidget {
  const _Stats({required this.drive});

  final SevaDrive drive;

  @override
  Widget build(BuildContext context) {
    final d = drive;
    final raised = d.donations.raised ?? 0;
    return Row(
      children: [
        Expanded(child: _Stat(value: '${d.volunteersJoined}', label: d.volunteersNeeded == null ? 'coming' : 'of ${d.volunteersNeeded} coming', color: Palette.saffron, icon: Icons.groups_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _Stat(value: '${d.signups}', label: d.signups == 1 ? 'sign-up' : 'sign-ups', color: Palette.ash, icon: Icons.how_to_reg_rounded)),
        const SizedBox(width: 8),
        Expanded(child: _Stat(value: rupees(raised), label: d.donations.donors == 0 ? 'raised' : 'from ${d.donations.donors} donor${d.donations.donors == 1 ? '' : 's'}', color: Palette.tulsi, icon: Icons.volunteer_activism_rounded)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color, required this.icon});

  final String value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _MisleadingBanner extends StatelessWidget {
  const _MisleadingBanner({this.note});

  final String? note;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Palette.kumkum.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: Palette.kumkum.withValues(alpha: 0.5))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Palette.kumkum),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Flagged as misleading by the team', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: Palette.kumkum)),
                    if (note != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(note!)),
                    const SizedBox(height: 4),
                    Text('Joining and donations are closed.', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// For the organiser: everybody who said they are coming, on the page.
class _WhoIsComing extends StatelessWidget {
  const _WhoIsComing({required this.drive, required this.volunteers});

  final SevaDrive drive;
  final List<SevaVolunteer> volunteers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, color: Palette.tulsi, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text("Who's coming", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
              Text('${drive.volunteersJoined} people', style: theme.textTheme.labelLarge),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(color: theme.colorScheme.surfaceContainerLow, borderRadius: BorderRadius.circular(16), border: Border.all(color: theme.colorScheme.outlineVariant)),
            child: Column(
              children: [
                for (var i = 0; i < volunteers.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Palette.saffron.withValues(alpha: 0.18),
                      child: volunteers[i].avatarUrl != null
                          ? ClipOval(child: SizedBox.expand(child: AppImage(volunteers[i].avatarUrl!)))
                          : Text((volunteers[i].name ?? '').characters.firstOrNull?.toUpperCase() ?? '?', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    title: Text(volunteers[i].name ?? 'A devotee', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: volunteers[i].note == null ? null : Text(volunteers[i].note!, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: volunteers[i].partySize > 1 ? SevaPill(text: '+${volunteers[i].partySize - 1} with them', color: Palette.saffron) : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
