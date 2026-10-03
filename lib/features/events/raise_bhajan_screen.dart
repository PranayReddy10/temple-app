import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/temple_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/theme/day_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_widgets.dart';
import '../bookings/book_puja_sheet.dart' show ensureSignedIn;

/// A bhajan gathering a devotee organises at a temple, the way a seva drive
/// is raised: the name, who leads it, the first day and time, whether it
/// repeats weekly, what will be sung. The server makes it free and hands it
/// to the editors; once published it sits on the temple's page with "I'll
/// join".
class RaiseBhajanScreen extends StatefulWidget {
  const RaiseBhajanScreen({super.key, required this.temple});

  final TempleSummary temple;

  /// Signed in first, then the form; the created event comes back, or null.
  static Future<TempleEvent?> open(BuildContext context, TempleSummary temple) async {
    if (!await ensureSignedIn(context) || !context.mounted) return null;
    return Navigator.of(context).push<TempleEvent>(MaterialPageRoute(builder: (_) => RaiseBhajanScreen(temple: temple)));
  }

  @override
  State<RaiseBhajanScreen> createState() => _RaiseBhajanScreenState();
}

class _RaiseBhajanScreenState extends State<RaiseBhajanScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _group = TextEditingController();
  final _about = TextEditingController();
  final _songs = TextEditingController();
  DateTime _day = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? _from = const TimeOfDay(hour: 18, minute: 30);
  TimeOfDay? _to = const TimeOfDay(hour: 20, minute: 0);
  bool _weekly = true;
  bool _openToAll = true;
  bool _busy = false;
  ApiException? _error;

  @override
  void dispose() {
    for (final c in [_title, _group, _about, _songs]) {
      c.dispose();
    }
    super.dispose();
  }

  static String _hhmm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> get _fields => {
        'title': _title.text.trim(),
        if (_group.text.trim().isNotEmpty) 'group_name': _group.text.trim(),
        if (_about.text.trim().isNotEmpty) 'description': _about.text.trim(),
        'starts_on': _ymd(_day),
        if (_from != null) 'starts_at': _hhmm(_from!),
        if (_from != null && _to != null) 'ends_at': _hhmm(_to!),
        'recurrence': _weekly ? 'weekly' : 'none',
        'open_to_all': _openToAll,
        if (_songs.text.trim().isNotEmpty) 'songs': _songs.text.trim(),
      };

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = S.of(context);
    try {
      final event = await context.read<TempleRepository>().raiseBhajan(widget.temple.slug, _fields);
      if (!mounted) return;
      setState(() => _busy = false);
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const IconBadge(Icons.check_rounded, color: Palette.tulsi, size: 52, filled: true),
          title: Text(s('bhajan_sent')),
          content: Text(s('bhajan_sent_body').replaceFirst('{temple}', widget.temple.name)),
          actions: [FilledButton(onPressed: () => Navigator.of(c).pop(), child: Text(s('bhajan_done')))],
        ),
      );
      if (mounted) Navigator.of(context).pop(event);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s('offline_note'))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(now.year, now.month, now.day), lastDate: now.add(const Duration(days: 365)));
    if (d != null) setState(() => _day = d);
  }

  Future<void> _pickTime(bool from) async {
    final t = await showTimePicker(context: context, initialTime: (from ? _from : _to) ?? const TimeOfDay(hour: 18, minute: 30));
    if (t == null) return;
    setState(() {
      if (from) {
        _from = t;
        if (_to != null && (_to!.hour * 60 + _to!.minute) <= (t.hour * 60 + t.minute)) _to = TimeOfDay(hour: (t.hour + 1) % 24, minute: t.minute);
      } else {
        _to = t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final day = DayTheme.forDeity(widget.temple.deity?.slug);
    final locale = Localizations.localeOf(context).toString();
    String? fieldError(String key) => _error?.errors[key]?.first;
    return Scaffold(
      appBar: AppBar(title: Text(s('raise_bhajan'))),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            SoftCard(
              color: day.accent.withValues(alpha: 0.1),
              border: day.accent.withValues(alpha: 0.4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(null, motif: Motif.bell, color: day.accent, size: 46),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s('raise_bhajan_title').replaceFirst('{temple}', widget.temple.name), style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif')),
                        const SizedBox(height: 4),
                        Text(s('raise_bhajan_pitch'), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SoftCard(
              color: Palette.tulsi.withValues(alpha: 0.1),
              border: Palette.tulsi.withValues(alpha: 0.4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.volunteer_activism_rounded, color: Palette.tulsi),
                  const SizedBox(width: 10),
                  Expanded(child: Text(s('bhajan_free_note'), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface))),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s('bhajan_name'), hintText: s('bhajan_name_hint'), prefixIcon: const Icon(Icons.music_note_rounded), errorText: fieldError('title')),
              validator: (v) => (v == null || v.trim().length < 3) ? s('bhajan_name_required') : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _group,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: s('bhajan_group'), prefixIcon: const Icon(Icons.groups_rounded), errorText: fieldError('group_name')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _about,
              maxLines: 3,
              minLines: 2,
              decoration: InputDecoration(labelText: s('bhajan_about'), alignLabelWithHint: true, errorText: fieldError('description')),
            ),
            const SizedBox(height: 20),
            Text(s('event_when'), style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            _PickerTile(
              icon: Icons.calendar_month_rounded,
              label: s('bhajan_day'),
              value: DateFormat.yMMMMEEEEd(locale).format(_day),
              accent: day.accent,
              onTap: _pickDay,
              error: fieldError('starts_on'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _PickerTile(icon: Icons.schedule_rounded, label: s('bhajan_from'), value: _from == null ? '—' : _from!.format(context), accent: day.accent, onTap: () => _pickTime(true), error: fieldError('starts_at'))),
                const SizedBox(width: 8),
                Expanded(child: _PickerTile(icon: Icons.schedule_rounded, label: s('bhajan_to'), value: _to == null ? '—' : _to!.format(context), accent: day.accent, onTap: () => _pickTime(false), error: fieldError('ends_at'))),
              ],
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _weekly,
              onChanged: (v) => setState(() => _weekly = v),
              title: Text(s('bhajan_weekly')),
              subtitle: Text(DateFormat.EEEE(locale).format(_day)),
              activeTrackColor: day.accent,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _openToAll,
              onChanged: (v) => setState(() => _openToAll = v),
              title: Text(s('bhajan_open')),
              subtitle: Text(s('bhajan_open_note')),
              activeTrackColor: day.accent,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _songs,
              maxLines: 6,
              minLines: 3,
              decoration: InputDecoration(labelText: s('bhajan_songs'), alignLabelWithHint: true, hintText: 'Raghupati Raghava\nSri Rama Jaya Rama', errorText: fieldError('songs')),
            ),
            if (_error != null && _error!.errors.isEmpty) ...[
              const SizedBox(height: 12),
              Text(_error!.message, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: day.accent, foregroundColor: day.onAccent(), minimumSize: const Size.fromHeight(52)),
              icon: _busy ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send_rounded),
              label: Text(s('bhajan_send')),
            ),
          ],
        ),
      ),
    );
  }
}

/// A date or time, shown like a field and tapped to change.
class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.icon, required this.label, required this.value, required this.accent, required this.onTap, this.error});

  final IconData icon;
  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: accent), errorText: error),
        child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
