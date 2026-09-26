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
  const DeityRef({required this.slug, required this.name, this.alternateNames = const [], this.templeCount, this.description, this.imageUrl, this.mantra, this.mantraTransliteration, this.mantraMeaning});

  final String slug;
  final String name;
  final List<String> alternateNames;
  final int? templeCount;
  final String? description;

  /// From the API's deity record: an image, and a mantra with its meaning.
  final String? imageUrl;
  final String? mantra;
  final String? mantraTransliteration;
  final String? mantraMeaning;

  factory DeityRef.fromJson(Map<String, dynamic> j) => DeityRef(
        slug: _s(j['slug']) ?? '',
        name: _s(j['name']) ?? '',
        alternateNames: _l(j['alternate_names']).map((e) => '$e').toList(),
        templeCount: _i(j['temples_count'] ?? j['temple_count']),
        description: _s(j['description']),
        imageUrl: _s(j['image_url']),
        mantra: _s(j['mantra']),
        mantraTransliteration: _s(j['mantra_transliteration']),
        mantraMeaning: _s(j['mantra_meaning']),
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
  const Photo({this.id, this.category, this.caption, this.isPrimary = false, this.original, this.medium, this.thumbnail, this.credit, this.license, this.isDevoteePhoto = false, this.devoteeName, this.devoteeAvatarUrl});

  final int? id;
  final String? category;
  final String? caption;
  final bool isPrimary;
  final String? original;
  final String? medium;
  final String? thumbnail;
  final String? credit;
  final String? license;

  /// Promoted from a devotee's Photo Stamp: shown with their first name.
  final bool isDevoteePhoto;
  final String? devoteeName;
  final String? devoteeAvatarUrl;

  String? get best => medium ?? original ?? thumbnail;

  factory Photo.fromJson(Map<String, dynamic> j) {
    final urls = _m(j['urls']);
    final devotee = _m(j['devotee']);
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
      isDevoteePhoto: _b(j['is_devotee_photo']),
      devoteeName: _s(devotee['name']),
      devoteeAvatarUrl: _s(devotee['avatar_url']),
    );
  }
}

/// One dimension of how visits went: the average across published accounts
/// and how many said so. There is no overall score, on purpose.
class RatingDimension {
  const RatingDimension({required this.key, required this.label, this.average, this.count = 0});

  final String key;
  final String label;
  final double? average;
  final int count;

  factory RatingDimension.fromJson(String key, Map<String, dynamic> j) => RatingDimension(key: key, label: _s(j['label']) ?? key, average: _d(j['average']), count: _i(j['count']) ?? 0);
}

class ReviewSummary {
  const ReviewSummary({this.count = 0, this.dimensions = const [], this.averageWaitMinutes});

  static const empty = ReviewSummary();

  final int count;
  final List<RatingDimension> dimensions;
  final int? averageWaitMinutes;

  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
        count: _i(j['count']) ?? 0,
        dimensions: [for (final e in _m(j['dimensions']).entries) RatingDimension.fromJson(e.key, _m(e.value))],
        averageWaitMinutes: _i(j['average_wait_minutes']),
      );
}

/// Where the signed-in devotee stands with a temple: what they tapped.
class ViewerEngagement {
  const ViewerEngagement({this.liked = false, this.following = false, this.notifyFestivals = false, this.notifyEvents = false, this.saved = false});

  final bool liked;
  final bool following;
  final bool notifyFestivals;
  final bool notifyEvents;
  final bool saved;

  factory ViewerEngagement.fromJson(Map<String, dynamic> j) => ViewerEngagement(
        liked: _b(j['liked']),
        following: _b(j['following']),
        notifyFestivals: _b(j['notify_festivals']),
        notifyEvents: _b(j['notify_events']),
        saved: _b(j['saved']),
      );
}

/// What devotees added to a temple: likes and follows as counts, and how
/// visits went. `viewer` is null for a guest.
class Engagement {
  const Engagement({this.likesCount = 0, this.followsCount = 0, this.viewer, this.reviews = ReviewSummary.empty});

  static const none = Engagement();

  final int likesCount;
  final int followsCount;
  final ViewerEngagement? viewer;
  final ReviewSummary reviews;

  factory Engagement.fromJson(Map<String, dynamic> j) => Engagement(
        likesCount: _i(j['likes_count']) ?? 0,
        followsCount: _i(j['follows_count']) ?? 0,
        viewer: j['viewer'] is Map ? ViewerEngagement.fromJson(_m(j['viewer'])) : null,
        reviews: j['reviews'] is Map ? ReviewSummary.fromJson(_m(j['reviews'])) : ReviewSummary.empty,
      );

  Engagement copyWith({int? likesCount, int? followsCount, ViewerEngagement? viewer, ReviewSummary? reviews}) =>
      Engagement(likesCount: likesCount ?? this.likesCount, followsCount: followsCount ?? this.followsCount, viewer: viewer ?? this.viewer, reviews: reviews ?? this.reviews);
}

/// One rating inside an account of a visit.
class ReviewRating {
  const ReviewRating({required this.key, required this.label, this.value});

  final String key;
  final String label;
  final int? value;

  factory ReviewRating.fromJson(Map<String, dynamic> j) => ReviewRating(key: _s(j['key']) ?? '', label: _s(j['label']) ?? '', value: _i(j['value']));
}

/// A devotee's account of a visit, as `GET /temples/{slug}/reviews` returns it.
class Review {
  const Review({
    this.id,
    this.templeSlug,
    this.templeName,
    required this.devoteeName,
    this.devoteeAvatarUrl,
    this.homeState,
    this.visitedOn,
    this.ratings = const [],
    this.waitMinutes,
    this.body,
    this.templeReply,
    this.templeRepliedAt,
    this.isMine = false,
    this.status,
    this.statusLabel,
    this.moderationNote,
    this.createdAt,
  });

