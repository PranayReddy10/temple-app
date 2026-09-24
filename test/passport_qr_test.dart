import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/data/sample_data.dart';
import 'package:temple_app/core/state/app_settings.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/memories_controller.dart';
import 'package:temple_app/core/state/passport_controller.dart';
import 'package:temple_app/core/state/submissions_controller.dart';
import 'package:temple_app/core/state/sync_service.dart';
import 'package:temple_app/core/state/yatra_controller.dart';
import 'package:temple_app/features/qr/qr_screens.dart';

void main() {
  group('passport codes', () {
    const code = 'Ab3dEf6hIj9kLm2nOp4q';

    test('read from the link, the app scheme or bare', () {
      expect(PassportCode.parse('https://templepassport.in/passport/$code'), code);
      expect(PassportCode.parse('templepassport://passport/$code'), code);
      expect(PassportCode.parse('  $code '), code);
    });

    test('a temple code, a slug or the old id form is not a passport', () {
      expect(PassportCode.parse('https://templepassport.in/temples/somnath-temple/checkin?s=abc'), isNull);
      expect(PassportCode.parse('kashi-vishwanath-temple'), isNull);
      expect(PassportCode.parse('templepassport://devotee/12'), isNull);
      // And a temple slug is still read as one.
      expect(TempleQr.parse('kashi-vishwanath-temple')?.slug, 'kashi-vishwanath-temple');
    });
  });

  group('memory photos', () {
    test('three a visit, kept across restarts, removable', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final passport = PassportController(prefs);
      final v = await passport.checkIn(SampleData.temples.first);

      for (var i = 0; i < 3; i++) {
        expect(await passport.addMemoryPhoto(v, '/m$i.jpg'), isNotNull);
      }
      expect(await passport.addMemoryPhoto(v, '/m3.jpg'), isNull, reason: 'a visit keeps three');

      final again = PassportController(prefs);
      expect(again.byKey(v.localKey)!.memoryPhotos.map((m) => m.path), ['/m0.jpg', '/m1.jpg', '/m2.jpg']);
      // Memory photos never become the passport photo.
      expect(again.byKey(v.localKey)!.photoPath, isNull);

      final removed = await again.removeMemoryPhoto(again.byKey(v.localKey)!, 1);
      expect(removed?.path, '/m1.jpg');
      expect(again.byKey(v.localKey)!.memoryPhotos.length, 2);
    });
  });

  group('staff-marked visits and memory sync', () {
    late Directory tmp;
    setUp(() => tmp = Directory.systemTemp.createTempSync('memories'));
    tearDown(() => tmp.deleteSync(recursive: true));

    test('a visit marked at the counter comes back as staff, and memories upload privately once the visit has', () async {
      SharedPreferences.setMockInitialValues({'devotee_token': 't', 'devotee': jsonEncode({'id': 1, 'name': 'Anu'})});
      final prefs = await SharedPreferences.getInstance();
      final uploads = <http.BaseRequest>[];
      final deletes = <String>[];
      var visitsOnline = false;
      final client = MockClient.streaming((request, body) async {
        final path = request.url.path.replaceFirst('/api/v1/', '');
        http.StreamedResponse json(Object o, [int status = 200]) => http.StreamedResponse(Stream.value(utf8.encode(jsonEncode(o))), status, headers: {'content-type': 'application/json'});
        if (request.method == 'POST' && path.endsWith('/visits')) {
          if (!visitsOnline) throw http.ClientException('offline');
          return json({'data': {'id': 41, 'temple': {'id': 7, 'slug': path.split('/')[1], 'name': 'T'}, 'visited_on': '2026-09-01', 'method': {'value': 'manual'}, 'is_verified': false}}, 201);
        }
        if (request.method == 'POST' && path.endsWith('/photos')) {
          uploads.add(request);
          await body.drain<void>();
          return json({'data': {'id': 77, 'visit_id': 41, 'kind': 'memory', 'original_url': 'https://cdn.test/m.jpg', 'status': {'value': 'pending'}}}, 201);
        }
        if (request.method == 'DELETE') {
          deletes.add(path);
          return json({'data': {}});
        }
        if (request.method == 'GET' && path == 'me/visits') {
          return json({'data': [{'id': 41, 'temple': {'id': 7, 'slug': SampleData.temples.first.slug, 'name': 'T'}, 'visited_on': '2026-09-01', 'method': {'value': 'staff'}, 'is_verified': true}]});
        }
        if (request.method == 'GET' && path == 'me/photos') {
          return json({'data': [{'id': 78, 'visit_id': 41, 'kind': 'memory', 'original_url': 'https://cdn.test/other-device.jpg', 'status': {'value': 'pending'}}]});
        }
        if (request.method == 'GET' && path == 'me/passport') return json({'data': {'stamps': 1, 'temples_visited': 1, 'visits_recorded': 1, 'photos': 0, 'memories': 0, 'states_covered': 1, 'circuits': []}});
        if (request.method == 'GET') return json({'data': []});
        return json({'message': 'nope'}, 404);
      });
      final api = ApiClient(baseUrl: 'http://api.test', client: client);
      final auth = AuthController(prefs, api);
      final passport = PassportController(prefs);
      final sync = SyncService(prefs: prefs, api: api, auth: auth, settings: AppSettings(prefs, api), passport: passport, yatras: YatraController(prefs), memories: MemoriesController(prefs), submissions: SubmissionsController(prefs));

      final v = await passport.checkIn(SampleData.temples.first);
      final file = File('${tmp.path}/m.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0xD9]);
      final withMemory = await passport.addMemoryPhoto(v, file.path);
      await sync.queueMemoryPhoto(withMemory!, file.path);
      await sync.flush();
      expect(uploads, isEmpty, reason: 'the photo waits for its visit');

      visitsOnline = true;
      await sync.sync();

      expect(uploads, hasLength(1));
      final sent = uploads.single as http.MultipartRequest;
      expect(sent.fields['kind'], 'memory');
      expect(sent.fields['is_public'], '0');
      expect(sent.fields['visit_id'], '41');

      final synced = passport.byKey(v.localKey)!;
      expect(synced.verification, Verification.staff);
      expect(synced.isVerified, isTrue);
      expect(synced.memoryPhotos.map((m) => m.remoteId), [77, 78], reason: 'one from here, one from another device');

      final removed = await passport.removeMemoryPhoto(synced, 0);
      await sync.removeMemoryPhoto(removed!);
      await sync.flush();
      expect(deletes, ['me/photos/77']);
    });
  });
}
