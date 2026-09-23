import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/temple_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/day_controller.dart';
import '../../core/state/reminders_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../temple/temple_screen.dart';

/// Festival calendar: a month grid with the weekday deity on every cell and
/// a dot for each festival, then the month's events with reminder toggles.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Result<List<TempleEvent>>? _events;

  @override
  void initState() {
    super.initState();
    context.read<TempleRepository>().events().then((r) {
      if (mounted) setState(() => _events = r);
    });
  }

  List<TempleEvent> _inMonth(DateTime m) => (_events?.data ?? const []).where((e) {
        final s = DateTime.tryParse(e.startsOn ?? '');
        final en = DateTime.tryParse(e.endsOn ?? e.startsOn ?? '');
        if (s == null) return false;
        final first = DateTime(m.year, m.month);
        final last = DateTime(m.year, m.month + 1, 0);
        return !s.isAfter(last) && !(en ?? s).isBefore(first);
      }).toList()
        ..sort((a, b) => (a.startsOn ?? '').compareTo(b.startsOn ?? ''));

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final day = context.watch<DayController>().theme;
    final reminders = context.watch<RemindersController>();
    final events = _inMonth(_month);
    final upcoming = (_events?.data ?? const []).where((e) => (DateTime.tryParse(e.startsOn ?? '') ?? DateTime(2000)).isAfter(DateTime.now().subtract(const Duration(days: 1)))).toList()
      ..sort((a, b) => (a.startsOn ?? '').compareTo(b.startsOn ?? ''));

    return Scaffold(
      appBar: AppBar(title: Text(s('calendar'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Row(
            children: [
              IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)), icon: const Icon(Icons.chevron_left_rounded)),
              Expanded(child: Text('${_monthName(_month.month)} ${_month.year}', textAlign: TextAlign.center, style: theme.textTheme.titleLarge)),
              IconButton(onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)), icon: const Icon(Icons.chevron_right_rounded)),
            ],
          ),
          _MonthGrid(month: _month, events: events, accent: day.accent),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [for (final d in DayTheme.all) Row(mainAxisSize: MainAxisSize.min, children: [MotifIcon(d.motif, size: 12, color: d.accent), const SizedBox(width: 3), Text('${d.dayName.substring(0, 3)} ${d.deityName}', style: theme.textTheme.labelSmall)])],
          ),
          if (_events?.isOffline == true) const Padding(padding: EdgeInsets.only(top: 8), child: OfflineNote()),
          SectionHeader(title: s('this_month'), motif: Motif.bell, subtitle: events.isEmpty ? 'No festivals published for this month' : '${events.length} ${events.length == 1 ? 'event' : 'events'}'),
          if (_events == null) const SizedBox(height: 80, child: DiyaLoader(size: 36)),
          for (final e in events) _EventCard(event: e, reminded: reminders.has(e), onRemind: () => reminders.toggle(e)),
          if (upcoming.isNotEmpty && upcoming.any((e) => !events.contains(e))) ...[
            SectionHeader(title: s('upcoming'), motif: Motif.diya),
            for (final e in upcoming.where((e) => !events.contains(e)).take(10)) _EventCard(event: e, reminded: reminders.has(e), onRemind: () => reminders.toggle(e)),
          ],
        ],
      ),
    );
  }

  static String _monthName(int m) => const ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'][m - 1];
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.month, required this.events, required this.accent});

  final DateTime month;
  final List<TempleEvent> events;
  final Color accent;

  bool _hasEvent(DateTime d) => events.any((e) {
        final s = DateTime.tryParse(e.startsOn ?? '');
        final en = DateTime.tryParse(e.endsOn ?? e.startsOn ?? '') ?? s;
        return s != null && en != null && !d.isBefore(DateTime(s.year, s.month, s.day)) && !d.isAfter(DateTime(en.year, en.month, en.day));
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday first.
    final today = DateTime.now();
    final cells = <Widget>[
      for (final d in DayTheme.all) Center(child: Text(d.dayName.substring(0, 2).toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: d.accent, letterSpacing: 1))),
      for (var i = 0; i < lead; i++) const SizedBox(),
      for (var day = 1; day <= daysInMonth; day++)
        Builder(builder: (context) {
          final date = DateTime(month.year, month.month, day);
          final dt = DayTheme.forDate(date);
          final isToday = date.year == today.year && date.month == today.month && date.day == today.day;
          final has = _hasEvent(date);
          return Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isToday ? dt.accent : dt.tint(theme.brightness),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: has ? accent : dt.accent.withValues(alpha: 0.25), width: has ? 1.6 : 1),
            ),
            child: Stack(
              children: [
                Positioned(right: 3, top: 3, child: MotifIcon(dt.motif, size: 10, color: (isToday ? dt.onAccent() : dt.accent).withValues(alpha: 0.7))),
                Center(child: Text('$day', style: theme.textTheme.bodyMedium?.copyWith(color: isToday ? dt.onAccent() : null, fontWeight: isToday ? FontWeight.w700 : null))),
                if (has) Positioned(left: 0, right: 0, bottom: 4, child: Center(child: Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: isToday ? dt.onAccent() : accent)))),
              ],
            ),
          );
        }),
    ];
    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1,
      children: cells,
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.reminded, required this.onRemind});

  final TempleEvent event;
  final bool reminded;
  final VoidCallback onRemind;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (event.imageUrl != null) AspectRatio(aspectRatio: 16 / 7, child: TempleImage(url: event.imageUrl)),
          ListTile(
            leading: Icon(event.isHappeningToday ? Icons.celebration_rounded : Icons.event_rounded, color: scheme.primary),
            title: Text(event.title, style: const TextStyle(fontFamily: 'NotoSerif')),
            subtitle: Text([event.dateLabel ?? event.startsOn, event.templeName].whereType<String>().join(' · ')),
            onTap: event.templeSlug == null ? null : () => enterTemple(context, TempleScreen(slug: event.templeSlug!)),
          ),
          if (event.description != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 8), child: Text(event.description!, style: theme.textTheme.bodySmall)),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                TextButton.icon(onPressed: onRemind, icon: Icon(reminded ? Icons.notifications_active_rounded : Icons.notifications_none_rounded), label: Text(reminded ? s('reminder_set') : s('remind_me'))),
                TextButton.icon(onPressed: () => launchUrl(RemindersController.calendarLink(event), mode: LaunchMode.externalApplication), icon: const Icon(Icons.calendar_month_rounded), label: Text(s('add_to_calendar'))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