  final int? id;
  final String? templeSlug;
  final String? templeName;
  final String devoteeName;
  final String? devoteeAvatarUrl;
  final String? homeState;
  final String? visitedOn;
  final List<ReviewRating> ratings;
  final int? waitMinutes;
  final String? body;
  final String? templeReply;
  final String? templeRepliedAt;
  final bool isMine;

  /// pending, approved or rejected: returned only to the author.
  final String? status;
  final String? statusLabel;
  final String? moderationNote;
  final String? createdAt;

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  factory Review.fromJson(Map<String, dynamic> j) {
    final devotee = _m(j['devotee']);
    final temple = _m(j['temple']);
    final status = _m(j['status']);
    return Review(
      id: _i(j['id']),
      templeSlug: _s(temple['slug']),
      templeName: _s(temple['name']),
      devoteeName: _s(devotee['name']) ?? 'A devotee',
      devoteeAvatarUrl: _s(devotee['avatar_url']),
      homeState: _s(devotee['home_state']),
      visitedOn: _s(j['visited_on']),
      ratings: _l(j['ratings']).map((e) => ReviewRating.fromJson(_m(e))).toList(),
      waitMinutes: _i(j['wait_minutes']),
      body: _s(j['body']),
      templeReply: _s(j['temple_reply']),
      templeRepliedAt: _s(j['temple_replied_at']),
      isMine: _b(j['is_mine']),
      status: _s(status['value']),
      statusLabel: _s(status['label']),
      moderationNote: _s(j['moderation_note']),
      createdAt: _s(j['created_at']),
    );
  }
}

/// The five things a devotee may rate about a visit, in the order they are
/// asked. Mirrors the server's list; the server's labels win when present.
const reviewDimensions = <(String key, String label, String low, String high)>[
  ('queue_rating', 'Queue and waiting', 'Very long', 'No wait'),
  ('cleanliness_rating', 'Cleanliness', 'Poor', 'Spotless'),
  ('facilities_rating', 'Facilities', 'Few', 'Everything needed'),
  ('accessibility_rating', 'Accessibility', 'Hard', 'Easy for everyone'),
  ('accuracy_rating', 'Our listing was accurate', 'Mostly wrong', 'Spot on'),
];

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
    this.isFeatured = false,
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

  /// An editor's "famous temple" mark. A curation choice, not a trust claim:
  /// [trust] still says how far the record can be relied on.
  final bool isFeatured;

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
        isFeatured: _b(j['is_featured']),
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
        isFeatured: isFeatured,
      );
}

/// A temple's verse: its own, or its deity's when it has none.
class Mantra {
  const Mantra({this.text, this.transliteration, this.meaning, this.isOwn = false, this.audio});

  final String? text;
  final String? transliteration;
  final String? meaning;

  /// Whether the verse is the owner's own, or its deity's. The app renders
  /// the two differently.
  final bool isOwn;

  /// The recording attached in the admin panel, or null: the normal case.
  final DevotionalMedia? audio;

  bool get isEmpty => text == null || text!.isEmpty;

  factory Mantra.fromJson(Map<String, dynamic> j) => Mantra(
        text: _s(j['text']),
        transliteration: _s(j['transliteration']),
        meaning: _s(j['meaning']),
        isOwn: _b(j['is_own']) || _b(j['is_temple_specific']),
        audio: j['audio'] is Map ? DevotionalMedia.fromJson(_m(j['audio'])) : null,
      );
}

/// How the server says a media item plays. Classified there so a released
/// build never has to pattern-match hosts it was compiled before seeing.
class Playback {
  const Playback({this.kind = 'link', this.isPlayable = false, this.needsEmbed = false, this.embedUrl, this.youtubeId});

  /// One of audio, video, youtube, vimeo, link.
  final String kind;
  final bool isPlayable;
  final bool needsEmbed;
  final String? embedUrl;
  final String? youtubeId;

  factory Playback.fromJson(Map<String, dynamic> j) => Playback(
        kind: _s(j['kind']) ?? 'link',
        isPlayable: _b(j['is_playable']),
        needsEmbed: _b(j['needs_embed']),
        embedUrl: _s(j['embed_url']),
        youtubeId: _s(j['youtube_id']),
      );

