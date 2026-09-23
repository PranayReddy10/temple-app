import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/data/sample_data.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/state/app_settings.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/memories_controller.dart';
import 'package:temple_app/core/state/passport_controller.dart';
import 'package:temple_app/core/state/submissions_controller.dart';
import 'package:temple_app/core/state/sync_service.dart';
import 'package:temple_app/core/state/yatra_controller.dart';

/// A fake `/api/v1` that records what it was asked and answers like Laravel.
class FakeServer {
  final List<http.Request> requests = [];
  bool online = true;
  int nextId = 100;
  final Map<int, Map<String, dynamic>> yatras = {};

  http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request r) async {
    if (!online) throw http.ClientException('offline');
    requests.add(r);
    final path = r.url.path.replaceFirst('/api/v1/', '');
    final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(r.body) as Map<String, dynamic>;
    if (r.method == 'POST' && RegExp(r'^temples/[^/]+/visits$').hasMatch(path)) {
      final slug = path.split('/')[1];
      return _json({
        'data': {'id': nextId++, 'temple': {'id': 7, 'slug': slug, 'name': slug, 'city': 'X'}, 'visited_on': body['visited_on'], 'visited_at': body['visited_at'], 'method': {'value': body['method']}, 'is_verified': body['method'] == 'gps', 'note': body['note'], 'is_public': true}
      }, 201);
    }
    if (r.method == 'POST' && path == 'auth/login') return _json({'data': {'devotee': {'id': 1, 'name': 'Anu'}, 'token': 't'}});
    if (r.method == 'POST' && path == 'me/memories') return _json({'data': {'id': nextId++, 'body': body['body'], 'is_private': body['is_private']}}, 201);
    if (r.method == 'POST' && path == 'me/yatras') {
      final id = nextId++;
      yatras[id] = {'id': id, 'title': body['title'], 'status': {'value': body['status']}, 'stops': []};
      return _json({'data': yatras[id]}, 201);
    }
    if (r.method == 'PATCH' && path.startsWith('me/yatras/')) return _json({'data': yatras[int.parse(path.split('/')[2])]});
    if (r.method == 'GET' && RegExp(r'^me/yatras/\d+$').hasMatch(path)) return _json({'data': yatras[int.parse(path.split('/')[2])]});
    if (r.method == 'PUT' && path.contains('/temples/')) return _json({'data': {}}, 201);
    if (r.method == 'POST' && path == 'support') return _json({'data': {'reference': 'TP-ABC123', 'subject': body['subject'], 'body': body['body'], 'status': {'value': 'open', 'label': 'Open', 'is_open': true}, 'category': {'value': body['category'], 'label': body['category']}}}, 201);
    if (r.method == 'GET' && path == 'languages') return _json({'data': {'current': 'en', 'fallback': 'en', 'languages': [{'code': 'en', 'name': 'English', 'native_name': 'English', 'rtl': false, 'is_available': true}, {'code': 'kn', 'name': 'Kannada', 'native_name': 'ಕನ್ನಡ', 'rtl': false, 'is_available': false}]}});
    if (r.method == 'GET' && path == 'me/passport') return _json({'data': {'stamps': 3, 'temples_visited': 5, 'visits_recorded': 6, 'photos': 1, 'memories': 2, 'states_covered': 2, 'circuits': [{'slug': 'jyotirlinga', 'name': 'Jyotirlinga', 'collected': 2, 'recorded': 8, 'total': 12}]}});
    if (r.method == 'GET' && path == 'me/visits') return _json({'data': [{'id': 900, 'temple': {'id': 9, 'slug': 'somnath-temple', 'name': 'Somnath Temple', 'city': 'Prabhas Patan'}, 'visited_on': '2026-01-05', 'visited_at': '07:30', 'method': {'value': 'qr'}, 'is_verified': true, 'is_public': true, 'photos': []}]});
    if (r.method == 'GET' && path == 'me/yatras') return _json({'data': [{'id': 700, 'title': 'Char Dham', 'status': {'value': 'planning'}, 'stops': [{'id': 1, 'day_number': 1, 'sort_order': 1, 'is_visited': false, 'temple': {'id': 3, 'slug': 'badrinath-temple', 'name': 'Badrinath Temple', 'city': 'Badrinath'}}, {'id': 2, 'day_number': 2, 'sort_order': 1, 'is_visited': true, 'temple': {'id': 4, 'slug': 'kedarnath-temple', 'name': 'Kedarnath Temple', 'city': 'Kedarnath'}}]}]});
    if (r.method == 'GET' && path == 'me/memories') return _json({'data': [{'id': 500, 'title': 'Dawn', 'body': 'The bells at five.', 'happened_on': '2026-01-05', 'is_private': true, 'temple': {'id': 9, 'slug': 'somnath-temple', 'name': 'Somnath Temple'}}]});
    if (r.method == 'GET' && path == 'me/photos') return _json({'data': []});
    if (r.method == 'GET' && path == 'me/support') return _json({'data': [{'reference': 'TP-ABC123', 'subject': 's', 'body': 'b', 'status': {'value': 'resolved', 'label': 'Resolved', 'is_open': false}, 'resolution': 'Fixed the timings.', 'messages': []}]});
    return _json({'message': 'not found'}, 404);
  }
}

