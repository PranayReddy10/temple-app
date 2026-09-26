/// Seva drives: devotees organising the care of an old temple or heritage
/// place, and others joining them. Mirrors `GET /api/v1/seva-drives`.
library;

class SevaCause {
  const SevaCause(this.value, this.label, this.description);

  final String value;
  final String label;
  final String description;

  /// The same list the server serves from `/seva-drives/options`, bundled so
  /// the form works before that answer arrives.
  static const all = <SevaCause>[
    SevaCause('cleaning', 'Cleaning & clearing', 'Clearing litter, weeds and debris from an old temple or its grounds.'),
    SevaCause('water_body', 'Temple tank / stepwell', 'Desilting and cleaning a kalyani, pushkarini or stepwell.'),
    SevaCause('restoration', 'Repair & restoration', 'Fixing broken steps, walls or flooring, with permission.'),
    SevaCause('painting', 'Whitewash & painting', 'Whitewashing walls and repainting where it is allowed.'),
    SevaCause('lighting', 'Lamps & lighting', 'Lamps for a shrine that sits in the dark.'),
    SevaCause('plantation', 'Trees & garden', 'Planting and tending trees or a nandavanam.'),
    SevaCause('documentation', 'Photographing & recording', 'Photographing inscriptions and carvings before they are lost.'),
    SevaCause('other', 'Something else', 'Any other care for a place that needs it.'),
  ];

  static SevaCause of(String? value) => all.firstWhere((c) => c.value == value, orElse: () => all.last);
}

class SevaMedia {
  const SevaMedia({required this.id, required this.stage, required this.type, this.url, this.isLink = false, this.caption});

  final int id;

  /// 'before' or 'after'.
  final String stage;

  /// 'photo' or 'video'.
  final String type;
  final String? url;

  /// A video that lives elsewhere (YouTube, Instagram) rather than a file.
  final bool isLink;
  final String? caption;

  bool get isPhoto => type == 'photo';

  factory SevaMedia.fromJson(Map<String, dynamic> j) => SevaMedia(
        id: (j['id'] as num).toInt(),
        stage: '${j['stage'] ?? 'before'}',
        type: '${j['type'] ?? 'photo'}',
        url: j['url']?.toString(),
        isLink: j['is_link'] == true,
        caption: j['caption']?.toString(),
      );
}

class SevaDonations {
  const SevaDonations({this.open = false, this.upiId, this.upiName, this.upiLink, this.goal, this.purpose, this.raised, this.donors = 0});

  /// Staff verified the work and the UPI ID may be shown.
  final bool open;
  final String? upiId;
  final String? upiName;
  final String? upiLink;
  final int? goal;
  final String? purpose;

  /// Only what the organiser confirmed receiving.
  final int? raised;

  /// People whose donation the organiser confirmed.
  final int donors;

  double? get progress => goal == null || goal == 0 || raised == null ? null : (raised! / goal!).clamp(0, 1).toDouble();

  factory SevaDonations.fromJson(Map<String, dynamic>? j) => j == null
      ? const SevaDonations()
      : SevaDonations(
          open: j['open'] == true,
          upiId: j['upi_id']?.toString(),
          upiName: j['upi_name']?.toString(),
          upiLink: j['upi_link']?.toString(),
          goal: (j['goal'] as num?)?.toInt(),
          purpose: j['purpose']?.toString(),
          raised: (j['raised'] as num?)?.toInt(),
          donors: (j['donors'] as num?)?.toInt() ?? 0,
        );
}

class SevaDrive {
  const SevaDrive({
    required this.id,
    required this.title,
    required this.cause,
    required this.status,
    required this.statusLabel,
    required this.placeName,
    this.address,
    this.pincode,
    this.district,
    this.city,
    this.state,
    this.latitude,
    this.longitude,
    this.meetingPoint,
    this.templeSlug,
    this.templeName,
    required this.problem,
    required this.plan,
    this.whatToBring,
    required this.startsAt,
    this.endsAt,
    this.volunteersNeeded,
    this.volunteersJoined = 0,
    this.signups = 0,
    this.organiserName,
    this.organiserAvatar,
    this.isTeam = false,
    this.isMultiDay = false,
    this.isMisleading = false,
    this.misleadingNote,
    this.blockReason,
    this.contactPhone,
    this.coverUrl,
    this.before = const [],
    this.after = const [],
    this.completionNote,
    this.completedAt,
    this.verifiedAt,
    this.donations = const SevaDonations(),
    this.isOrganiser = false,
    this.hasJoined = false,
    this.canJoin = false,
    this.canEdit = false,
    this.canComplete = false,
    this.canLeave = false,
    this.canRequestVerification = false,
    this.isVerified = false,
    this.verificationRequested = false,
    this.myDonations = const [],
    this.supporters = const [],
    this.moderationNote,
    this.myUpiId,
    this.myUpiName,
  });