  /// A best guess for payloads that predate the block, and for the bundled
  /// catalogue.
  static Playback guess(String? url, String? sourceType) {
    if (url == null) return const Playback();
    final u = Uri.tryParse(url);
    final host = (u?.host ?? '').toLowerCase().replaceFirst('www.', '');
    if (host == 'youtu.be' || host.endsWith('youtube.com') || host == 'youtube-nocookie.com') {
      String? id;
      if (host == 'youtu.be') {
        id = u!.pathSegments.firstOrNull;
      } else if (u!.queryParameters['v'] != null) {
        id = u.queryParameters['v'];
      } else if (u.pathSegments.length >= 2 && const ['embed', 'shorts', 'live', 'v'].contains(u.pathSegments.first)) {
        id = u.pathSegments[1];
      }
      id = id == null || !RegExp(r'^[A-Za-z0-9_-]{6,}$').hasMatch(id) ? null : id;
      return Playback(kind: 'youtube', needsEmbed: true, embedUrl: id == null ? null : 'https://www.youtube.com/embed/$id', youtubeId: id);
    }
    if (host == 'vimeo.com' || host == 'player.vimeo.com') {
      final id = u!.pathSegments.lastOrNull;
      return Playback(kind: 'vimeo', needsEmbed: true, embedUrl: id == null ? null : 'https://player.vimeo.com/video/$id');
    }
    final ext = (u?.path ?? url).split('?').first.split('.').last.toLowerCase();
    if (const ['mp3', 'm4a', 'aac', 'ogg', 'oga', 'opus', 'wav', 'flac'].contains(ext)) return const Playback(kind: 'audio', isPlayable: true);
    if (const ['mp4', 'webm', 'mov', 'm4v'].contains(ext)) return const Playback(kind: 'video', isPlayable: true);
    return const Playback();
  }
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

/// Booking through the app, where the temple has switched it on for this
/// seva. `enabled` false means the listing is information only and the card
/// shows it exactly as before; nothing here is compulsory for a temple.
class AppBooking {
  const AppBooking({
    this.enabled = false,
    this.requiresPayment = false,
    this.feePerPerson = true,
    this.amountPaise = 0,
    this.maxPeople = 10,
    this.advanceDays = 30,
    this.capacityPerDay,
    this.instructions,
  });

  static const off = AppBooking();

  final bool enabled;
  final bool requiresPayment;
  final bool feePerPerson;

  /// What one person (or one booking, when the fee is not per person) costs.
  final int amountPaise;
  final int maxPeople;
  final int advanceDays;
  final int? capacityPerDay;

  /// Where to report, what to bring, how early to come.
  final String? instructions;

  factory AppBooking.fromJson(Map<String, dynamic> j) => AppBooking(
        enabled: _b(j['enabled']),
        requiresPayment: _b(j['requires_payment']),
        feePerPerson: j.containsKey('fee_per_person') ? _b(j['fee_per_person']) : true,
        amountPaise: _i(j['amount_paise']) ?? 0,
        maxPeople: _i(j['max_people']) ?? 10,
        advanceDays: _i(j['advance_days']) ?? 30,
        capacityPerDay: _i(j['capacity_per_day']),
        instructions: _s(j['instructions']),
      );

  /// The total for this many people, in paise.
  int totalFor(int people) => feePerPerson ? amountPaise * people : amountPaise;
}

class Puja {
  const Puja({
    this.id,
    this.kind = 'puja',
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
    this.appBooking = AppBooking.off,
  });

  final int? id;

  /// puja, seva or prasadam: how the temple files it, and how the app
  /// groups the list.
  final String kind;
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
  final AppBooking appBooking;

  bool get isBookableInApp => appBooking.enabled && id != null;

  factory Puja.fromJson(Map<String, dynamic> j) => Puja(
        id: _i(j['id']),
        kind: _s(j['kind']) ?? 'puja',
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
        appBooking: j['app_booking'] is Map ? AppBooking.fromJson(_m(j['app_booking'])) : AppBooking.off,
      );

  /// The heading the list shows over this kind.
  static String kindLabel(String kind) => switch (kind) {
        'seva' => 'Sevas',
        'prasadam' => 'Prasadam',
        _ => 'Pujas',
      };
}

/// A puja, seva or prasadam the devotee booked through the app, as
/// `GET /me/bookings` returns it: the reference the counter reads out, the
/// code its scanner checks, and where it stands.
class PujaBooking {
  const PujaBooking({
    required this.reference,
    required this.code,
    this.qrUrl,
    required this.status,
    required this.statusLabel,
    this.isLive = false,
    this.templeSlug,
    this.templeName,
    this.templeCity,
    this.pujaId,
    required this.pujaName,
    this.pujaKind = 'puja',
    this.pujaStartsAt,
    this.pujaImageUrl,
    this.instructions,
    required this.bookedFor,
    this.people = 1,
    required this.devoteeName,
    this.devoteePhone,
    this.gotram,
    this.nakshatram,
    this.note,
    this.amountPaise = 0,
    this.amountLabel = 'Free',
    this.paymentId,
    this.paymentStatus,
    this.verifiedAt,
    this.cancelledAt,
    this.cancelReason,
    this.canCancel = false,
    this.createdAt,
  });

  final String reference;
  final String code;
  final String? qrUrl;

  /// pending_payment, confirmed, verified, cancelled, refunded.
  final String status;
  final String statusLabel;
  final bool isLive;
  final String? templeSlug;
  final String? templeName;
  final String? templeCity;
  final int? pujaId;
  final String pujaName;
  final String pujaKind;
  final String? pujaStartsAt;
  final String? pujaImageUrl;
  final String? instructions;
  final DateTime bookedFor;
  final int people;
  final String devoteeName;
  final String? devoteePhone;
  final String? gotram;
  final String? nakshatram;
  final String? note;
  final int amountPaise;
  final String amountLabel;
  final String? paymentId;
  final String? paymentStatus;
  final String? verifiedAt;
  final String? cancelledAt;
  final String? cancelReason;
  final bool canCancel;
  final String? createdAt;

  bool get isFree => amountPaise == 0;
  bool get isPendingPayment => status == 'pending_payment';
  bool get isConfirmed => status == 'confirmed';
  bool get isVerified => status == 'verified';

  /// Over: the day has passed, or it was cancelled, refunded or received.
  bool get isPast {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    return isVerified || status == 'cancelled' || status == 'refunded' || bookedFor.isBefore(day);
  }

  /// What the QR carries: the server's link, or the bare code if it gave none.
  String get qrData => qrUrl ?? code;

