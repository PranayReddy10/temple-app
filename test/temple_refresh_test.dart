import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/temple_repository.dart';

/// A temple page carries likes, follows and reviews, so it must not be kept
/// for the whole session: a review just published has to appear on it.
void main() {
  var reviews = 0;
  var online = true;
  var calls = 0;

  TempleRepository repo() => TempleRepository(ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((r) async {
          if (!online) throw http.ClientException('offline');
          calls++;
          return http.Response(
            jsonEncode({
              'data': {
                'id': 7,
                'slug': 'srisailam',
                'name': 'Srisailam',
                'engagement': {'likes_count': 0, 'follows_count': 0, 'reviews': {'count': reviews, 'dimensions': {}, 'latest': []}},
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ));

  setUp(() {
    reviews = 0;
    online = true;
    calls = 0;
  });

  test('reopening briefly reuses the page, but a fresh load asks the server', () async {
    final r = repo();
    expect((await r.temple('srisailam')).data.engagement.reviews.count, 0);

    reviews = 1; // the devotee publishes a review
    await r.temple('srisailam');
    expect(calls, 1, reason: 'reopened within a couple of minutes: reused');

    final after = await r.temple('srisailam', fresh: true);
    expect(calls, 2);
    expect(after.data.engagement.reviews.count, 1, reason: 'the page shows the review just published');
  });

  test('offline, the last copy fetched this session is shown rather than the sample', () async {
    final r = repo();
    reviews = 3;
    await r.temple('srisailam');
    online = false;
    final offline = await r.temple('srisailam', fresh: true);
    expect(offline.isOffline, isTrue);
    expect(offline.data.engagement.reviews.count, 3);
  });
}
