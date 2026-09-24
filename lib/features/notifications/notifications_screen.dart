import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/strings.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/notifications_controller.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/temple_widgets.dart';
import 'notice_links.dart';

/// The notification inbox: festival reminders, new temples, app news.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotificationsController>().load());
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final inbox = context.watch<NotificationsController>();
    return Scaffold(
      appBar: AppBar(
        title: Text(s('notifications')),
        actions: [
          if (inbox.unreadCount > 0) TextButton(onPressed: inbox.markAllRead, child: Text(s('mark_all_read'))),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: inbox.load,
        child: inbox.items.isEmpty
            ? ListView(children: [
                const SizedBox(height: 80),
                if (inbox.loading) const Center(child: CircularProgressIndicator()) else EmptyShrine(motif: Motif.diya, message: s('notifications_empty')),
              ])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: inbox.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = inbox.items[i];
                  final unread = !inbox.isRead(n);
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        inbox.markRead(n);
                        openNoticeLink(n, context: context);
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (n.imageUrl != null) AspectRatio(aspectRatio: 2, child: AppImage(n.imageUrl!, decodeWidth: 600)),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 6, right: 10),
                                  child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: unread ? theme.colorScheme.primary : Colors.transparent)),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(n.title, style: theme.textTheme.titleMedium?.copyWith(fontFamily: 'NotoSerif', fontWeight: unread ? FontWeight.w600 : null)),
                                      const SizedBox(height: 4),
                                      Text(n.body, style: theme.textTheme.bodyMedium),
                                      if (n.sentAt != null) ...[
                                        const SizedBox(height: 6),
                                        Text(_when(n.sentAt!), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
                                      ],
                                    ],
                                  ),
                                ),
                                if (n.linkType != 'none') Icon(Icons.chevron_right_rounded, color: theme.colorScheme.outline),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static String _when(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return '${d.day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][d.month - 1]} ${d.year}';
  }
}

/// A bell with the unread count, for app bars and headers.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationsController>().unreadCount;
    return IconButton(
      tooltip: S.of(context)('notifications'),
      color: color,
      onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 9 ? '9+' : '$unread'), child: const Icon(Icons.notifications_outlined)),
    );
  }
}