  factory PujaBooking.fromJson(Map<String, dynamic> j) {
    final status = _m(j['status']);
    final temple = _m(j['temple']);
    final puja = _m(j['puja']);
    final payment = _m(j['payment']);
    return PujaBooking(
      reference: _s(j['reference']) ?? '',
      code: _s(j['code']) ?? '',
      qrUrl: _s(j['qr_url']),
      status: _s(status['value']) ?? 'confirmed',
      statusLabel: _s(status['label']) ?? 'Confirmed',
      isLive: _b(j['is_live']),
      templeSlug: _s(temple['slug']),
      templeName: _s(temple['name']),
      templeCity: _s(temple['city']),
      pujaId: _i(puja['id']),
      pujaName: _s(puja['name']) ?? 'Seva',
      pujaKind: _s(puja['kind']) ?? 'puja',
      pujaStartsAt: _s(puja['starts_at']),
      pujaImageUrl: _s(puja['image_url']),
      instructions: _s(puja['instructions']),
      bookedFor: DateTime.tryParse(_s(j['booked_for']) ?? '') ?? DateTime.now(),
      people: _i(j['people']) ?? 1,
      devoteeName: _s(j['devotee_name']) ?? '',
      devoteePhone: _s(j['devotee_phone']),
      gotram: _s(j['gotram']),
      nakshatram: _s(j['nakshatram']),
      note: _s(j['note']),
      amountPaise: _i(j['amount_paise']) ?? 0,
      amountLabel: _s(j['amount']) ?? 'Free',
      paymentId: _s(payment['id']),
      paymentStatus: _s(payment['status']),
      verifiedAt: _s(j['verified_at']),
      cancelledAt: _s(j['cancelled_at']),
      cancelReason: _s(j['cancel_reason']),
      canCancel: _b(j['can_cancel']),
      createdAt: _s(j['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'reference': reference,
        'code': code,
        'qr_url': qrUrl,
        'status': {'value': status, 'label': statusLabel},
        'is_live': isLive,
        'temple': {'slug': templeSlug, 'name': templeName, 'city': templeCity},
        'puja': {'id': pujaId, 'name': pujaName, 'kind': pujaKind, 'starts_at': pujaStartsAt, 'image_url': pujaImageUrl, 'instructions': instructions},
        'booked_for': '${bookedFor.year}-${bookedFor.month.toString().padLeft(2, '0')}-${bookedFor.day.toString().padLeft(2, '0')}',
        'people': people,
        'devotee_name': devoteeName,
        'devotee_phone': devoteePhone,
        'gotram': gotram,
        'nakshatram': nakshatram,
        'note': note,
        'amount_paise': amountPaise,
        'amount': amountLabel,
        'payment': paymentId == null ? null : {'id': paymentId, 'status': paymentStatus},
        'verified_at': verifiedAt,
        'cancelled_at': cancelledAt,
        'cancel_reason': cancelReason,
        'can_cancel': canCancel,
        'created_at': createdAt,
      };
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
    this.mantra,
    this.devotionalMedia = const [],
    this.language,
    this.engagement = Engagement.none,
  });

  final TempleSummary summary;

  /// Likes, follows and how visits went. Empty from a server that predates
  /// the block, and for the bundled samples.
  final Engagement engagement;

  /// The temple's verse, falling back to its deity's. Null when the API
  /// predates the field (or the record is a bundled sample).
  final Mantra? mantra;

  /// The temple's own songs first, then its deity's. Empty when the API has
  /// nothing published; the bundled catalogue then stands in.
  final List<DevotionalMedia> devotionalMedia;
  final String? language;
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
    final cover = j['primary_photo'] is Map ? Photo.fromJson(_m(j['primary_photo'])) : null;
    final primary = cover ?? photos.where((p) => p.isPrimary).firstOrNull ?? photos.firstOrNull;
    // The cover leads the gallery even when it is not among the published rows.
    if (cover != null && !photos.any((p) => p.id == cover.id)) photos.insert(0, cover);
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
        isFeatured: _b(j['is_featured']),
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
      mantra: j['mantra'] is Map ? Mantra.fromJson(_m(j['mantra'])) : null,
      devotionalMedia: _l(j['devotional_media']).map((e) => DevotionalMedia.fromJson(_m(e))).toList(),
      language: _s(j['language']),
      engagement: j['engagement'] is Map ? Engagement.fromJson(_m(j['engagement'])) : Engagement.none,
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
    Playback? playback,
  }) : _playback = playback;

  final Playback? _playback;

  /// The server's classification when it sent one, a guess otherwise.
  Playback get playback => _playback ?? Playback.guess(url, sourceType);

  /// A poster for YouTube items that carry no thumbnail of their own.
  String? get posterUrl => thumbnailUrl ?? (playback.youtubeId == null ? null : 'https://img.youtube.com/vi/${playback.youtubeId}/hqdefault.jpg');

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
        playback: j['playback'] is Map ? Playback.fromJson(_m(j['playback'])) : null,
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
    this.mantraAudio,
  });

  /// The day's mantra with its recording, falling back to the deity's.
  final Mantra? mantraAudio;

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
        mantraAudio: j['mantra_audio'] is Map ? Mantra.fromJson(_m(j['mantra_audio'])) : null,
      );
}

class Devotee {
  const Devotee({this.id, required this.name, this.email, this.phone, this.avatarUrl, this.locale, this.homeState, this.dateOfBirth, this.gender, this.isVerified = false, this.joinedAt, this.passportUrl, this.signInMethods = const [], this.entitlements = Entitlements.free, this.subscriptionPlan, this.subscriptionEndsAt, this.homeStateId});

  final int? id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final String? locale;
  final String? homeState;
  final String? dateOfBirth;

