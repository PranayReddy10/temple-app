import 'api_client.dart';

/// A temple the devotee added from the app, as the editors left it.
class TempleSuggestionItem {
  const TempleSuggestionItem({required this.id, required this.name, this.place, required this.status, required this.statusLabel, this.reviewNote, this.templeSlug, this.templeName, this.photoUrl, this.createdAt});

  final int id;
  final String name;
  final String? place;

  /// pending | approved | duplicate | rejected
  final String status;
  final String statusLabel;
  final String? reviewNote;

  /// Where it is listed now, once it is public.
  final String? templeSlug;
  final String? templeName;
  final String? photoUrl;
  final DateTime? createdAt;

  factory TempleSuggestionItem.fromJson(Map<String, dynamic> j) {
    final temple = j['temple'] is Map ? Map<String, dynamic>.from(j['temple'] as Map) : null;
    final photos = (j['photos'] as List? ?? const []);
    return TempleSuggestionItem(
      id: (j['id'] as num).toInt(),
      name: '${j['name'] ?? ''}',
      place: [j['city'], j['district'], j['state']].whereType<String>().where((s) => s.isNotEmpty).join(', '),
      status: '${(j['status'] as Map?)?['value'] ?? 'pending'}',
      statusLabel: '${(j['status'] as Map?)?['label'] ?? ''}',
      reviewNote: j['review_note']?.toString(),
      templeSlug: temple?['slug']?.toString(),
      templeName: temple?['name']?.toString(),
      photoUrl: photos.isEmpty ? null : '${photos.first}',
      createdAt: DateTime.tryParse('${j['created_at'] ?? ''}')?.toLocal(),
    );
  }
}

/// "My temple is not listed" over `/api/v1/me/temple-suggestions`.
class TempleSuggestionRepository {
  TempleSuggestionRepository(this._api);

  final ApiClient _api;

  /// Who is adding it, as the server offers them.
  static const roles = <(String, String)>[
    ('devotee', 'A devotee who visits'),
    ('trustee', 'Trustee'),
    ('priest', 'Priest / archaka'),
    ('committee', 'Temple committee member'),
    ('staff', 'Temple office staff'),
    ('other', 'Someone else'),
  ];

  static bool isTempleMember(String role) => role != 'devotee' && role != 'other';

  Future<TempleSuggestionItem> submit(Map<String, String> fields, List<String> photos) async {
    final body = await _api.upload('me/temple-suggestions', files: {for (var i = 0; i < photos.length; i++) 'photos[$i]': photos[i]}, fields: fields);
    return TempleSuggestionItem.fromJson(Map<String, dynamic>.from(body['data'] as Map));
  }

  Future<List<TempleSuggestionItem>> mine() async => ((await _api.get('me/temple-suggestions'))['data'] as List? ?? const []).map((e) => TempleSuggestionItem.fromJson(Map<String, dynamic>.from(e as Map))).toList();
}
