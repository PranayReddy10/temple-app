import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/api/temple_repository.dart';
import '../../core/l10n/strings.dart';
import '../../core/models/models.dart';
import '../../core/motifs/motif.dart';
import '../../core/theme/day_theme.dart';
import '../../core/widgets/temple_door.dart';
import '../../core/widgets/temple_widgets.dart';
import '../temple/temple_screen.dart';

/// Search by name, deity, city or state, with filters and a nearby mode.
///
/// Also used as the "see all" destination for a deity, circuit or state,
/// and as the temple picker for the Yatra planner (when [picker] is set the
/// tapped temple is returned instead of opened).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initial = const TempleQuery(), this.autofocus = false, this.picker = false, this.title});

  final TempleQuery initial;
  final bool autofocus;
  final bool picker;
  final String? title;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TempleQuery _query = widget.initial;
  late final TextEditingController _text = TextEditingController(text: widget.initial.q ?? '');
  Timer? _debounce;
  Result<Paged<TempleSummary>>? _result;
  final List<TempleSummary> _items = [];
  bool _loading = false;
  bool _loadingMore = false;
  String? _error;
  List<DeityRef> _deities = const [];
  List<CategoryRef> _categories = const [];
  List<StateRef> _states = const [];

  @override
  void initState() {
    super.initState();
    _run();
    final repo = context.read<TempleRepository>();
    Future.wait([repo.deities(), repo.categories(), repo.states()]).then((r) {
      if (!mounted) return;
      setState(() {
        _deities = (r[0] as Result<List<DeityRef>>).data;
        _categories = (r[1] as Result<List<CategoryRef>>).data;
        _states = (r[2] as Result<List<StateRef>>).data;
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await context.read<TempleRepository>().temples(_query.copyWith(page: 1));
      if (!mounted) return;
      setState(() {
        _result = r;
        _items
          ..clear()
          ..addAll(r.data.items);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _more() async {
    if (_loadingMore || _result == null || !_result!.data.hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final r = await context.read<TempleRepository>().temples(_query.copyWith(page: _result!.data.currentPage + 1));
      if (!mounted) return;
      setState(() {
        _result = r;
        _items.addAll(r.data.items);
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onText(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _query = _query.copyWith(q: v);
      _run();
    });
  }

  void _set(TempleQuery q) {
    setState(() => _query = q);
    _run();
  }

  Future<void> _nearMe() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) throw 'Location permission denied';
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      _set(_query.copyWith(lat: pos.latitude, lng: pos.longitude, radiusKm: 500, sort: 'distance'));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _open(TempleSummary t) {
    if (widget.picker) {
      Navigator.of(context).pop(t);
      return;
    }
    enterTemple(context, TempleScreen(slug: t.slug, preview: t), accent: DayTheme.forDeity(t.deity?.slug).accent);
  }

  String _label(String? slug, List<dynamic> from) {
    for (final x in from) {
      if ((x as dynamic).slug == slug) return (x as dynamic).name as String;
    }
    return slug ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final activeFilters = <Widget>[
      if (_query.deity != null) _FilterChip(label: _label(_query.deity, _deities), onRemove: () => _set(_query.copyWith(clearFilters: true, category: _query.category, state: _query.state))),
      if (_query.category != null) _FilterChip(label: _label(_query.category, _categories), onRemove: () => _set(_query.copyWith(clearFilters: true, deity: _query.deity, state: _query.state))),
      if (_query.state != null) _FilterChip(label: _label(_query.state, _states), onRemove: () => _set(_query.copyWith(clearFilters: true, deity: _query.deity, category: _query.category))),
      if (_query.verifiedOnly) _FilterChip(label: s('verified_only'), onRemove: () => _set(_query.copyWith(verifiedOnly: false))),
      if (_query.isNearby) _FilterChip(label: 'Near me · ${_query.radiusKm?.toStringAsFixed(0)} km', onRemove: () => _set(TempleQuery(q: _query.q, deity: _query.deity, category: _query.category, state: _query.state, verifiedOnly: _query.verifiedOnly))),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? (widget.picker ? 'Choose a temple' : 'Search')),
        actions: [
          IconButton(tooltip: 'Near me', onPressed: _nearMe, icon: const Icon(Icons.near_me_rounded)),
          IconButton(tooltip: s('filters'), onPressed: _showFilters, icon: Badge(isLabelVisible: activeFilters.isNotEmpty, child: const Icon(Icons.tune_rounded))),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: TextField(
              controller: _text,
              autofocus: widget.autofocus,
              onChanged: _onText,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: s('search_hint'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _text.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _text.clear();
                          _onText('');
                        },
                      ),
              ),
            ),
          ),
          if (activeFilters.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [for (final f in activeFilters) Padding(padding: const EdgeInsets.only(right: 8), child: f)]),
            ),
          if (_result?.isOffline == true) const OfflineNote(),
          Expanded(
            child: _loading && _items.isEmpty
                ? const DiyaLoader(label: 'Searching')
                : _error != null
                    ? EmptyShrine(motif: Motif.diya, message: _error!, action: OutlinedButton(onPressed: _run, child: const Text('Try again')))
                    : _items.isEmpty
                        ? EmptyShrine(motif: Motif.lotus, message: s('no_results'))
                        : NotificationListener<ScrollNotification>(
                            onNotification: (n) {
                              if (n.metrics.pixels > n.metrics.maxScrollExtent - 300) _more();
                              return false;
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                              itemCount: _items.length + (_loadingMore ? 1 : 0),
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (context, i) {
                                if (i >= _items.length) return const SizedBox(height: 60, child: DiyaLoader(size: 32));
                                final t = _items[i];
                                return TempleCard(temple: t, compact: true, onTap: () => _open(t), trailing: widget.picker ? Icon(Icons.add_circle_rounded, color: theme.colorScheme.primary) : null);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Future<void> _showFilters() async {
    final s = S.of(context);
    var draft = _query;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          builder: (context, controller) => ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Theme.of(context).colorScheme.outline, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 12),
              Text(s('filters'), style: Theme.of(context).textTheme.titleLarge),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(s('verified_only')),
                subtitle: Text(s('trust_note'), style: Theme.of(context).textTheme.bodySmall),
                value: draft.verifiedOnly,
                onChanged: (v) => setSheet(() => draft = draft.copyWith(verifiedOnly: v)),
              ),
              const KolamDivider(),
              Text(s('by_deity'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in _deities)
                    ChoiceChip(
                      label: Text(d.name),
                      avatar: MotifIcon(DayTheme.forDeity(d.slug).deitySlug == d.slug ? DayTheme.forDeity(d.slug).motif : Motif.om, size: 16, color: DayTheme.forDeity(d.slug).accent),
                      selected: draft.deity == d.slug,
                      onSelected: (v) => setSheet(() => draft = TempleQuery(q: draft.q, deity: v ? d.slug : null, category: draft.category, state: draft.state, verifiedOnly: draft.verifiedOnly, lat: draft.lat, lng: draft.lng, radiusKm: draft.radiusKm, sort: draft.sort)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(s('categories'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in _categories)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: draft.category == c.slug,
                      onSelected: (v) => setSheet(() => draft = TempleQuery(q: draft.q, deity: draft.deity, category: v ? c.slug : null, state: draft.state, verifiedOnly: draft.verifiedOnly, lat: draft.lat, lng: draft.lng, radiusKm: draft.radiusKm, sort: draft.sort)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(s('by_state'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final st in _states)
                    ChoiceChip(
                      label: Text(st.name),
                      selected: draft.state == st.slug,
                      onSelected: (v) => setSheet(() => draft = TempleQuery(q: draft.q, deity: draft.deity, category: draft.category, state: v ? st.slug : null, verifiedOnly: draft.verifiedOnly, lat: draft.lat, lng: draft.lng, radiusKm: draft.radiusKm, sort: draft.sort)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Sort', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'recent', label: Text('Recent')),
                  ButtonSegment(value: 'name', label: Text('A–Z')),
                  ButtonSegment(value: '-name', label: Text('Z–A')),
                ],
                selected: {draft.sort == null || draft.sort == 'distance' ? 'recent' : draft.sort!},
                onSelectionChanged: (v) => setSheet(() => draft = draft.copyWith(sort: v.first)),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => setSheet(() => draft = TempleQuery(q: draft.q)), child: const Text('Clear'))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _set(draft);
                      },
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => InputChip(label: Text(label), selected: true, showCheckmark: false, onDeleted: onRemove, deleteIcon: const Icon(Icons.close_rounded, size: 16));
}