  /// male, female, other or prefer_not_to_say; null when not given.
  final String? gender;
  final bool isVerified;
  final String? joinedAt;

  /// What the devotee's own passport QR carries: a link with a random code,
  /// never the account id. Reset from the My QR screen.
  final String? passportUrl;

  /// password, google, apple: how this account can sign in.
  final List<String> signInMethods;

  /// What the account's plan unlocks, decided by the server.
  final Entitlements entitlements;
  final String? subscriptionPlan;
  final String? subscriptionEndsAt;
  final int? homeStateId;

  factory Devotee.fromJson(Map<String, dynamic> j) => Devotee(
        id: _i(j['id']),
        name: _s(j['name']) ?? 'Devotee',
        email: _s(j['email']),
        phone: _s(j['phone']),
        avatarUrl: _s(j['avatar_url']),
        locale: _s(j['locale']),
        homeState: _s(j['home_state']),
        dateOfBirth: _s(j['date_of_birth']),
        gender: _s(j['gender']),
        isVerified: _b(j['is_verified']),
        joinedAt: _s(j['joined_at']),
        passportUrl: _s(j['passport_url']),
        signInMethods: _l(j['sign_in_methods']).map((e) => '$e').toList(),
        entitlements: j['entitlements'] is Map ? Entitlements.fromJson(_m(j['entitlements'])) : Entitlements.free,
        subscriptionPlan: _s(_m(j['subscription'])['plan']),
        subscriptionEndsAt: _s(_m(j['subscription'])['ends_at']),
        homeStateId: _i(j['home_state_id']),
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
        'gender': gender,
        'is_verified': isVerified,
        'joined_at': joinedAt,
        'passport_url': passportUrl,
        'sign_in_methods': signInMethods,
        'entitlements': entitlements.toJson(),
        if (subscriptionPlan != null) 'subscription': {'plan': subscriptionPlan, 'ends_at': subscriptionEndsAt},
        'home_state_id': homeStateId,
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

// ---------------------------------------------------------------------------
// Devotee endpoints: passport, photos, memories, yatras, support, languages.
// ---------------------------------------------------------------------------

/// A visit as the server records it.
class RemoteVisit {
  const RemoteVisit({required this.id, required this.templeSlug, required this.templeName, this.templeId, this.city, this.visitedOn, this.visitedAt, this.method, this.isVerified = false, this.distanceMetres, this.note, this.isPublic = true, this.photos = const []});

  final int id;
  final int? templeId;
  final String templeSlug;
  final String templeName;
  final String? city;
  final String? visitedOn;
  final String? visitedAt;
  final String? method;
  final bool isVerified;
  final int? distanceMetres;
  final String? note;
  final bool isPublic;
  final List<VisitPhoto> photos;

  factory RemoteVisit.fromJson(Map<String, dynamic> j) {
    final t = _m(j['temple']);
    return RemoteVisit(
      id: _i(j['id']) ?? 0,
      templeId: _i(t['id']),
      templeSlug: _s(t['slug']) ?? '',
      templeName: _s(t['name']) ?? '',
      city: _s(t['city']),
      visitedOn: _s(j['visited_on']),
      visitedAt: _s(j['visited_at']),
      method: _s(_m(j['method'])['value']),
      isVerified: _b(j['is_verified']),
      distanceMetres: _i(j['distance_metres']),
      note: _s(j['note']),
      isPublic: j['is_public'] == null ? true : _b(j['is_public']),
      photos: _l(j['photos']).map((e) => VisitPhoto.fromJson(_m(e))).toList(),
    );
  }
}

class CircuitProgress {
  const CircuitProgress({required this.slug, required this.name, required this.collected, required this.recorded, this.total});

  final String slug;
  final String name;
  final int collected;
  final int recorded;
  final int? total;

  factory CircuitProgress.fromJson(Map<String, dynamic> j) => CircuitProgress(
        slug: _s(j['slug']) ?? '',
        name: _s(j['name']) ?? '',
        collected: _i(j['collected']) ?? 0,
        recorded: _i(j['recorded']) ?? 0,
        total: _i(j['total']),
      );
}

/// `GET /me/passport`: stamps are verified visits only.
class PassportSummary {
  const PassportSummary({required this.stamps, required this.templesVisited, required this.visitsRecorded, required this.photos, required this.memories, required this.statesCovered, this.firstVisitOn, this.latestVisitOn, this.circuits = const []});

  final int stamps;
  final int templesVisited;
  final int visitsRecorded;
  final int photos;
  final int memories;
  final int statesCovered;
  final String? firstVisitOn;
  final String? latestVisitOn;
  final List<CircuitProgress> circuits;

  factory PassportSummary.fromJson(Map<String, dynamic> j) => PassportSummary(
        stamps: _i(j['stamps']) ?? 0,
        templesVisited: _i(j['temples_visited']) ?? 0,
        visitsRecorded: _i(j['visits_recorded']) ?? 0,
        photos: _i(j['photos']) ?? 0,
        memories: _i(j['memories']) ?? 0,
        statesCovered: _i(j['states_covered']) ?? 0,
        firstVisitOn: _s(j['first_visit_on']),
        latestVisitOn: _s(j['latest_visit_on']),
        circuits: _l(j['circuits']).map((e) => CircuitProgress.fromJson(_m(e))).toList(),
      );
}

class VisitPhoto {
  const VisitPhoto({required this.id, this.templeId, this.visitId, this.kind = 'stamp', this.originalUrl, this.stampUrl, this.hasStamp = false, this.caption, this.status, this.statusLabel, this.moderationNote, this.isPublic = false, this.isVisibleToOthers = false, this.createdAt});

  final int id;
  final int? templeId;
  final int? visitId;

  /// `stamp`: the photo in the passport. `memory`: one of up to three kept
  /// with the visit, never shown to anyone else.
  final String kind;
  bool get isMemory => kind == 'memory';
  final String? originalUrl;
  final String? stampUrl;
  final bool hasStamp;
  final String? caption;
  final String? status;
  final String? statusLabel;
  final String? moderationNote;
  final bool isPublic;
  final bool isVisibleToOthers;
  final String? createdAt;

  factory VisitPhoto.fromJson(Map<String, dynamic> j) => VisitPhoto(
        id: _i(j['id']) ?? 0,
        templeId: _i(j['temple_id']),
        visitId: _i(j['visit_id']),
        kind: _s(j['kind']) ?? 'stamp',
        originalUrl: _s(j['original_url']),
        stampUrl: _s(j['stamp_url']),
        hasStamp: _b(j['has_stamp']),
        caption: _s(j['caption']),
        status: _s(_m(j['status'])['value']),
        statusLabel: _s(_m(j['status'])['label']),
        moderationNote: _s(j['moderation_note']),
        isPublic: _b(j['is_public']),
        isVisibleToOthers: _b(j['is_visible_to_others']),
        createdAt: _s(j['created_at']),
      );
}

class RemoteMemory {
  const RemoteMemory({required this.id, this.title, required this.body, this.happenedOn, this.isPrivate = true, this.templeId, this.templeSlug, this.templeName, this.visitId});

  final int id;
  final String? title;
  final String body;
  final String? happenedOn;
  final bool isPrivate;
  final int? templeId;
  final String? templeSlug;
  final String? templeName;
  final int? visitId;

  factory RemoteMemory.fromJson(Map<String, dynamic> j) {
    final t = _m(j['temple']);
    return RemoteMemory(
      id: _i(j['id']) ?? 0,
      title: _s(j['title']),
      body: _s(j['body']) ?? '',
      happenedOn: _s(j['happened_on']),
      isPrivate: j['is_private'] == null ? true : _b(j['is_private']),
      templeId: _i(t['id']),
      templeSlug: _s(t['slug']),
      templeName: _s(t['name']),
      visitId: _i(j['visit_id']),
    );
  }
}

class RemoteYatraStop {
  const RemoteYatraStop({required this.id, required this.dayNumber, required this.sortOrder, this.plannedOn, this.note, this.isVisited = false, this.visitId, this.templeId, this.templeSlug, this.templeName, this.city});

  final int id;
  final int dayNumber;
  final int sortOrder;
  final String? plannedOn;
  final String? note;
  final bool isVisited;
  final int? visitId;
  final int? templeId;
  final String? templeSlug;
  final String? templeName;
  final String? city;

  factory RemoteYatraStop.fromJson(Map<String, dynamic> j) {
    final t = _m(j['temple']);
    return RemoteYatraStop(
      id: _i(j['id']) ?? 0,
      dayNumber: _i(j['day_number']) ?? 1,
      sortOrder: _i(j['sort_order']) ?? 0,
      plannedOn: _s(j['planned_on']),
      note: _s(j['note']),
      isVisited: _b(j['is_visited']),
      visitId: _i(j['visit_id']),
      templeId: _i(t['id']),
      templeSlug: _s(t['slug']),
      templeName: _s(t['name']),
      city: _s(t['city']),
    );
  }
}

class RemoteYatra {
  const RemoteYatra({required this.id, required this.title, this.description, this.status, this.startsOn, this.endsOn, this.dayCount, this.partySize, this.isPublic = false, this.stops = const [], this.updatedAt});

  final int id;
  final String title;
  final String? description;
  final String? status;
  final String? startsOn;
  final String? endsOn;
  final int? dayCount;
  final int? partySize;
  final bool isPublic;
  final List<RemoteYatraStop> stops;
  final String? updatedAt;

  factory RemoteYatra.fromJson(Map<String, dynamic> j) => RemoteYatra(
        id: _i(j['id']) ?? 0,
        title: _s(j['title']) ?? '',
        description: _s(j['description']),
        status: _s(_m(j['status'])['value']),
        startsOn: _s(j['starts_on']),
        endsOn: _s(j['ends_on']),
        dayCount: _i(j['day_count']),
        partySize: _i(j['party_size']),
        isPublic: _b(j['is_public']),
        stops: _l(j['stops']).map((e) => RemoteYatraStop.fromJson(_m(e))).toList(),
        updatedAt: _s(j['updated_at']),
      );
}

class SupportMessage {
  const SupportMessage({required this.body, required this.fromStaff, this.author, this.createdAt});

  final String body;
  final bool fromStaff;
  final String? author;
  final String? createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> j) => SupportMessage(body: _s(j['body']) ?? '', fromStaff: _b(j['from_staff']), author: _s(j['author']), createdAt: _s(j['created_at']));
}

class SupportTicket {
  const SupportTicket({required this.reference, this.kind, this.category, this.categoryLabel, this.status, this.statusLabel, this.isOpen = true, required this.subject, required this.body, this.aboutLabel, this.resolution, this.messages = const [], this.createdAt});