Future<({SyncService sync, FakeServer server, PassportController passport, YatraController yatras, MemoriesController memories, SubmissionsController submissions, AuthController auth, AppSettings settings})> build({bool signedIn = true}) async {
  SharedPreferences.setMockInitialValues(signedIn ? {'devotee_token': 't', 'devotee': jsonEncode({'id': 1, 'name': 'Anu'})} : {});
  final prefs = await SharedPreferences.getInstance();
  final server = FakeServer();
  final api = ApiClient(baseUrl: 'http://api.test', client: MockClient(server.handle));
  final auth = AuthController(prefs, api);
  final settings = AppSettings(prefs, api);
  final passport = PassportController(prefs);
  final yatras = YatraController(prefs);
  final memories = MemoriesController(prefs);
  final submissions = SubmissionsController(prefs);
  final sync = SyncService(prefs: prefs, api: api, auth: auth, settings: settings, passport: passport, yatras: yatras, memories: memories, submissions: submissions);
  return (sync: sync, server: server, passport: passport, yatras: yatras, memories: memories, submissions: submissions, auth: auth, settings: settings);
}

void main() {
  test('a check-in is posted with method, time and coordinates, and gets its server id', () async {
    final t = await build();
    final v = await t.passport.checkIn(SampleData.temples.first, verification: Verification.gps, latitude: 13.68, longitude: 79.34, note: 'Govinda');
    await t.sync.flush();
    final req = t.server.requests.single;
    expect(req.url.path, '/api/v1/temples/${v.templeSlug}/visits');
    expect(req.url.queryParameters['lang'], 'en');
    expect(req.headers['Accept-Language'], 'en');
    expect(req.headers['Authorization'], 'Bearer t');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['method'], 'gps');
    expect(body['latitude'], 13.68);
    expect(body['note'], 'Govinda');
    expect(t.passport.byKey(v.localKey)!.remoteId, isNotNull);
    expect(t.passport.byKey(v.localKey)!.remoteVerified, isTrue);
    expect(t.sync.pendingCount, 0);
  });

  test('offline at the gate: the visit waits in the outbox and goes out later', () async {
    final t = await build();
    t.server.online = false;
    final v = await t.passport.checkIn(SampleData.temples[1]);
    await t.sync.flush();
    expect(t.sync.pendingCount, 1);
    expect(t.passport.byKey(v.localKey)!.remoteId, isNull);
    t.server.online = true;
    await t.sync.flush();
    expect(t.sync.pendingCount, 0);
    expect(t.passport.byKey(v.localKey)!.remoteId, isNotNull);
    expect(t.passport.byKey(v.localKey)!.remoteVerified, isFalse, reason: 'a manual check-in is never a stamp on the server');
  });

  test('a guest\'s visits are sent when they sign in', () async {
    final t = await build(signedIn: false);
    await t.passport.checkIn(SampleData.temples[2]);
    await t.sync.flush();
    expect(t.server.requests, isEmpty, reason: 'nothing to send as a guest');
    expect(t.sync.pendingCount, 1);
    await t.auth.login(identifier: 'anu@example.com', password: 'password1');
    await t.sync.flush();
    await t.sync.flush();
    expect(t.server.requests.where((r) => r.url.path.endsWith('/visits') && r.method == 'POST'), hasLength(1));
    expect(t.sync.pendingCount, 0);
  });

  test('a trip is created, its stops pushed by day, and a deleted trip removed', () async {
    final t = await build();
    final y = await t.yatras.create('South');
    await t.yatras.addStop(y, 0, const YatraStop(slug: 'meenakshi-amman-temple', name: 'Meenakshi'));
    await t.yatras.addDay(y);
    await t.yatras.addStop(y, 1, const YatraStop(slug: 'ramanathaswamy-temple-rameswaram', name: 'Rameswaram'));
    await t.sync.flush();
    expect(y.remoteId, isNotNull);
    final puts = t.server.requests.where((r) => r.method == 'PUT').toList();
    expect(puts.last.url.path, '/api/v1/me/yatras/${y.remoteId}/temples/ramanathaswamy-temple-rameswaram');
    expect(jsonDecode(puts.last.body)['day_number'], 2);
    await t.yatras.delete(y);
    await t.sync.flush();
    expect(t.server.requests.last.method, 'DELETE');
  });

  test('pull merges the account into the device without doubling', () async {
    final t = await build();
    await t.sync.pull();
    expect(t.passport.summary!.stamps, 3);
    expect(t.passport.summary!.circuits.single.total, 12);
    expect(t.passport.visits.where((v) => v.remoteId == 900), hasLength(1));
    expect(t.passport.visits.first.verification, Verification.qr);
    expect(t.yatras.yatras.single.remoteId, 700);
    expect(t.yatras.yatras.single.days, hasLength(2));
    expect(t.yatras.yatras.single.days[1].stops.single.done, isTrue, reason: 'the server recorded that visit');
    expect(t.memories.all.single.remoteId, 500);
    expect(t.settings.contentAvailable('kn'), isFalse);
    expect(t.settings.contentAvailable('en'), isTrue);
    await t.sync.pull();
    expect(t.passport.visits.where((v) => v.remoteId == 900), hasLength(1), reason: 'a second pull adds nothing');
    expect(t.yatras.yatras, hasLength(1));
  });

  test('a report needs no account and comes back with a reference and, later, a resolution', () async {
    final t = await build(signedIn: false);
    final s = await t.submissions.add(kind: 'correction', templeSlug: 'somnath-temple', templeId: 9, templeName: 'Somnath Temple', field: 'Timings', text: 'Closes at 21:30 now.', reporterName: 'Ravi');
    await t.sync.flush();
    final req = t.server.requests.single;
    expect(req.url.path, '/api/v1/support');
    final body = jsonDecode(req.body) as Map<String, dynamic>;
    expect(body['kind'], 'report');
    expect(body['about_type'], 'temple');
    expect(body['about_id'], 9);
    expect(body['category'], 'wrong_information');
    expect(body['name'], 'Ravi');
    expect(t.submissions.all.single.reference, 'TP-ABC123');
    // Signed in later: the ticket's status and resolution arrive on pull.
    t.auth.api.token = 't';
    await t.submissions.mergeTickets([SupportTicket.fromJson(jsonDecode(jsonEncode({'reference': 'TP-ABC123', 'subject': s.subject, 'body': s.text, 'status': {'value': 'resolved', 'label': 'Resolved', 'is_open': false}, 'resolution': 'Fixed the timings.'})) as Map<String, dynamic>)]);
    expect(t.submissions.all.single.resolution, 'Fixed the timings.');
  });

  test('a server rejection drops the op but keeps the device record', () async {
    final t = await build();
    final m = await t.memories.add(body: 'x' * 5, happenedOn: DateTime(2026, 1, 1));
    // Make the server reject memories.
    final rejecting = FakeServer();
    final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => http.Response(jsonEncode({'message': 'The body field is required.', 'errors': {'body': ['required']}}), 422)));
    SharedPreferences.setMockInitialValues({'devotee_token': 't', 'devotee': jsonEncode({'id': 1, 'name': 'Anu'})});
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthController(prefs, api);
    final sync2 = SyncService(prefs: prefs, api: api, auth: auth, settings: AppSettings(prefs, api), passport: PassportController(prefs), yatras: YatraController(prefs), memories: t.memories, submissions: SubmissionsController(prefs));
    await sync2.enqueue('memory_create', {'local_id': m.localId});
    await sync2.flush();
    expect(sync2.pendingCount, 0);
    expect(sync2.lastError, contains('memory_create'));
    expect(t.memories.byLocalId(m.localId), isNotNull, reason: 'the device copy survives');
    expect(rejecting.requests, isEmpty);
  });

  test('temple detail parses the mantra and its own media first', () {
    final d = TempleDetail.fromJson({
      'slug': 'x', 'name': 'X', 'location': {}, 'trust': {},
      'mantra': {'text': 'कौसल्या सुप्रजा राम', 'transliteration': 'Kausalya Supraja Rama', 'is_temple_specific': true},
      'devotional_media': [{'type': 'song', 'title': 'Suprabhatam', 'license': 'CC BY'}],
      'language': 'te',
    });
    expect(d.mantra!.isOwn, isTrue);
    expect(d.devotionalMedia.single.title, 'Suprabhatam');
    expect(d.language, 'te');
    final day = DevotionalDay.fromJson({'weekday': 1, 'title': 't', 'deity': {'slug': 'shiva', 'name': 'Shiva', 'image_url': 'https://x/shiva.jpg', 'mantra_meaning': 'I bow to Shiva.'}});
    expect(day.deity!.imageUrl, 'https://x/shiva.jpg');
    expect(day.deity!.mantraMeaning, 'I bow to Shiva.');
  });
}
