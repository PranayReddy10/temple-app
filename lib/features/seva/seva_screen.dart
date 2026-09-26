import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api/api_client.dart';
import '../../core/api/seva_repository.dart';
import '../../core/models/seva.dart';
import '../../core/motifs/motif.dart';
import '../../core/state/auth_controller.dart';
import '../../core/theme/palette.dart';
import '../../core/widgets/temple_widgets.dart';
import '../auth/auth_screen.dart';
import 'raise_drive_screen.dart';
import 'seva_drive_screen.dart';
import 'seva_widgets.dart';

/// Seva drives: care for old temples and heritage places, organised by
/// devotees and joined by others.
///
/// Three lists: what can still be joined, the finished work (verified first,
/// with before and after side by side), and the signed-in devotee's own.
class SevaScreen extends StatefulWidget {
  const SevaScreen({super.key});

  /// Raise a drive, signing in first if need be. From a temple's page the
  /// drive is linked to that temple.
  static Future<SevaDrive?> raise(BuildContext context, {String? templeSlug, String? templeName}) async {
    if (!context.read<AuthController>().isSignedIn) {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
      if (!context.mounted || !context.read<AuthController>().isSignedIn) return null;
    }
    return Navigator.of(context).push<SevaDrive>(MaterialPageRoute(builder: (_) => RaiseDriveScreen(templeSlug: templeSlug, templeName: templeName)));
  }

  @override
  State<SevaScreen> createState() => _SevaScreenState();
}