  final String reference;
  final String? kind;
  final String? category;
  final String? categoryLabel;
  final String? status;
  final String? statusLabel;
  final bool isOpen;
  final String subject;
  final String body;
  final String? aboutLabel;
  final String? resolution;
  final List<SupportMessage> messages;
  final String? createdAt;

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        reference: _s(j['reference']) ?? '',
        kind: _s(j['kind']),
        category: _s(_m(j['category'])['value']),
        categoryLabel: _s(_m(j['category'])['label']),
        status: _s(_m(j['status'])['value']),
        statusLabel: _s(_m(j['status'])['label']),
        isOpen: j['status'] is Map ? _b(_m(j['status'])['is_open']) : true,
        subject: _s(j['subject']) ?? '',
        body: _s(j['body']) ?? '',
        aboutLabel: _s(_m(j['about'])['label']),
        resolution: _s(j['resolution']),
        messages: _l(j['messages']).map((e) => SupportMessage.fromJson(_m(e))).toList(),
        createdAt: _s(j['created_at']),
      );
}

class SupportCategory {
  const SupportCategory({required this.value, required this.label, this.description, this.needsSubject = true});

  final String value;
  final String label;
  final String? description;
  final bool needsSubject;

  factory SupportCategory.fromJson(Map<String, dynamic> j) => SupportCategory(value: _s(j['value']) ?? '', label: _s(j['label']) ?? '', description: _s(j['description']), needsSubject: j['needs_subject'] == null ? true : _b(j['needs_subject']));
}

