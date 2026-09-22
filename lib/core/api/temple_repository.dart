import 'dart:math' as math;

import '../data/sample_data.dart';
import '../models/models.dart';
import 'api_client.dart';

/// Search parameters for `GET /temples`.
class TempleQuery {
  const TempleQuery({
    this.q,
    this.deity,
    this.category,
    this.state,
    this.district,
    this.verifiedOnly = false,
    this.featuredOnly = false,
    this.lat,
    this.lng,
    this.radiusKm,
    this.sort,
    this.page = 1,
    this.perPage = 20,
  });

  final String? q;
  final String? deity;
  final String? category;
  final String? state;
  final String? district;
  final bool verifiedOnly;

  /// Famous temples only. A backend that predates the flag ignores the
  /// parameter and returns its normal list, so this degrades gracefully.
  final bool featuredOnly;
  final double? lat;
  final double? lng;
  final double? radiusKm;
  final String? sort;
  final int page;
  final int perPage;

  bool get isNearby => lat != null && lng != null;

  Map<String, String?> toParams() => {
        'q': q,
        'deity': deity,
        'category': category,
        'state': state,
        'district': district,
        'verified': verifiedOnly ? '1' : null,
        'featured': featuredOnly ? '1' : null,
        'lat': lat?.toString(),
        'lng': lng?.toString(),
        'radius': radiusKm?.toString(),
        'sort': sort,
        'page': '$page',
        'per_page': '$perPage',
      };

  TempleQuery copyWith({
    String? q,
    String? deity,
    String? category,
    String? state,
    bool? verifiedOnly,
    bool? featuredOnly,
    double? lat,
    double? lng,
    double? radiusKm,
    String? sort,
    int? page,
    bool clearFilters = false,
  }) =>
      TempleQuery(
        q: q ?? this.q,
        deity: clearFilters ? null : (deity ?? this.deity),
        category: clearFilters ? null : (category ?? this.category),
        state: clearFilters ? null : (state ?? this.state),
        district: clearFilters ? null : district,
        verifiedOnly: clearFilters ? false : (verifiedOnly ?? this.verifiedOnly),
        featuredOnly: clearFilters ? false : (featuredOnly ?? this.featuredOnly),
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        radiusKm: radiusKm ?? this.radiusKm,
        sort: sort ?? this.sort,
        page: page ?? this.page,
        perPage: perPage,
      );
}

/// Where a result came from. The UI shows a quiet note when it is offline
/// data so a devotee never mistakes sample records for verified ones.
enum DataSource { live, offline }

class Result<T> {
  const Result(this.data, this.source);

  final T data;
  final DataSource source;

  bool get isOffline => source == DataSource.offline;
}

/// Reads temples, listings and devotional days from the API, falling back to
/// the bundled sample set when the server is unreachable.
///
/// The fallback exists so the app is usable at a temple gate with no signal,
/// and so a fresh checkout runs without a backend. It never pretends to be
/// live: every result carries its source.
class TempleRepository {
  TempleRepository(this.api);

  final ApiClient api;

  final Map<String, TempleDetail> _detailCache = {};
  Result<List<DeityRef>>? _deities;
  Result<List<CategoryRef>>? _categories;
  Result<List<StateRef>>? _states;

  Future<Result<T>> _tryLive<T>(Future<T> Function() live, T Function() offline) async {
    try {
      return Result(await live(), DataSource.live);
    } catch (e) {
      if (e is ApiException && (e.isNotFound || e.isValidation)) rethrow;
      return Result(offline(), DataSource.offline);
    }
  }

  Future<Result<Paged<TempleSummary>>> temples(TempleQuery query) => _tryLive(
        () async {
          final json = await api.get('temples', query.toParams());
          final data = (json['data'] as List? ?? const []).map((e) => TempleSummary.fromJson(e as Map<String, dynamic>)).toList();
          final meta = json['meta'] as Map<String, dynamic>? ?? const {};
          return Paged(
            items: data,
            currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
            lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
            total: (meta['total'] as num?)?.toInt(),
          );
        },
        () => Paged(items: _filterOffline(query)),
      );

