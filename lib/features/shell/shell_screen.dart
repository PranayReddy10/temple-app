import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/platform.dart';

import '../../core/l10n/strings.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/day_controller.dart';
import '../explore/explore_screen.dart';
import '../home/home_screen.dart';
import '../passport/passport_screen.dart';
import '../profile/profile_screen.dart';
import '../yatra/yatra_screen.dart';

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
  }

  @override
  void dispose() {
    shellTabRequest.removeListener(_onTabRequest);
    super.dispose();
  }

  /// A notification asked for a tab (the Passport, the Yatra planner).
  void _onTabRequest() {
    final i = shellTabRequest.value;
    if (i == null || !mounted) return;
    setState(() => _index = i.clamp(0, 4));
    shellTabRequest.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final day = context.watch<DayController>().theme;
    final scheme = Theme.of(context).colorScheme;
    final pages = [
      HomeScreen(onExplore: () => setState(() => _index = 1), onTab: (i) => setState(() => _index = i)),
      const ExploreScreen(),
      const PassportScreen(),
      const YatraScreen(),
      const ProfileScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
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
    );
  }
}
