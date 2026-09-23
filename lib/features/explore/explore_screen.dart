import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ads/ads.dart';
import '../../core/api/temple_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/theme/day_theme.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../temple/temple_screen.dart';
import 'india_map.dart';
import 'search_screen.dart';

/// Explore: a map of every temple we know, then circuits, deities and states.
///
/// Laid out as a mandapa: the map is the central shrine, the tiles around it
/// the pillared hall.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> with AutomaticKeepAliveClientMixin {
  Result<List<CategoryRef>>? _categories;
  Result<List<DeityRef>>? _deities;
  Result<List<StateRef>>? _states;
  Result<Paged<TempleSummary>>? _all;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<TempleRepository>();
    final r = await Future.wait([repo.categories(), repo.deities(), repo.states(), repo.temples(const TempleQuery(perPage: 50))]);
    if (!mounted) return;
    setState(() {
      _categories = r[0] as Result<List<CategoryRef>>;
      _deities = r[1] as Result<List<DeityRef>>;
      _states = r[2] as Result<List<StateRef>>;
      _all = r[3] as Result<Paged<TempleSummary>>;
    });
  }

  void _search(TempleQuery q) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SearchScreen(initial: q)));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, top + 16, 20, 8),
              child: Row(
                children: [
                  Expanded(child: Text(s('explore'), style: theme.textTheme.headlineMedium)),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SearchScreen(autofocus: true))),
                    icon: const Icon(Icons.search_rounded),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: IndiaMap(
                temples: _all?.data.items ?? const [],
                onTap: (t) => enterTemple(context, TempleScreen(slug: t.slug, preview: t), accent: DayTheme.forDeity(t.deity?.slug).accent),
              ),
            ),
          ),
          if (_all?.isOffline == true) const SliverToBoxAdapter(child: OfflineNote()),
          SliverToBoxAdapter(child: SectionHeader(title: s('categories'), motif: Motif.kalasha)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: _categories == null
                ? const SliverToBoxAdapter(child: SizedBox(height: 100, child: DiyaLoader()))
                : SliverGrid.builder(
                    // A fixed row height that grows with the font, rather than
                    // an aspect ratio that a larger text setting overflows.
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, mainAxisExtent: scaledHeight(context, 136)),
                    itemCount: _categories!.data.length,
                    itemBuilder: (context, i) {
                      final c = _categories!.data[i];
                      return StoneTile(
                        title: c.name,
                        subtitle: c.templeCount != null ? '${c.templeCount} temples' : c.kind,
                        motif: _motifForCategory(c.slug),
                        onTap: () => _search(TempleQuery(category: c.slug)),
                      );
                    },
                  ),
          ),
          SliverToBoxAdapter(child: SectionHeader(title: s('by_deity'), motif: Motif.om)),
          SliverToBoxAdapter(
            child: SizedBox(
              height: scaledHeight(context, 122),
              child: _deities == null
                  ? const DiyaLoader()
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _deities!.data.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final d = _deities!.data[i];
                        final dt = DayTheme.forDeity(d.slug);
                        return GestureDetector(
                          onTap: () => _search(TempleQuery(deity: d.slug)),
                          child: Column(
                            children: [
                              DeityIcon(slug: d.slug, imageUrl: d.imageUrl, accent: dt.accent, secondary: dt.secondary, onAccent: dt.onAccent()),
                              const SizedBox(height: 4),
                              SizedBox(width: 80, child: FittedBox(fit: BoxFit.scaleDown, child: Text(d.name, textAlign: TextAlign.center, maxLines: 1, style: theme.textTheme.labelMedium?.copyWith(fontFamily: 'NotoSerif')))),
                              if (d.templeCount != null) Flexible(child: Text('${d.templeCount}', style: theme.textTheme.labelSmall?.copyWith(color: dt.accent))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.symmetric(horizontal: 20), sliver: SliverToBoxAdapter(child: NativeAdSlot(placement: 'explore'))),
          SliverToBoxAdapter(child: SectionHeader(title: s('by_state'), motif: Motif.lotus)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: _states == null
                ? const SliverToBoxAdapter(child: SizedBox(height: 100, child: DiyaLoader()))
                : SliverToBoxAdapter(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final st in _states!.data)
                          ActionChip(
                            avatar: Text(st.code ?? st.name.substring(0, 2).toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
                            label: Text(st.templeCount != null ? '${st.name} · ${st.templeCount}' : st.name),
                            onPressed: () => _search(TempleQuery(state: st.slug)),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static Motif _motifForCategory(String slug) => switch (slug) {
        'jyotirlinga' => Motif.trishul,
        'char-dham' || 'chota-char-dham' => Motif.kalasha,
        'shakti-peetha' => Motif.lotus,
        'divya-desam' => Motif.shankhaChakra,
        'sapta-puri' => Motif.om,
        'unesco-world-heritage' => Motif.bell,
        'hill-temple' => Motif.sun,
        'coastal-temple' || 'river-ghat-temple' => Motif.diya,
        _ => Motif.om,
      };
}