/// `GET /languages`: what the app may offer today.
class LanguageInfo {
  const LanguageInfo({required this.code, required this.name, required this.nativeName, this.rtl = false, this.isAvailable = true});

  final String code;
  final String name;
  final String nativeName;
  final bool rtl;
  final bool isAvailable;

  factory LanguageInfo.fromJson(Map<String, dynamic> j) => LanguageInfo(code: _s(j['code']) ?? '', name: _s(j['name']) ?? '', nativeName: _s(j['native_name']) ?? _s(j['name']) ?? '', rtl: _b(j['rtl']), isAvailable: j['is_available'] == null ? true : _b(j['is_available']));

  /// The languages the app ships interface strings and fonts for.
  static const bundled = [
    LanguageInfo(code: 'en', name: 'English', nativeName: 'English'),
    LanguageInfo(code: 'te', name: 'Telugu', nativeName: 'తెలుగు'),
    LanguageInfo(code: 'hi', name: 'Hindi', nativeName: 'हिन्दी'),
    LanguageInfo(code: 'ta', name: 'Tamil', nativeName: 'தமிழ்'),
    LanguageInfo(code: 'kn', name: 'Kannada', nativeName: 'ಕನ್ನಡ'),
  ];
}


/// `GET /passports/{code}`: someone else's passport, from the code they
/// showed. Public visits only, and nothing but a name and a photo about them.
class PublicPassport {
  const PublicPassport({required this.name, this.avatarUrl, this.homeState, this.joinedAt, this.stamps = 0, this.templesVisited = 0, this.visitsRecorded = 0, this.statesCovered = 0, this.visits = const []});

  final String name;
  final String? avatarUrl;
  final String? homeState;
  final String? joinedAt;
  final int stamps;
  final int templesVisited;
  final int visitsRecorded;
  final int statesCovered;
  final List<RemoteVisit> visits;

  factory PublicPassport.fromJson(Map<String, dynamic> j) => PublicPassport(
        name: _s(j['name']) ?? 'Devotee',
        avatarUrl: _s(j['avatar_url']),
        homeState: _s(j['home_state']),
        joinedAt: _s(j['joined_at']),
        stamps: _i(j['stamps']) ?? 0,
        templesVisited: _i(j['temples_visited']) ?? 0,
        visitsRecorded: _i(j['visits_recorded']) ?? 0,
        statesCovered: _i(j['states_covered']) ?? 0,
        visits: _l(j['visits']).map((e) => RemoteVisit.fromJson(_m(e))).toList(),
      );
}


/// What a plan unlocks. The free app: ads, three memory photos a visit.
class Entitlements {
  const Entitlements({this.noAds = false, this.memoryPhotosPerVisit = 3, this.premiumPassport = false});

  static const free = Entitlements();

  final bool noAds;
  final int memoryPhotosPerVisit;
  final bool premiumPassport;

  factory Entitlements.fromJson(Map<String, dynamic> j) => Entitlements(
        noAds: _b(j['no_ads']),
        memoryPhotosPerVisit: (_i(j['memory_photos_per_visit']) ?? 3).clamp(3, 50),
        premiumPassport: _b(j['premium_passport']),
      );

  Map<String, dynamic> toJson() => {'no_ads': noAds, 'memory_photos_per_visit': memoryPhotosPerVisit, 'premium_passport': premiumPassport};
}

/// `GET /app/config`: what the app may do right now, set in the admin panel.
class AppConfig {
  const AppConfig({
    this.maintenance = false,
    this.maintenanceTitle,
    this.maintenanceMessage,
    this.maintenanceUntil,
    this.updateAvailable = false,
    this.updateRequired = false,
    this.latestVersion,
    this.storeUrl,
    this.updateTitle,
    this.updateMessage,
    this.passwordSignIn = true,
    this.googleSignIn = false,
    this.googleServerClientId,
    this.googleIosClientId,
    this.appleSignIn = false,
    this.pushEnabled = false,
    this.firebase,
    this.ads = AdsConfig.off,
    this.paymentsEnabled = false,
    this.paymentsElsewhere = false,
    this.gateways = const [],
    this.defaultGateway,
    this.supportEmail,
  });

  static const fallback = AppConfig();

  final bool maintenance;
  final String? maintenanceTitle;
  final String? maintenanceMessage;
  final String? maintenanceUntil;
  final bool updateAvailable;
  final bool updateRequired;
  final String? latestVersion;
  final String? storeUrl;
  final String? updateTitle;
  final String? updateMessage;
  final bool passwordSignIn;
  final bool googleSignIn;
  final String? googleServerClientId;
  final String? googleIosClientId;
  final bool appleSignIn;
  final bool pushEnabled;