  final int id;
  final String title;
  final SevaCause cause;

  /// pending | approved | rejected | completed | verified | cancelled
  final String status;
  final String statusLabel;

  final String placeName;
  final String? address;
  final String? pincode;
  final String? district;
  final String? city;
  final String? state;
  final double? latitude;
  final double? longitude;
  final String? meetingPoint;
  final String? templeSlug;
  final String? templeName;

  final String problem;
  final String plan;
  final String? whatToBring;
  final DateTime startsAt;
  final DateTime? endsAt;

  final int? volunteersNeeded;
  final int volunteersJoined;
  final int signups;

  final String? organiserName;
  final String? organiserAvatar;

  /// Run by the team rather than a devotee.
  final bool isTeam;

  /// Spans more than one calendar day.
  final bool isMultiDay;

  /// Staff flagged it: shown with this warning, closed to joining and giving.
  final bool isMisleading;
  final String? misleadingNote;

  /// Why staff blocked it, for the organiser.
  final String? blockReason;

  /// Only for the organiser and for volunteers who have joined.
  final String? contactPhone;

  final String? coverUrl;
  final List<SevaMedia> before;
  final List<SevaMedia> after;
  final String? completionNote;
  final DateTime? completedAt;
  final DateTime? verifiedAt;
  final SevaDonations donations;

  final bool isOrganiser;
  final bool hasJoined;
  final bool canJoin;
  final bool canEdit;
  final bool canComplete;

  /// A volunteer can back out while the drive is open — verified or not.
  final bool canLeave;
  final bool canRequestVerification;

  /// The team's badge. Separate from the status: a verified drive may still
  /// be upcoming, and an unverified one is still listed.
  final bool isVerified;

  /// The organiser asked and the team has not answered yet.
  final bool verificationRequested;

  /// What the signed-in devotee gave, each marked paid once confirmed.
  final List<MyDonation> myDonations;

  /// Confirmed donations, for everyone to see.
  final List<SevaSupporter> supporters;

  /// What staff said, for the organiser.
  final String? moderationNote;
  final String? myUpiId;
  final String? myUpiName;

  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isOpen => status == 'approved';
  bool get isDone => status == 'completed';
  bool get isCancelled => status == 'cancelled';
  bool get isBlocked => status == 'blocked';

  /// Calendar days it spans, counting both ends.
  int get dayCount => endsAt == null ? 1 : DateTime(endsAt!.year, endsAt!.month, endsAt!.day).difference(DateTime(startsAt.year, startsAt.month, startsAt.day)).inDays + 1;
  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isUpcoming => isOpen && startsAt.isAfter(DateTime.now());

  String get where => [placeName, city, district, state].whereType<String>().where((s) => s.isNotEmpty).join(', ');

  double? get volunteerProgress => volunteersNeeded == null || volunteersNeeded == 0 ? null : (volunteersJoined / volunteersNeeded!).clamp(0, 1).toDouble();

  /// Where the drive is along raised → open → completed, 0 to 2.
  int get stage => switch (status) {
        'approved' => 1,
        'completed' => 2,
        _ => 0,
      };

