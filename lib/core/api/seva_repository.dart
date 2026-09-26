import '../models/models.dart';
import '../models/seva.dart';
import 'api_client.dart';

/// Photographs and a video picked on the device, ready to upload.
class SevaUpload {
  const SevaUpload({this.photos = const [], this.videoPath, this.videoUrl, this.caption});

  final List<String> photos;
  final String? videoPath;
  final String? videoUrl;
  final String? caption;

  bool get isEmpty => photos.isEmpty && videoPath == null && (videoUrl == null || videoUrl!.isEmpty);

  Map<String, String> get files => {
        for (var i = 0; i < photos.length; i++) 'photos[$i]': photos[i],
        if (videoPath != null) 'video': videoPath!,
      };

  Map<String, String> get fields => {
        if (videoUrl != null && videoUrl!.isNotEmpty) 'video_url': videoUrl!,
        if (caption != null && caption!.isNotEmpty) 'caption': caption!,
      };
}

/// Seva drives over `/api/v1/seva-drives` and `/api/v1/me/seva-drives`.
///
/// Online only, unlike the passport: joining a drive or asking for money is
/// something the organiser and the other volunteers need to see now, and a
/// queued sign-up that arrives after the day helps nobody.
class SevaRepository {
  SevaRepository(this._api);

  final ApiClient _api;

  List<SevaDrive> _list(Map<String, dynamic> body) => (body['data'] as List? ?? const []).map((e) => SevaDrive.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  SevaDrive _one(Map<String, dynamic> body) => SevaDrive.fromJson(Map<String, dynamic>.from(body['data'] as Map));

  /// [when] is 'upcoming' (can still be joined) or 'done' (finished work).
  Future<Paged<SevaDrive>> list({String when = 'upcoming', String? cause, String? q, String? temple, bool verifiedOnly = false, int page = 1}) async {
    final body = await _api.get('seva-drives', {'when': when, 'cause': cause, 'q': q, 'temple': temple, 'verified': verifiedOnly ? '1' : null, 'page': '$page'});
    final meta = Map<String, dynamic>.from(body['meta'] as Map? ?? const {});
    return Paged(
      items: _list(body),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
      total: (meta['total'] as num?)?.toInt(),
    );
  }

  /// The state, district and towns for a PIN code; null when it has none.
  Future<PincodeInfo?> pincode(String code) async {
    try {
      final body = await _api.get('pincode/$code');
      return PincodeInfo.fromJson(Map<String, dynamic>.from(body['data'] as Map));
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// Drives I organised, or ([joined]) the ones I am going to.
  Future<List<SevaDrive>> mine({bool joined = false}) async => _list(await _api.get('me/seva-drives', {'scope': joined ? 'joined' : null}));

  Future<SevaDrive> show(int id) async => _one(await _api.get('seva-drives/$id'));

  Future<SevaDrive> create(Map<String, String> fields, SevaUpload media) async => _one(await _api.upload('me/seva-drives', files: media.files, fields: {...fields, ...media.fields}));

  Future<SevaDrive> update(int id, Map<String, dynamic> fields) async => _one(await _api.patch('me/seva-drives/$id', fields));

  Future<void> addMedia(int id, String stage, SevaUpload media) => _api.upload('me/seva-drives/$id/media', files: media.files, fields: {'stage': stage, ...media.fields});

  Future<void> removeMedia(int id, int mediaId) => _api.delete('me/seva-drives/$id/media/$mediaId');

  Future<SevaDrive> complete(int id, String note) async => _one(await _api.post('me/seva-drives/$id/complete', {'completion_note': note}));

  Future<SevaDrive> cancel(int id) async => _one(await _api.post('me/seva-drives/$id/cancel', const {}));

  Future<SevaDrive> join(int id, {int partySize = 1, String? note}) async => _one(await _api.post('seva-drives/$id/join', {'party_size': partySize, if (note != null && note.isNotEmpty) 'note': note}));

  Future<SevaDrive> leave(int id) async => _one(await _api.delete('seva-drives/$id/join'));

  Future<List<SevaVolunteer>> volunteers(int id) async => ((await _api.get('me/seva-drives/$id/volunteers'))['data'] as List? ?? const []).map((e) => SevaVolunteer.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<List<SevaDonation>> donations(int id) async => ((await _api.get('me/seva-drives/$id/donations'))['data'] as List? ?? const []).map((e) => SevaDonation.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<void> reportDonation(int id, {required int amount, String? upiRef, String? paymentApp, DateTime? paidOn, String? message, bool anonymous = false}) => _api.post('seva-drives/$id/donations', {
        'amount': amount,
        if (upiRef != null && upiRef.isNotEmpty) 'upi_ref': upiRef,
        if (paymentApp != null) 'payment_app': paymentApp,
        if (paidOn != null) 'paid_on': '${paidOn.year.toString().padLeft(4, '0')}-${paidOn.month.toString().padLeft(2, '0')}-${paidOn.day.toString().padLeft(2, '0')}',
        if (message != null && message.isNotEmpty) 'message': message,
        'is_anonymous': anonymous,
      });

  /// Ask the team to verify the drive; they answer with a badge or a note.
  Future<SevaDrive> requestVerification(int id, {String? note}) async => _one(await _api.post('me/seva-drives/$id/request-verification', {if (note != null && note.isNotEmpty) 'note': note}));

  /// Tell the team something is wrong with a drive. Goes through Support, so
  /// the reporter gets a reference and replies like any other report.
  Future<String?> report(SevaDrive drive, {required String reason, required String details, String? name, String? email}) async {
    final body = await _api.post('support', {
      'kind': 'report',
      'category': reason == 'inappropriate' ? 'inappropriate_content' : (reason == 'duplicate' ? 'duplicate' : 'wrong_information'),
      'subject': 'Seva drive: ${drive.title}',
      'body': '${reportReasons.firstWhere((r) => r.$1 == reason, orElse: () => reportReasons.last).$2}\n\n$details'.trim(),
      'about_type': 'seva_drive',
      'about_id': drive.id,
      if (name != null && name.isNotEmpty) 'name': name,
      if (email != null && email.isNotEmpty) 'email': email,
    });
    return (body['data'] as Map?)?['reference']?.toString();
  }

  static const reportReasons = <(String, String)>[
    ('misleading', 'Misleading — not what it claims'),
    ('fake', 'The place or photographs are not real'),
    ('money', 'Asking for money dishonestly'),
    ('unsafe', 'Unsafe, or damages a heritage site'),
    ('inappropriate', 'Inappropriate photos or text'),
    ('duplicate', 'Duplicate of another drive'),
    ('other', 'Something else'),
  ];

  Future<void> confirmDonation(int id, int donationId, {bool received = true}) => _api.post('me/seva-drives/$id/donations/$donationId/confirm', {'received': received});
}
