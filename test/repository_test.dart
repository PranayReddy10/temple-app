import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/models/models.dart';

void main() {
  TempleRepository offlineRepo() => TempleRepository(ApiClient(
        baseUrl: 'http://localhost:1',
        client: MockClient((_) async => throw http.ClientException('offline')),
      ));

  group('offline fallback', () {
    test('search by alternate name finds Tirumala', () async {
      final r = await offlineRepo().temples(const TempleQuery(q: 'Tirupati'));
      expect(r.isOffline, isTrue);
      expect(r.data.items.map((t) => t.slug), contains('sri-venkateswara-swamy-temple-tirumala'));
    });

    test('deity and category filters compose', () async {
      final r = await offlineRepo().temples(const TempleQuery(deity: 'shiva', category: 'jyotirlinga'));
      expect(r.data.items, isNotEmpty);
      expect(r.data.items.every((t) => t.deity?.slug == 'shiva' && t.categorySlugs.contains('jyotirlinga')), isTrue);
    });

    test('nearby orders by distance and respects radius', () async {
      // Hyderabad.
      final r = await offlineRepo().temples(const TempleQuery(lat: 17.3850, lng: 78.4867, radiusKm: 200));
      expect(r.data.items.first.slug, 'yadadri-lakshmi-narasimha-temple');
      expect(r.data.items.every((t) => t.distanceKm! <= 200), isTrue);
      for (var i = 1; i < r.data.items.length; i++) {
        expect(r.data.items[i].distanceKm!, greaterThanOrEqualTo(r.data.items[i - 1].distanceKm!));
      }
    });

    test('every bundled temple is community level, never official', () async {
      final r = await offlineRepo().temples(const TempleQuery(perPage: 50));
      expect(r.data.items.every((t) => t.trust.level == TrustLevel.community), isTrue);
      final v = await offlineRepo().temples(const TempleQuery(verifiedOnly: true));
      expect(v.data.items, isEmpty);
    });

    test('unknown slug is a 404, not a fallback', () async {
      expect(() => offlineRepo().temple('no-such-temple'), throwsA(isA<ApiException>().having((e) => e.isNotFound, 'isNotFound', true)));
    });

    test('today returns the weekday lead deity', () async {
      final r = await offlineRepo().today();
      expect(r.data.first.weekday, DateTime.now().weekday % 7);
    });
  });

  group('live parsing', () {
    test('paginated list parses meta', () async {
      final repo = TempleRepository(ApiClient(
        baseUrl: 'http://api.test/',
        client: MockClient((req) async {
          expect(req.url.path, '/api/v1/temples');
          expect(req.url.queryParameters['deity'], 'shiva');
          return http.Response(
            jsonEncode({
              'data': [
                {'slug': 'a', 'name': 'A', 'location': {}, 'trust': {'level': 'official'}},
              ],
              'meta': {'current_page': 1, 'last_page': 3, 'total': 41},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ));
      final r = await repo.temples(const TempleQuery(deity: 'shiva'));
      expect(r.isOffline, isFalse);
      expect(r.data.hasMore, isTrue);
      expect(r.data.total, 41);
      expect(r.data.items.single.trust.level, TrustLevel.official);
    });

    test('422 surfaces field errors', () async {
      final api = ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((_) async => http.Response(
              jsonEncode({'message': 'Both lat and lng are required for a nearby search.', 'errors': {'lng': ['Both lat and lng are required for a nearby search.']}}),
              422,
            )),
      );
      expect(
        () => api.get('temples', {'lat': '1'}),
        throwsA(isA<ApiException>().having((e) => e.errors['lng']?.single, 'lng error', contains('lat and lng'))),
      );
    });
  });

  test('great-circle distance matches a known pair', () {
    // Hyderabad to Tirumala is roughly 415 km.
    final km = TempleRepository.distanceKm(17.3850, 78.4867, 13.6833, 79.3474);
    expect(km, closeTo(423, 15));
  });
}
