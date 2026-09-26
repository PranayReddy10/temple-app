import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/engagement_repository.dart';
import '../../core/data/sample_data.dart';
import '../../core/l10n/strings.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/engagement_controller.dart';
import '../../core/theme/day_theme.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../temple/temple_screen.dart';

/// The temples the devotee follows, and what each may send: a festival
/// reminder the evening before, an event reminder, both or neither. Nothing
/// is sent for a temple that is not here, and nothing here is on for anyone
/// who has not followed.
class FollowsScreen extends StatefulWidget {
  const FollowsScreen({super.key});

  @override
  State<FollowsScreen> createState() => _FollowsScreenState();
}

class _FollowsScreenState extends State<FollowsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<EngagementController>().refresh());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final ctl = context.watch<EngagementController>();
    final follows = ctl.follows;
    return Scaffold(
      appBar: AppBar(title: Text(s('followed_temples'))),
      body: RefreshIndicator(
        onRefresh: ctl.refresh,
        child: follows.isEmpty
            ? ListView(children: [SizedBox(height: MediaQuery.sizeOf(context).height * 0.6, child: EmptyShrine(motif: Motif.bell, message: s('follows_empty')))])
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  Text(s('follows_intro'), style: theme.textTheme.bodySmall?.copyWith(height: 1.4)),
                  const SizedBox(height: 12),
                  for (final f in follows) _FollowCard(follow: f),
                ],
              ),
      ),
    );
  }
}

class _FollowCard extends StatelessWidget {
  const _FollowCard({required this.follow});

  final FollowedTemple follow;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final t = follow.temple;
    final day = DayTheme.forDeity(t.deity?.slug);
    final ctl = context.read<EngagementController>();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            leading: SizedBox(width: 48, height: 48, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: TempleImage(url: t.primaryPhoto?.best, deitySlug: t.deity?.slug, motifSize: 22))),
            title: Text(t.name, style: const TextStyle(fontFamily: 'NotoSerif'), maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text([t.location.city, t.location.state].whereType<String>().join(', ')),
            trailing: IconButton(tooltip: s('unfollow'), onPressed: () => ctl.toggleFollow(t), icon: const Icon(Icons.notifications_off_outlined)),
            onTap: () => enterTemple(context, TempleScreen(slug: t.slug, preview: SampleData.bySlug(t.slug) ?? t), accent: day.accent),
          ),
          SwitchListTile(
            dense: true,
            secondary: Icon(Icons.celebration_rounded, color: day.accent),
            title: Text(s('remind_festivals')),
            subtitle: Text(s('remind_festivals_note')),
            value: follow.notifyFestivals,
            onChanged: (v) => ctl.setReminders(t.slug, festivals: v),
          ),
          SwitchListTile(
            dense: true,
            secondary: Icon(Icons.event_rounded, color: day.accent),
            title: Text(s('remind_events')),
            subtitle: Text(s('remind_events_note')),
            value: follow.notifyEvents,
            onChanged: (v) => ctl.setReminders(t.slug, events: v),
          ),
        ],
      ),
    );
  }
}
