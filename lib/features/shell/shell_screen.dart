import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_queue.dart';
import '../media/now_playing_screen.dart';

import '../../core/platform.dart';
import '../../core/services/analytics.dart';

import '../../core/l10n/strings.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/day_controller.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../passport/passport_screen.dart';
import '../profile/profile_screen.dart';
import '../yatra/yatra_screen.dart';
import '../../core/services/deep_links.dart';
import '../temple/temple_screen.dart';

/// Five tabs, per the project plan: Home, Explore, Passport, Yatra, Profile.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  late int _index = widget.initialIndex;

  @override
  void initState() {
    super.initState();
    shellTabRequest.addListener(_onTabRequest);
    Analytics.instance.screen(_tabs[_index]);
    // A temple link (shared page, or the website's Open / Book buttons).
    DeepLinks.pending.addListener(_openLink);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openLink());
  }

  void _openLink() {
    if (!mounted || DeepLinks.pending.value == null) return;
    final link = DeepLinks.take()!;
    Analytics.instance.screen('deep_link', item: link.slug);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TempleScreen(slug: link.slug, openSevas: link.book)));
  }

  static const _tabs = ['home', 'explore', 'passport', 'yatra', 'profile'];

  void _go(int i) {
    i = i.clamp(0, 4);
    if (i != _index) Analytics.instance.screen(_tabs[i]);
    setState(() => _index = i);
  }

  @override
  void dispose() {
    shellTabRequest.removeListener(_onTabRequest);
    DeepLinks.pending.removeListener(_openLink);
    super.dispose();
  }

  /// A notification asked for a tab (the Passport, the Yatra planner).
  void _onTabRequest() {
    final i = shellTabRequest.value;
    if (i == null || !mounted) return;
    _go(i);
    shellTabRequest.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final day = context.watch<DayController>().theme;
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      HomeScreen(onExplore: () => _go(1), onTab: _go),
      const ExploreScreen(),
      const PassportScreen(),
      const YatraScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      // Whatever is playing rides above the tabs on every one of them.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (context.watch<AudioQueueController?>() != null) const MiniPlayer(),
          NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _go,
        destinations: [
          NavigationDestination(
            icon: MotifIcon(day.motif, size: 24, color: scheme.onSurface.withValues(alpha: 0.65)),
            selectedIcon: MotifIcon(day.motif, size: 26, color: scheme.primary),
            label: s('home'),
          ),
          NavigationDestination(icon: const Icon(Icons.explore_outlined), selectedIcon: const Icon(Icons.explore_rounded), label: s('explore')),
          NavigationDestination(
            icon: MotifIcon(Motif.kalasha, size: 24, color: scheme.onSurface.withValues(alpha: 0.65)),
            selectedIcon: MotifIcon(Motif.kalasha, size: 26, color: scheme.primary),
            label: s('passport'),
          ),
          NavigationDestination(icon: const Icon(Icons.route_outlined), selectedIcon: const Icon(Icons.route_rounded), label: s('yatra')),
          NavigationDestination(icon: const Icon(Icons.person_outline_rounded), selectedIcon: const Icon(Icons.person_rounded), label: s('profile')),
        ],
      ),
        ],
      ),
    );
  }
}
