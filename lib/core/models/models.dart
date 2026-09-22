/// Plain data classes mirroring the `/api/v1` resources.
///
/// Every field is nullable where the API may omit it. Parsing is tolerant:
/// a missing key never throws, because the app is used at temple gates on
/// networks that drop half a payload.
library;

double? _d(dynamic v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int? _i(dynamic v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
String? _s(dynamic v) => v?.toString();
bool _b(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';
Map<String, dynamic> _m(dynamic v) => v is Map<String, dynamic> ? v : const {};
List<dynamic> _l(dynamic v) => v is List ? v : const [];

enum TrustLevel {
  unverified,
  community,
  verified,
  official;

  static TrustLevel parse(String? v) => TrustLevel.values.firstWhere(
        (t) => t.name == v,
        orElse: () => TrustLevel.unverified,
      );

  String get label => switch (this) {
        TrustLevel.unverified => 'Unverified',
        TrustLevel.community => 'Community',
        TrustLevel.verified => 'Verified',
        TrustLevel.official => 'Official',
      };
}

class Trust {
  const Trust({required this.level, this.label, this.sourceName, this.sourceUrl, this.lastVerifiedAt, this.isStale = false});

  final TrustLevel level;
  final String? label;
  final String? sourceName;
  final String? sourceUrl;
  final String? lastVerifiedAt;
  final bool isStale;

  factory Trust.fromJson(Map<String, dynamic> j) => Trust(
        level: TrustLevel.parse(_s(j['level'])),
        label: _s(j['label']),
        sourceName: _s(j['source_name']),
        sourceUrl: _s(j['source_url']),
        lastVerifiedAt: _s(j['last_verified_at']),
        isStale: _b(j['is_stale']),
      );
}

class DeityRef {
  const DeityRef({required this.slug, required this.name, this.alternateNames = const [], this.templeCount});

  final String slug;
  final String name;
  final List<String> alternateNames;
  final int? templeCount;

  factory DeityRef.fromJson(Map<String, dynamic> j) => DeityRef(
        slug: _s(j['slug']) ?? '',
        name: _s(j['name']) ?? '',
        alternateNames: _l(j['alternate_names']).map((e) => '$e').toList(),
        templeCount: _i(j['temples_count'] ?? j['temple_count']),
      );
}

class CategoryRef {
  const CategoryRef({required this.slug, required this.name, this.kind, this.description, this.templeCount});

  final String slug;
  final String name;
  final String? kind;
  final String? description;
  final int? templeCount;

  factory CategoryRef.fromJson(Map<String, dynamic> j) => CategoryRef(
        slug: _s(j['slug']) ?? '',
        name: _s(j['name']) ?? '',
        kind: _s(j['kind']),
        description: _s(j['description']),
        templeCount: _i(j['temples_count'] ?? j['temple_count']),
      );
}

class StateRef {
  const StateRef({this.id, required this.slug, required this.name, this.code, this.templeCount, this.districts = const []});

  final int? id;
  final String slug;
  final String name;
  final String? code;
  final int? templeCount;
  final List<DistrictRef> districts;

  factory StateRef.fromJson(Map<String, dynamic> j) => StateRef(
        id: _i(j['id']),
        slug: _s(j['slug']) ?? '',
        name: _s(j['name']) ?? '',
        code: _s(j['code']),
        templeCount: _i(j['temples_count'] ?? j['temple_count']),
        districts: _l(j['districts']).map((e) => DistrictRef.fromJson(_m(e))).toList(),
      );
}

class DistrictRef {
  const DistrictRef({required this.slug, required this.name});

  final String slug;
  final String name;

  factory DistrictRef.fromJson(Map<String, dynamic> j) => DistrictRef(slug: _s(j['slug']) ?? '', name: _s(j['name']) ?? '');
}

class FacilityRef {
  const FacilityRef({required this.slug, required this.name, this.group, this.isVerified = false, this.note, this.templeCount});

  final String slug;
  final String name;
  final String? group;
  final bool isVerified;
  final String? note;
  final int? templeCount;

  factory FacilityRef.fromJson(Map<String, dynamic> j) => FacilityRef(
        slug: _s(j['slug']) ?? '',
        name: _s(j['name']) ?? '',
        group: _s(j['group']),
        isVerified: _b(j['is_verified']),
        note: _s(j['note']),
        templeCount: _i(j['temples_count'] ?? j['temple_count']),
      );
}

class Location {
  const Location({this.address, this.city, this.district, this.state, this.pincode, this.latitude, this.longitude});

  final String? address;
  final String? city;
  final String? district;
  final String? state;
  final String? pincode;
  final double? latitude;
  final double? longitude;

  bool get hasCoordinates => latitude != null && longitude != null;

  String get short => [city, state].where((e) => e != null && e.isNotEmpty).join(', ');

  factory Location.fromJson(Map<String, dynamic> j) => Location(
        address: _s(j['address']),
        city: _s(j['city']),
        district: _s(j['district']),
        state: _s(j['state']),
        pincode: _s(j['pincode']),
        latitude: _d(j['latitude']),
        longitude: _d(j['longitude']),
      );
}

class Photo {
  const Photo({this.id, this.category, this.caption, this.isPrimary = false, this.original, this.medium, this.thumbnail, this.credit, this.license});

  final int? id;
  final String? category;
  final String? caption;
  final bool isPrimary;
  final String? original;
  final String? medium;
  final String? thumbnail;
  final String? credit;
  final String? license;

  String? get best => medium ?? original ?? thumbnail;

  factory Photo.fromJson(Map<String, dynamic> j) {
    final urls = _m(j['urls']);
    return Photo(
      id: _i(j['id']),
      category: _s(j['category']),
      caption: _s(j['caption']),
      isPrimary: _b(j['is_primary']),
      original: _s(urls['original']),
      medium: _s(urls['medium']),
      thumbnail: _s(urls['thumbnail']),
      credit: _s(j['credit']),
      license: _s(j['license']),
    );
  }
}

class TempleSummary {
  const TempleSummary({
    required this.slug,
    required this.name,
    this.id,
    this.shortDescription,
    this.deity,
    required this.location,
    this.distanceKm,
    required this.trust,
    this.primaryPhoto,
    this.categorySlugs = const [],
  });

  final int? id;
  final String slug;
  final String name;
  final String? shortDescription;
  final DeityRef? deity;
  final Location location;
  final double? distanceKm;
  final Trust trust;
  final Photo? primaryPhoto;

  /// Only populated by the offline sample data; the summary endpoint does not
  /// carry categories.
  final List<String> categorySlugs;

  factory TempleSummary.fromJson(Map<String, dynamic> j) => TempleSummary(
        id: _i(j['id']),
        slug: _s(j['slug']) ?? '',
        name: _s(j['name']) ?? '',
        shortDescription: _s(j['short_description']),
        deity: j['deity'] is Map ? DeityRef.fromJson(_m(j['deity'])) : null,
        location: Location.fromJson(_m(j['location'])),
        distanceKm: _d(j['distance_km']),
        trust: Trust.fromJson(_m(j['trust'])),
        primaryPhoto: j['primary_photo'] is Map ? Photo.fromJson(_m(j['primary_photo'])) : null,
      );

  TempleSummary withDistance(double km) => TempleSummary(
        id: id,
        slug: slug,
        name: name,
        shortDescription: shortDescription,
        deity: deity,
        location: location,
        distanceKm: km,
        trust: trust,
        primaryPhoto: primaryPhoto,
        categorySlugs: categorySlugs,
      );
}

class Timing {
  const Timing({this.kind, this.label, this.dayOfWeek, this.dayLabel, this.opensAt, this.closesAt, this.window, this.notes});

  final String? kind;
  final String? label;
  final int? dayOfWeek;
  final String? dayLabel;
  final String? opensAt;
  final String? closesAt;
  final String? window;
  final String? notes;

  factory Timing.fromJson(Map<String, dynamic> j) => Timing(
        kind: _s(j['kind']),
        label: _s(j['label']),
        dayOfWeek: _i(j['day_of_week']),
        dayLabel: _s(j['day_label']),
        opensAt: _s(j['opens_at']),
        closesAt: _s(j['closes_at']),
        window: _s(j['window']),
        notes: _s(j['notes']),
      );
}

class Fee {
  const Fee({this.isFree = false, this.amount, this.currency, this.label});

  final bool isFree;
  final double? amount;
  final String? currency;

  /// Rendered verbatim. `amount == null` means "no published price", never
  /// "free"; only `isFree` means free.
  final String? label;

  factory Fee.fromJson(Map<String, dynamic> j) => Fee(
        isFree: _b(j['is_free']),
        amount: _d(j['amount']),
        currency: _s(j['currency']),
        label: _s(j['label']),
      );

  String get display {
    if (label != null && label!.isNotEmpty) return label!;
    if (isFree) return 'Free';
    if (amount == null) return 'No published price';
    return '${currency ?? 'INR'} ${amount!.toStringAsFixed(0)}';
  }
}

class Booking {
  const Booking({this.url, this.isOfficial = false, this.label, this.note});

  final String? url;

  /// The single field that decides whether a link may be shown as official.
  final bool isOfficial;
  final String? label;
  final String? note;

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        url: _s(j['url']),
        isOfficial: _b(j['is_official']),
        label: _s(j['label']),
        note: _s(j['note']),
      );
}

class Puja {
  const Puja({
    this.id,
    required this.name,
    this.description,
    this.imageUrl,
    this.includes,
    this.eligibility,
    this.startsAt,
    this.durationLabel,
    this.scheduleNote,
    required this.fee,
    required this.booking,
  });

  final int? id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String? includes;
  final String? eligibility;
  final String? startsAt;
  final String? durationLabel;
  final String? scheduleNote;
  final Fee fee;
  final Booking booking;

  factory Puja.fromJson(Map<String, dynamic> j) => Puja(
        id: _i(j['id']),
        name: _s(j['name']) ?? '',
        description: _s(j['description']),
        imageUrl: _s(j['image_url']),
        includes: _s(j['includes']),
        eligibility: _s(j['eligibility']),
        startsAt: _s(j['starts_at']),
        durationLabel: _s(j['duration_label']),
        scheduleNote: _s(j['schedule_note']),
        fee: Fee.fromJson(_m(j['fee'])),
        booking: Booking.fromJson(_m(j['booking'])),
      );
}

class Closure {
  const Closure({this.reason, this.startsOn, this.endsOn, this.isFullDay = true, this.isActiveToday = false, this.notes});

  final String? reason;
  final String? startsOn;
  final String? endsOn;
  final bool isFullDay;
  final bool isActiveToday;
  final String? notes;

  factory Closure.fromJson(Map<String, dynamic> j) => Closure(
        reason: _s(j['reason']),
        startsOn: _s(j['starts_on']),
        endsOn: _s(j['ends_on']),
        isFullDay: _b(j['is_full_day']),
        isActiveToday: _b(j['is_active_today']),
        notes: _s(j['notes']),
      );
}

class TempleEvent {
  const TempleEvent({
    this.id,
    this.type,
    required this.title,
    this.description,
    this.imageUrl,
    this.startsOn,
    this.endsOn,
    this.dateLabel,
    this.isHappeningToday = false,
    this.templeSlug,
    this.templeName,
    this.templeCity,
  });

  final int? id;
  final String? type;
  final String title;
  final String? description;
  final String? imageUrl;
  final String? startsOn;
  final String? endsOn;
  final String? dateLabel;
  final bool isHappeningToday;
  final String? templeSlug;
  final String? templeName;
  final String? templeCity;

  factory TempleEvent.fromJson(Map<String, dynamic> j) {
    final t = _m(j['temple']);
    return TempleEvent(
      id: _i(j['id']),
      type: _s(j['type']),
      title: _s(j['title']) ?? '',
      description: _s(j['description']),
      imageUrl: _s(j['image_url']),
      startsOn: _s(j['starts_on']),
      endsOn: _s(j['ends_on']),
      dateLabel: _s(j['date_label']),
      isHappeningToday: _b(j['is_happening_today']),
      templeSlug: _s(t['slug']),
      templeName: _s(t['name']),
      templeCity: _s(t['city']),
    );
  }
}

class TempleDetail {
  const TempleDetail({
    required this.summary,
    this.alternateNames = const [],
    this.categories = const [],
    this.history,
    this.significance,
    this.architectureStyle,
    this.builtPeriod,
    this.visitorRules = const {},
    this.website,
    this.phone,
    this.email,
    this.timings = const [],
    this.pujas = const [],
    this.photos = const [],
    this.closures = const [],
    this.events = const [],
    this.facilities = const [],
    this.isClosedToday = false,
  });

  final TempleSummary summary;
  final List<String> alternateNames;
  final List<CategoryRef> categories;
  final String? history;
  final String? significance;
  final String? architectureStyle;
  final String? builtPeriod;
  final Map<String, String> visitorRules;
  final String? website;
  final String? phone;
  final String? email;
  final List<Timing> timings;
  final List<Puja> pujas;
  final List<Photo> photos;
  final List<Closure> closures;
  final List<TempleEvent> events;
  final List<FacilityRef> facilities;
  final bool isClosedToday;

  factory TempleDetail.fromJson(Map<String, dynamic> j) {
    final about = _m(j['about']);
    final rules = _m(j['visitor_rules']);
    final contact = _m(j['contact']);
    final photos = _l(j['photos']).map((e) => Photo.fromJson(_m(e))).toList();
    final primary = photos.where((p) => p.isPrimary).firstOrNull ?? photos.firstOrNull;
    return TempleDetail(
      summary: TempleSummary(
        id: _i(j['id']),
        slug: _s(j['slug']) ?? '',
        name: _s(j['name']) ?? '',
        shortDescription: _s(about['short_description']),
        deity: j['deity'] is Map ? DeityRef.fromJson(_m(j['deity'])) : null,
        location: Location.fromJson(_m(j['location'])),
        trust: Trust.fromJson(_m(j['trust'])),
        primaryPhoto: primary,
        categorySlugs: _l(j['categories']).map((e) => _s(_m(e)['slug']) ?? '').toList(),
      ),
      alternateNames: _l(j['alternate_names']).map((e) => _s(_m(e)['name']) ?? '').where((e) => e.isNotEmpty).toList(),
      categories: _l(j['categories']).map((e) => CategoryRef.fromJson(_m(e))).toList(),
      history: _s(about['history']),
      significance: _s(about['significance']),
      architectureStyle: _s(about['architecture_style']),
      builtPeriod: _s(about['built_period']),
      visitorRules: {
        for (final e in rules.entries)
          if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
      },
      website: _s(contact['website']),
      phone: _s(contact['phone']),
      email: _s(contact['email']),
      timings: _l(j['timings']).map((e) => Timing.fromJson(_m(e))).toList(),
      pujas: _l(j['pujas']).map((e) => Puja.fromJson(_m(e))).toList(),
      photos: photos,
      closures: _l(j['closures']).map((e) => Closure.fromJson(_m(e))).toList(),
      events: _l(j['events']).map((e) => TempleEvent.fromJson(_m(e))).toList(),
      facilities: _l(j['facilities']).map((e) => FacilityRef.fromJson(_m(e))).toList(),
      isClosedToday: _b(j['is_closed_today']),
    );
  }
}

class DevotionalMedia {
  const DevotionalMedia({
    this.type,
    required this.title,
    this.description,
    this.sourceType,
    this.url,
    this.thumbnailUrl,
    this.durationLabel,
    this.artist,
    this.credit,
    this.license,
    this.licenseUrl,
  });

  final String? type;
  final String title;
  final String? description;
  final String? sourceType;
  final String? url;
  final String? thumbnailUrl;
  final String? durationLabel;
  final String? artist;
  final String? credit;
  final String? license;
  final String? licenseUrl;

  factory DevotionalMedia.fromJson(Map<String, dynamic> j) => DevotionalMedia(
        type: _s(j['type']),
        title: _s(j['title']) ?? '',
        description: _s(j['description']),
        sourceType: _s(j['source_type']),
        url: _s(j['url']),
        thumbnailUrl: _s(j['thumbnail_url']),
        durationLabel: _s(j['duration_label']),
        artist: _s(j['artist']),
        credit: _s(j['credit']),
        license: _s(j['license']),
        licenseUrl: _s(j['license_url']),
      );
}

class DevotionalDay {
  const DevotionalDay({
    required this.weekday,
    this.weekdayName,
    required this.title,
    this.subtitle,
    this.significance,
    this.mantra,
    this.mantraTransliteration,
    this.accentColor,
    this.deity,
    this.media = const [],
    this.temples = const [],
  });

  final int weekday;
  final String? weekdayName;
  final String title;
  final String? subtitle;
  final String? significance;
  final String? mantra;
  final String? mantraTransliteration;
  final String? accentColor;
  final DeityRef? deity;
  final List<DevotionalMedia> media;
  final List<TempleSummary> temples;

  factory DevotionalDay.fromJson(Map<String, dynamic> j) => DevotionalDay(
        weekday: _i(j['weekday']) ?? 0,
        weekdayName: _s(j['weekday_name']),
        title: _s(j['title']) ?? '',
        subtitle: _s(j['subtitle']),
        significance: _s(j['significance']),
        mantra: _s(j['mantra']),
        mantraTransliteration: _s(j['mantra_transliteration']),
        accentColor: _s(j['accent_color']),
        deity: j['deity'] is Map ? DeityRef.fromJson(_m(j['deity'])) : null,
        media: _l(j['media']).map((e) => DevotionalMedia.fromJson(_m(e))).toList(),
        temples: _l(j['temples']).map((e) => TempleSummary.fromJson(_m(e))).toList(),
      );
}

class Devotee {
  const Devotee({this.id, required this.name, this.email, this.phone, this.avatarUrl, this.locale, this.homeState, this.dateOfBirth, this.isVerified = false, this.joinedAt});

  final int? id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? locale;
  final String? homeState;
  final String? dateOfBirth;
  final bool isVerified;
  final String? joinedAt;

  factory Devotee.fromJson(Map<String, dynamic> j) => Devotee(
        id: _i(j['id']),
        name: _s(j['name']) ?? 'Devotee',
        email: _s(j['email']),
        phone: _s(j['phone']),
        avatarUrl: _s(j['avatar_url']),
        locale: _s(j['locale']),
        homeState: _s(j['home_state']),
        dateOfBirth: _s(j['date_of_birth']),
        isVerified: _b(j['is_verified']),
        joinedAt: _s(j['joined_at']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatar_url': avatarUrl,
        'locale': locale,
        'home_state': homeState,
        'date_of_birth': dateOfBirth,
        'is_verified': isVerified,
        'joined_at': joinedAt,
      };
}

class Paged<T> {
  const Paged({required this.items, this.currentPage = 1, this.lastPage = 1, this.total});

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int? total;

  bool get hasMore => currentPage < lastPage;
}
