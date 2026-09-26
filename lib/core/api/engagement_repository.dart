import '../models/models.dart';
import '../state/favourites_controller.dart' show SavedTemple;
import 'api_client.dart';

/// A followed temple with what it may send.
class FollowedTemple {
  const FollowedTemple({required this.temple, this.notifyFestivals = true, this.notifyEvents = true});

  final TempleSummary temple;
  final bool notifyFestivals;
  final bool notifyEvents;

  factory FollowedTemple.fromJson(Map<String, dynamic> j) => FollowedTemple(
        temple: TempleSummary.fromJson(Map<String, dynamic>.from(j['temple'] as Map)),
        notifyFestivals: j['notify_festivals'] == true,
        notifyEvents: j['notify_events'] == true,
      );

  /// Kept on the device the way saved temples are: enough to draw a card,
  /// plus the temple's id, which names its push topic. Without it, a follow
  /// read back after a restart could never be unsubscribed.
  Map<String, dynamic> toJson() => {'temple': SavedTemple.fromSummary(temple).toJson(), 'temple_id': temple.id, 'notify_festivals': notifyFestivals, 'notify_events': notifyEvents};

  factory FollowedTemple.fromStored(Map<String, dynamic> j) => FollowedTemple(
        temple: SavedTemple.fromJson(Map<String, dynamic>.from(j['temple'] as Map)).toSummary(id: (j['temple_id'] as num?)?.toInt()),
        notifyFestivals: j['notify_festivals'] == true,
        notifyEvents: j['notify_events'] == true,
      );

  FollowedTemple copyWith({bool? notifyFestivals, bool? notifyEvents}) => FollowedTemple(temple: temple, notifyFestivals: notifyFestivals ?? this.notifyFestivals, notifyEvents: notifyEvents ?? this.notifyEvents);
}

/// What a temple's reviews endpoint answers: the page and the summary.
class ReviewPage {
  const ReviewPage({required this.reviews, required this.summary, this.lastPage = 1});

  final List<Review> reviews;
  final ReviewSummary summary;
  final int lastPage;
}

/// Likes, follows and accounts of visits, over `/api/v1`.
class EngagementRepository {
  EngagementRepository(this._api);

  final ApiClient _api;

  Engagement _state(Map<String, dynamic> body) => Engagement.fromJson(Map<String, dynamic>.from(body['data'] as Map));

  Future<Engagement> like(String slug) async => _state(await _api.put('me/likes/$slug'));
  Future<Engagement> unlike(String slug) async => _state(await _api.delete('me/likes/$slug'));

  Future<Engagement> follow(String slug, {bool? notifyFestivals, bool? notifyEvents}) async => _state(await _api.put('me/follows/$slug', {
        if (notifyFestivals != null) 'notify_festivals': notifyFestivals,
        if (notifyEvents != null) 'notify_events': notifyEvents,
      }));
  Future<Engagement> unfollow(String slug) async => _state(await _api.delete('me/follows/$slug'));

  Future<List<TempleSummary>> likes() async => ((await _api.get('me/likes'))['data'] as List? ?? const []).map((e) => TempleSummary.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<List<FollowedTemple>> follows() async => ((await _api.get('me/follows'))['data'] as List? ?? const []).map((e) => FollowedTemple.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<ReviewPage> reviews(String slug, {int page = 1}) async {
    final body = await _api.get('temples/$slug/reviews', {'page': '$page'});
    final meta = Map<String, dynamic>.from((body['meta'] as Map?) ?? const {});
    return ReviewPage(
      reviews: (body['data'] as List? ?? const []).map((e) => Review.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      summary: meta['summary'] is Map ? ReviewSummary.fromJson(Map<String, dynamic>.from(meta['summary'] as Map)) : ReviewSummary.empty,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
    );
  }

  Future<List<Review>> myReviews() async => ((await _api.get('me/reviews'))['data'] as List? ?? const []).map((e) => Review.fromJson(Map<String, dynamic>.from(e as Map))).toList();

  Future<Review> write(String slug, {String? visitedOn, int? visitId, Map<String, int> ratings = const {}, int? waitMinutes, String? body}) async {
    final json = await _api.post('temples/$slug/reviews', {
      if (visitedOn != null) 'visited_on': visitedOn,
      if (visitId != null) 'visit_id': visitId,
      ...ratings,
      if (waitMinutes != null) 'wait_minutes': waitMinutes,
      if (body != null && body.isNotEmpty) 'body': body,
    });
    return Review.fromJson(Map<String, dynamic>.from(json['data'] as Map));
  }

  Future<void> remove(int id) => _api.delete('me/reviews/$id');
}
