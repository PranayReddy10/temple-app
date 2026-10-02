import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a festival parses from the API and from the bundled file alike', () {
    final api = Festival.fromJson({'slug': 'diwali', 'name': 'Diwali (Lakshmi Puja)', 'starts_on': '2026-11-08', 'kind': 'festival', 'is_major': true, 'deity': 'lakshmi', 'tithi': 'Ashwin Krishna Amavasya'});
    final bundled = Festival.fromJson({'slug': 'diwali', 'name': 'Diwali (Lakshmi Puja)', 'date': '2026-11-08', 'kind': 'festival', 'is_major': true});
    expect(api.startsOn, '2026-11-08');
    expect(bundled.startsOn, '2026-11-08');
    expect(api.toEvent().title, 'Diwali (Lakshmi Puja)');
    expect(api.toEvent().endsOn, '2026-11-08');
    expect(Festival.fromJson({'name': 'Kamada Ekadashi', 'date': '2026-03-29', 'kind': 'vrat'}).isVrat, isTrue);
  });

  test('the calendar has India\'s festivals even with no server', () async {
    final repo = TempleRepository(ApiClient(baseUrl: 'http://api.test', client: MockClient((_) async => throw http.ClientException('offline'))));
    final r = await repo.festivals(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30));
    expect(r.isOffline, isTrue);
    expect(r.data.map((f) => f.slug), contains('diwali'));
    expect(r.data.firstWhere((f) => f.slug == 'diwali').startsOn, '2026-11-08');
    expect(r.data.every((f) => f.startsOn.startsWith('2026-11') || (f.endsOn ?? '').startsWith('2026-11')), isTrue);
  });

  test('the server\'s calendar wins when it answers', () async {
    final repo = TempleRepository(ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
      expect(r.url.path, '/api/v1/festivals');
      expect(r.url.queryParameters['from'], '2026-11-01');
      return http.Response(jsonEncode({'data': [{'slug': 'diwali', 'name': 'Diwali', 'starts_on': '2026-11-09', 'kind': 'festival', 'is_major': true}]}), 200, headers: {'content-type': 'application/json'});
    })));
    final r = await repo.festivals(from: DateTime(2026, 11, 1), to: DateTime(2026, 11, 30));
    expect(r.isOffline, isFalse);
    expect(r.data.single.startsOn, '2026-11-09');
  });
}
