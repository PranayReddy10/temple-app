import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
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