class _SevaScreenState extends State<SevaScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this)..addListener(_onTab);
  late final SevaRepository _repo = SevaRepository(context.read<ApiClient>());

  String? _cause;
  final Map<int, List<SevaDrive>?> _lists = {};
  final Map<int, String?> _errors = {};
  List<SevaDrive>? _joined;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _onTab() {
    if (_tabs.indexIsChanging) return;
    if (_lists[_tabs.index] == null) _load(_tabs.index);
  }

  Future<void> _load(int tab) async {
    setState(() => _errors[tab] = null);
    try {
      if (tab == 2) {
        if (!context.read<AuthController>().isSignedIn) {
          setState(() => _lists[2] = const []);
          return;
        }
        final results = await Future.wait([_repo.mine(), _repo.mine(joined: true)]);
        if (!mounted) return;
        setState(() {
          _lists[2] = results[0];
          _joined = results[1];
        });
        return;
      }
      final page = await _repo.list(when: tab == 0 ? 'upcoming' : 'done', cause: _cause);
      if (!mounted) return;
      setState(() => _lists[tab] = page.items);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lists[tab] = const [];
        _errors[tab] = e is ApiException ? e.message : 'Could not reach the server. Pull down to try again.';
      });
    }
  }

  void _setCause(String? cause) {
    setState(() {
      _cause = cause;
      _lists.remove(0);
      _lists.remove(1);
    });
    _load(_tabs.index == 2 ? 0 : _tabs.index);
  }

  Future<void> _open(SevaDrive d) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SevaDriveScreen(driveId: d.id, initial: d)));
    if (mounted) _load(_tabs.index);
  }

  Future<void> _raise() async {
    final created = await SevaScreen.raise(context);
    if (created == null || !mounted) return;
    _tabs.animateTo(2);
    _load(2);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _raise,
        backgroundColor: Palette.saffron,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Raise a drive'),
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 230,
            backgroundColor: Palette.deep,
            foregroundColor: Palette.sandal,
            title: const Text('Seva Drives'),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Palette.tulsi, Palette.deep]))),
                  const Positioned(left: 0, right: 0, bottom: 0, child: GopuramBand(color: Palette.gold, height: 90, opacity: 0.18)),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Care for the places\nthat cared for us', style: theme.textTheme.headlineSmall?.copyWith(color: Palette.sandal, fontFamily: 'NotoSerif', fontWeight: FontWeight.w700, height: 1.15)),
                        const SizedBox(height: 6),
                        Text('Clean an old temple, a temple tank or a forgotten shrine — together.', style: theme.textTheme.bodySmall?.copyWith(color: Palette.sandal.withValues(alpha: 0.85))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Palette.gold,
              labelColor: Palette.sandal,
              unselectedLabelColor: Palette.sandal.withValues(alpha: 0.6),
              tabs: const [Tab(text: 'Upcoming'), Tab(text: 'Completed'), Tab(text: 'Mine')],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _list(0),
            _list(1),
            _mine(),
          ],
        ),
      ),
    );
  }

  Widget _causeChips() => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
          children: [
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('All'), selected: _cause == null, onSelected: (_) => _setCause(null))),
            for (final c in SevaCause.all)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(avatar: Icon(sevaCauseIcon(c.value), size: 16), label: Text(c.label), selected: _cause == c.value, onSelected: (_) => _setCause(_cause == c.value ? null : c.value)),
              ),
          ],
        ),
      );

  Widget _list(int tab) {
    final items = _lists[tab];
    return RefreshIndicator(
      onRefresh: () => _load(tab),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _causeChips()),
          if (tab == 0) const SliverToBoxAdapter(child: _HowItWorks()),
          if (items == null)
            const SliverFillRemaining(hasScrollBody: false, child: DiyaLoader(label: 'Finding drives…'))
          else if (items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyShrine(
                motif: tab == 0 ? Motif.diya : Motif.lotus,
                message: _errors[tab] ?? (tab == 0 ? 'No drives are open right now. Know an old temple or tank that needs care? Raise the first one.' : 'Finished drives, with their before and after photographs, appear here.'),
                action: tab == 0 ? FilledButton.icon(onPressed: _raise, icon: const Icon(Icons.add_a_photo_rounded), label: const Text('Raise a drive')) : null,
              ),
            )
          else ...[
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            SliverList.builder(itemCount: items.length, itemBuilder: (context, i) => SevaDriveCard(drive: items[i], onTap: () => _open(items[i]))),
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ],
      ),
    );
  }

  Widget _mine() {
    final signedIn = context.watch<AuthController>().isSignedIn;
    if (!signedIn) {
      return EmptyShrine(
        motif: Motif.kalasha,
        message: 'Sign in to raise a drive, join one, and see the drives you are part of.',
        action: FilledButton(onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthScreen()));
          if (mounted) _load(2);
        }, child: const Text('Sign in')),
      );
    }
    final mine = _lists[2];
    final joined = _joined ?? const <SevaDrive>[];
    return RefreshIndicator(
      onRefresh: () => _load(2),
      child: CustomScrollView(
        slivers: [
          if (mine == null)
            const SliverFillRemaining(hasScrollBody: false, child: DiyaLoader())
          else if (mine.isEmpty && joined.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyShrine(
                motif: Motif.kalasha,
                message: _errors[2] ?? 'Drives you organise or join appear here.',
                action: FilledButton.icon(onPressed: _raise, icon: const Icon(Icons.add_a_photo_rounded), label: const Text('Raise a drive')),
              ),
            )
          else ...[
            if (mine.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader(title: 'Organised by you', motif: Motif.kalasha)),
              SliverList.builder(itemCount: mine.length, itemBuilder: (context, i) => SevaDriveCard(drive: mine[i], onTap: () => _open(mine[i]))),
            ],
            if (joined.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader(title: "You're going", motif: Motif.diya)),
              SliverList.builder(itemCount: joined.length, itemBuilder: (context, i) => SevaDriveCard(drive: joined[i], onTap: () => _open(joined[i]))),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 90)),
          ],
        ],
      ),
    );
  }
}

/// The four steps, once, for someone who has not seen a drive before.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (Icons.add_a_photo_rounded, 'Raise', 'Photos of the place, the problem and your plan'),
    (Icons.fact_check_rounded, 'Approved', 'The team checks it before it is listed'),
    (Icons.groups_rounded, 'Join hands', 'Volunteers sign up and meet on the day'),
    (Icons.verified_rounded, 'Verified', 'After-photos checked; donations open by UPI'),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Palette.tulsi.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Palette.tulsi.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How a seva drive works', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(radius: 16, backgroundColor: Palette.tulsi, child: Icon(_steps[i].$1, size: 16, color: Colors.white)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: '${i + 1}. ${_steps[i].$2}  ', style: const TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: _steps[i].$3),
                        ]),
                        style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