  /// Public Firebase ids for this platform, so no google-services file has
  /// to be built into the app.
  final Map<String, String>? firebase;
  final AdsConfig ads;
  final bool paymentsEnabled;

  /// Plans exist but cannot be bought on this platform (iOS without IAP).
  final bool paymentsElsewhere;
  final List<({String code, String name})> gateways;
  final String? defaultGateway;
  final String? supportEmail;

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final m = _m(j['maintenance']);
    final u = _m(j['update']);
    final a = _m(j['auth']);
    final p = _m(j['push']);
    final pay = _m(j['payments']);
    final fb = _m(p['firebase']);
    return AppConfig(
      maintenance: _b(m['enabled']),
      maintenanceTitle: _s(m['title']),
      maintenanceMessage: _s(m['message']),
      maintenanceUntil: _s(m['until']),
      updateAvailable: _b(u['available']),
      updateRequired: _b(u['required']),
      latestVersion: _s(u['latest_version']),
      storeUrl: _s(u['store_url']),
      updateTitle: _s(u['title']),
      updateMessage: _s(u['message']),
      passwordSignIn: a['password'] == null ? true : _b(a['password']),
      googleSignIn: _b(_m(a['google'])['enabled']),
      googleServerClientId: _s(_m(a['google'])['server_client_id']),
      googleIosClientId: _s(_m(a['google'])['ios_client_id']),
      appleSignIn: _b(_m(a['apple'])['enabled']),
      pushEnabled: _b(p['enabled']),
      firebase: fb.isEmpty ? null : {for (final e in fb.entries) if (e.value != null) e.key: '${e.value}'},
      ads: j['ads'] is Map ? AdsConfig.fromJson(_m(j['ads'])) : AdsConfig.off,
      paymentsEnabled: _b(pay['enabled']),
      paymentsElsewhere: _b(pay['available_elsewhere']),
      gateways: _l(pay['gateways']).map((g) => (code: '${_m(g)['code']}', name: '${_m(g)['name']}')).toList(),
      defaultGateway: _s(pay['default_gateway']),
      supportEmail: _s(j['support_email']),
    );
  }
}

class AdsConfig {
  const AdsConfig({this.enabled = false, this.network = 'admob', this.testMode = true, this.applovinSdkKey, this.nativeUnit, this.bannerUnit, this.listInterval = 6, this.placements = const {}});

  static const off = AdsConfig();

  final bool enabled;

  /// admob or applovin_max. Meta Audience Network serves through either.
  final String network;
  final bool testMode;
  final String? applovinSdkKey;
  final String? nativeUnit;
  final String? bannerUnit;
  final int listInterval;
  final Map<String, bool> placements;

  bool allows(String placement) => enabled && (placements[placement] ?? false) && (nativeUnit ?? '').isNotEmpty;

  factory AdsConfig.fromJson(Map<String, dynamic> j) => AdsConfig(
        enabled: _b(j['enabled']),
        network: _s(j['network']) ?? 'admob',
        testMode: j['test_mode'] == null ? true : _b(j['test_mode']),
        applovinSdkKey: _s(j['applovin_sdk_key']),
        nativeUnit: _s(_m(j['units'])['native']),
        bannerUnit: _s(_m(j['units'])['banner']),
        listInterval: (_i(j['list_interval']) ?? 6).clamp(3, 30),
        placements: {for (final e in _m(j['placements']).entries) e.key: _b(e.value)},
      );
}

/// A plan from `GET /plans`.
class SubscriptionPlan {
  const SubscriptionPlan({required this.code, required this.name, this.description, required this.price, this.period, this.badge, this.benefits = const {}});

  final String code;
  final String name;
  final String? description;
  final String price;
  final String? period;
  final String? badge;
  final Map<String, dynamic> benefits;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> j) => SubscriptionPlan(
        code: _s(j['code']) ?? '',
        name: _s(j['name']) ?? '',
        description: _s(j['description']),
        price: _s(j['price']) ?? '',
        period: _s(j['period']),
        badge: _s(j['badge']),
        benefits: _m(j['benefits']),
      );

  /// The benefits in words, in a fixed order.
  List<String> get benefitLines => [
        if (_b(benefits['no_ads'])) 'No ads anywhere in the app',
        if (_i(benefits['memory_photos_per_visit']) != null) '${_i(benefits['memory_photos_per_visit'])} memory photos with every visit',
        if (_b(benefits['premium_passport'])) 'Gold edition passport cover',
      ];
}

/// One message in the notification inbox.
class AppNotice {
  const AppNotice({required this.id, required this.title, required this.body, this.imageUrl, this.linkType = 'none', this.linkValue, this.sentAt, this.isRead});

  final int id;
  final String title;
  final String body;
  final String? imageUrl;
  final String linkType;
  final String? linkValue;
  final String? sentAt;

  /// From the server for a signed-in devotee; null for a guest.
  final bool? isRead;

  factory AppNotice.fromJson(Map<String, dynamic> j) => AppNotice(
        id: _i(j['id']) ?? 0,
        title: _s(j['title']) ?? '',
        body: _s(j['body']) ?? '',
        imageUrl: _s(j['image_url']),
        linkType: _s(_m(j['link'])['type']) ?? 'none',
        linkValue: _s(_m(j['link'])['value']),
        sentAt: _s(j['sent_at']),
        isRead: j['is_read'] == null ? null : _b(j['is_read']),
      );
}