  factory SevaDrive.fromJson(Map<String, dynamic> j) {
    final place = Map<String, dynamic>.from(j['place'] as Map? ?? const {});
    final temple = j['temple'] is Map ? Map<String, dynamic>.from(j['temple'] as Map) : null;
    final organiser = j['organiser'] is Map ? Map<String, dynamic>.from(j['organiser'] as Map) : null;
    final media = j['media'] is Map ? Map<String, dynamic>.from(j['media'] as Map) : const <String, dynamic>{};
    final viewer = Map<String, dynamic>.from(j['viewer'] as Map? ?? const {});
    final mine = j['mine'] is Map ? Map<String, dynamic>.from(j['mine'] as Map) : null;
    List<SevaMedia> list(String key) => (media[key] as List? ?? const []).map((e) => SevaMedia.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    double? num_(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
    return SevaDrive(
      id: (j['id'] as num).toInt(),
      title: '${j['title'] ?? ''}',
      cause: SevaCause.of((j['cause'] as Map?)?['value']?.toString()),
      status: '${(j['status'] as Map?)?['value'] ?? 'pending'}',
      statusLabel: '${(j['status'] as Map?)?['label'] ?? ''}',
      placeName: '${place['name'] ?? ''}',
      address: place['address']?.toString(),
      pincode: place['pincode']?.toString(),
      district: place['district']?.toString(),
      city: place['city']?.toString(),
      state: place['state']?.toString(),
      latitude: num_(place['latitude']),
      longitude: num_(place['longitude']),
      meetingPoint: place['meeting_point']?.toString(),
      templeSlug: temple?['slug']?.toString(),
      templeName: temple?['name']?.toString(),
      problem: '${j['problem'] ?? ''}',
      plan: '${j['plan'] ?? ''}',
      whatToBring: j['what_to_bring']?.toString(),
      startsAt: DateTime.tryParse('${j['starts_at']}')?.toLocal() ?? DateTime.now(),
      endsAt: DateTime.tryParse('${j['ends_at'] ?? ''}')?.toLocal(),
      volunteersNeeded: (j['volunteers_needed'] as num?)?.toInt(),
      volunteersJoined: (j['volunteers_joined'] as num?)?.toInt() ?? 0,
      signups: (j['signups'] as num?)?.toInt() ?? 0,
      organiserName: organiser?['name']?.toString(),
      organiserAvatar: organiser?['avatar_url']?.toString(),
      isTeam: organiser?['is_team'] == true,
      isMultiDay: j['is_multi_day'] == true,
      isMisleading: j['is_misleading'] == true,
      misleadingNote: j['misleading_note']?.toString(),
      blockReason: mine?['block_reason']?.toString(),
      contactPhone: j['contact_phone']?.toString(),
      coverUrl: j['cover_url']?.toString(),
      before: list('before'),
      after: list('after'),
      completionNote: j['completion_note']?.toString(),
      completedAt: DateTime.tryParse('${j['completed_at'] ?? ''}')?.toLocal(),
      verifiedAt: DateTime.tryParse('${j['verified_at'] ?? ''}')?.toLocal(),
      donations: SevaDonations.fromJson(j['donations'] is Map ? Map<String, dynamic>.from(j['donations'] as Map) : null),
      isOrganiser: viewer['is_organiser'] == true,
      hasJoined: viewer['has_joined'] == true,
      canJoin: viewer['can_join'] == true,
      canEdit: viewer['can_edit'] == true,
      canComplete: viewer['can_complete'] == true,
      canLeave: viewer['can_leave'] == true || (viewer['has_joined'] == true && '${(j['status'] as Map?)?['value']}' == 'approved'),
      canRequestVerification: viewer['can_request_verification'] == true,
      isVerified: j['is_verified'] == true,
      verificationRequested: (j['verification'] as Map?)?['requested'] == true,
      myDonations: (j['my_donations'] as List? ?? const []).map((e) => MyDonation.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      supporters: (j['supporters'] as List? ?? const []).map((e) => SevaSupporter.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      moderationNote: mine?['moderation_note']?.toString(),
      myUpiId: mine?['upi_id']?.toString(),
      myUpiName: mine?['upi_name']?.toString(),
    );
  }
}

class SevaVolunteer {
  const SevaVolunteer({required this.id, this.name, this.avatarUrl, this.partySize = 1, this.note});

  final int id;
  final String? name;
  final String? avatarUrl;
  final int partySize;
  final String? note;

  factory SevaVolunteer.fromJson(Map<String, dynamic> j) => SevaVolunteer(
        id: (j['id'] as num).toInt(),
        name: j['name']?.toString(),
        avatarUrl: j['avatar_url']?.toString(),
        partySize: (j['party_size'] as num?)?.toInt() ?? 1,
        note: j['note']?.toString(),
      );
}

class SevaDonation {
  const SevaDonation({required this.id, required this.amount, this.donor, this.upiRef, this.paymentApp, this.paidOn, this.message, this.confirmed = false, this.createdAt});

  final int id;
  final int amount;
  final String? donor;
  final String? upiRef;

  /// "PhonePe", "Google Pay"… as the donor picked it.
  final String? paymentApp;
  final DateTime? paidOn;
  final String? message;
  final bool confirmed;
  final DateTime? createdAt;

  factory SevaDonation.fromJson(Map<String, dynamic> j) => SevaDonation(
        id: (j['id'] as num).toInt(),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        donor: j['donor']?.toString(),
        upiRef: j['upi_ref']?.toString(),
        paymentApp: j['payment_app_label']?.toString(),
        paidOn: DateTime.tryParse('${j['paid_on'] ?? ''}'),
        message: j['message']?.toString(),
        confirmed: j['confirmed'] == true,
        createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
      );
}

/// What a PIN code covers, from `GET /api/v1/pincode/{code}`.
/// Where a place is, from a PIN code or from a pin dropped on the map.
///
/// The PIN code lookup fills state, district and the towns under the code;
/// the map (`GET /geocode/reverse`) also knows the street and which one of
/// those towns you are actually standing in, and the code itself.
class PincodeInfo {
  const PincodeInfo({this.pincode, this.state, this.stateId, this.district, this.places = const [], this.city, this.address});

  /// Null when the map had no PIN code for the spot.
  final String? pincode;
  final String? state;
  final int? stateId;
  final String? district;

  /// Post office names: the villages and towns under this code.
  final List<String> places;

  /// The village or town at the pin, when it came from the map.
  final String? city;

  /// Street and landmark at the pin, when it came from the map.
  final String? address;

  factory PincodeInfo.fromJson(Map<String, dynamic> j) => PincodeInfo(
        pincode: j['pincode']?.toString(),
        state: j['state']?.toString(),
        stateId: (j['state_id'] as num?)?.toInt(),
        district: j['district']?.toString(),
        places: (j['places'] as List? ?? const []).map((e) => '${(e as Map)['name']}').toList(),
        city: j['city']?.toString(),
        address: j['address']?.toString(),
      );
}

/// How a donor paid, as the server lists them in `/seva-drives/options`.
const sevaPaymentApps = <(String, String)>[
  ('phonepe', 'PhonePe'),
  ('gpay', 'Google Pay'),
  ('paytm', 'Paytm'),
  ('bhim', 'BHIM'),
  ('amazonpay', 'Amazon Pay'),
  ('other_upi', 'Another UPI app'),
  ('bank', 'Bank transfer'),
  ('cash', 'Cash'),
];

/// One of the signed-in devotee's own donations to a drive.
class MyDonation {
  const MyDonation({required this.id, required this.amount, this.paymentApp, this.paidOn, this.upiRef, this.confirmed = false});

  final int id;
  final int amount;
  final String? paymentApp;
  final DateTime? paidOn;
  final String? upiRef;

  /// The organiser confirmed it arrived: shown as paid.
  final bool confirmed;

  factory MyDonation.fromJson(Map<String, dynamic> j) => MyDonation(
        id: (j['id'] as num).toInt(),
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        paymentApp: j['payment_app_label']?.toString(),
        paidOn: DateTime.tryParse('${j['paid_on'] ?? ''}'),
        upiRef: j['upi_ref']?.toString(),
        confirmed: j['confirmed'] == true,
      );
}

/// A confirmed donation as everyone sees it.
class SevaSupporter {
  const SevaSupporter({required this.name, required this.amount, this.paidOn});

  final String name;
  final int amount;
  final DateTime? paidOn;

  factory SevaSupporter.fromJson(Map<String, dynamic> j) => SevaSupporter(
        name: '${j['name'] ?? 'A devotee'}',
        amount: (j['amount'] as num?)?.toInt() ?? 0,
        paidOn: DateTime.tryParse('${j['paid_on'] ?? ''}'),
      );
}