  List<TempleSummary> _filterOffline(TempleQuery q) {
    Iterable<TempleSummary> list = SampleData.temples;
    if (q.q != null && q.q!.trim().isNotEmpty) {
      final needle = q.q!.toLowerCase();
      list = list.where((t) =>
          t.name.toLowerCase().contains(needle) ||
          (t.location.city ?? '').toLowerCase().contains(needle) ||
          (t.location.state ?? '').toLowerCase().contains(needle) ||
          (t.deity?.name ?? '').toLowerCase().contains(needle) ||
          SampleData.aliasesFor(t.slug).any((a) => a.toLowerCase().contains(needle)));
    }
    if (q.deity != null) list = list.where((t) => t.deity?.slug == q.deity);
    if (q.category != null) list = list.where((t) => t.categorySlugs.contains(q.category));
    if (q.state != null) list = list.where((t) => SampleData.stateSlug(t.location.state) == q.state);
    if (q.verifiedOnly) list = list.where((t) => t.trust.level == TrustLevel.verified || t.trust.level == TrustLevel.official);
    if (q.featuredOnly) list = list.where((t) => t.isFeatured);
    var out = list.toList();
    if (q.isNearby) {
      out = out
          .where((t) => t.location.hasCoordinates)
          .map((t) => t.withDistance(distanceKm(q.lat!, q.lng!, t.location.latitude!, t.location.longitude!)))
          .where((t) => t.distanceKm! <= (q.radiusKm ?? 50))
          .toList()
        ..sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
    } else if (q.sort == 'name') {
      out.sort((a, b) => a.name.compareTo(b.name));
    } else if (q.sort == '-name') {
      out.sort((a, b) => b.name.compareTo(a.name));
    } else if (q.sort == 'featured') {
      out.sort((a, b) => a.isFeatured == b.isFeatured ? a.name.compareTo(b.name) : (a.isFeatured ? -1 : 1));
    }
    return out;
  }

  Future<Result<TempleDetail>> temple(String slug) async {
    final cached = _detailCache[slug];
    if (cached != null) return Result(cached, DataSource.live);
    return _tryLive(
      () async {
        final json = await api.get('temples/$slug');
        final d = TempleDetail.fromJson(json['data'] as Map<String, dynamic>);
        _detailCache[slug] = d;
        return d;
      },
      () {
        final d = SampleData.detail(slug);
        if (d == null) throw const ApiException('Temple not found', statusCode: 404);
        return d;
      },
    );
  }

  Future<Result<List<DeityRef>>> deities() async => _deities ??= await _tryLive(
        () async => ((await api.get('deities'))['data'] as List).map((e) => DeityRef.fromJson(e as Map<String, dynamic>)).toList(),
        () => SampleData.deities,
      );

  Future<Result<List<CategoryRef>>> categories() async => _categories ??= await _tryLive(
        () async => ((await api.get('categories'))['data'] as List).map((e) => CategoryRef.fromJson(e as Map<String, dynamic>)).toList(),
        () => SampleData.categories,
      );

  Future<Result<List<StateRef>>> states() async => _states ??= await _tryLive(
        () async => ((await api.get('states'))['data'] as List).map((e) => StateRef.fromJson(e as Map<String, dynamic>)).toList(),
        () => SampleData.states,
      );

  Future<Result<List<TempleEvent>>> events() => _tryLive(
        () async => ((await api.get('events'))['data'] as List).map((e) => TempleEvent.fromJson(e as Map<String, dynamic>)).toList(),
        () => SampleData.events,
      );

  Future<Result<List<DevotionalDay>>> today() => _tryLive(
        () async {
          final data = (await api.get('today'))['data'] as Map<String, dynamic>;
          return (data['days'] as List? ?? const []).map((e) => DevotionalDay.fromJson(e as Map<String, dynamic>)).toList();
        },
        () => SampleData.daysFor(DateTime.now().weekday % 7),
      );

  Future<Result<List<DevotionalDay>>> day(int weekday) => _tryLive(
        () async => ((await api.get('days/$weekday'))['data'] as List).map((e) => DevotionalDay.fromJson(e as Map<String, dynamic>)).toList(),
        () => SampleData.daysFor(weekday),
      );

  Future<Result<List<DevotionalDay>>> week() => _tryLive(
        () async => ((await api.get('days'))['data'] as List).map((e) => DevotionalDay.fromJson(e as Map<String, dynamic>)).toList(),
        () => [for (var w = 0; w < 7; w++) ...SampleData.daysFor(w)],
      );

  /// Great-circle distance, matching the server's ST_Distance_Sphere.
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
