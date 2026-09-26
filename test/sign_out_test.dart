import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/state/engagement_controller.dart';
import 'package:temple_app/core/state/notifications_controller.dart';
import 'package:temple_app/core/state/offline_pack_controller.dart';
import 'package:temple_app/core/data/sample_data.dart';
import 'package:temple_app/core/state/app_settings.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/favourites_controller.dart';
import 'package:temple_app/core/state/location_controller.dart';
import 'package:temple_app/core/state/memories_controller.dart';
import 'package:temple_app/core/state/passport_controller.dart';
import 'package:temple_app/core/state/submissions_controller.dart';
import 'package:temple_app/core/state/sync_service.dart';
import 'package:temple_app/core/state/yatra_controller.dart';

void main() {
  test('signing out leaves nothing of the account on the device', () async {
    SharedPreferences.setMockInitialValues({'favourites': ['legacy-slug']});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(baseUrl: 'http://localhost', client: MockClient((_) async => http.Response('{}', 200)));
    final auth = AuthController(prefs, api);
    final passport = PassportController(prefs);
    final memories = MemoriesController(prefs);
    final yatras = YatraController(prefs);
    final submissions = SubmissionsController(prefs);
    final favourites = FavouritesController(prefs, auth);
    final sync = SyncService(prefs: prefs, api: api, auth: auth, settings: AppSettings(prefs, api), passport: passport, yatras: yatras, memories: memories, submissions: submissions);
    for (final clear in [sync.clearAll, passport.clearAll, memories.clearAll, yatras.clearAll, favourites.clearAll, submissions.clearAll]) {
      auth.onSignOut(clear);
    }

    // The last person's visit, with a photo, and a saved temple.
    final v = await passport.checkIn(SampleData.temples.first);
    await passport.addMemoryPhoto(v, '/old-user-photo.jpg');
    await sync.enqueue('visit_create', {'key': v.localKey});
    expect(passport.visits, isNotEmpty);
    expect(favourites.items, isNotEmpty);

    await auth.logout();

    expect(passport.visits, isEmpty);
    expect(passport.summary, isNull);
    expect(favourites.items, isEmpty);
    expect(sync.pendingCount, 0, reason: 'nothing of the old account may be sent under the next one');

    // And it stays gone after a restart.
    expect(PassportController(prefs).visits, isEmpty);
    expect(FavouritesController(prefs, auth).items, isEmpty);
    expect(prefs.getString('outbox'), isNull);
  });

  test('the next account does not get the last one\'s photo, reviews, packs, pushes or read marks', () async {
    SharedPreferences.setMockInitialValues({
      'avatar_path': '/old-user/avatar.jpg',
      'notices_read': ['1', '2'],
      'offline_packs': '{"trip-1":["srisailam"]}',
      'offline_temples': '{"srisailam":{"slug":"srisailam","name":"Srisailam"}}',
      'followed_temples': '[{"temple":{"slug":"srisailam","name":"Srisailam"},"temple_id":7,"notify_festivals":true,"notify_events":true}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(baseUrl: 'http://localhost', client: MockClient((_) async => http.Response('{}', 200)));
    final auth = AuthController(prefs, api);
    final repo = TempleRepository(api);
    final packs = OfflinePackController(prefs, repo);
    final inbox = NotificationsController(prefs, api, auth);
    final engagement = EngagementController(prefs, auth, api: api);
    final unfollowed = <int?>[];
    engagement.onFollowChanged = (id, follow) {
      if (!follow) unfollowed.add(id);
    };
    for (final clear in [engagement.clearAll, packs.clearAll, inbox.clearAll]) {
      auth.onSignOut(clear);
    }
    expect(auth.localAvatarPath, isNotNull);
    expect(repo.packed, isNotEmpty);
    expect(inbox.isRead(const AppNotice(id: 1, title: '', body: '')), isTrue);

    await auth.logout();

    expect(auth.localAvatarPath, isNull, reason: 'the old profile photo showed as the new account\'s');
    expect(repo.packed, isEmpty);
    expect(prefs.getString('offline_temples'), isNull);
    expect(inbox.isRead(const AppNotice(id: 1, title: '', body: '')), isFalse);
    expect(unfollowed, [7], reason: 'the phone must stop receiving the old account\'s temple pushes');
  });

  group('distance', () {
    test('reads the way people say it', () {
      expect(LocationController.formatKm(0.05), 'You are here');
      expect(LocationController.formatKm(0.65), '650 m away');
      expect(LocationController.formatKm(4.26), '4.3 km away');
      expect(LocationController.formatKm(1240.4), '1,240 km away');
    });

    test('is known once a position is shared, and remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final loc = LocationController(prefs);
      expect(loc.labelTo(17.385, 78.486), isNull);

      await loc.set(17.385, 78.486); // Hyderabad
      final km = loc.kmTo(17.6868, 83.2185)!; // Visakhapatnam
      expect(km, inInclusiveRange(500, 540));
      expect(LocationController(prefs).known, isTrue);
    });
  });
}
