import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/temple_repository.dart';
import 'core/brand.dart';
import 'core/state/app_settings.dart';
import 'core/state/auth_controller.dart';
import 'core/state/bookings_controller.dart';
import 'core/state/day_controller.dart';
import 'core/state/family_controller.dart';
import 'core/state/favourites_controller.dart';
import 'core/state/mantra_player.dart';
import 'core/state/memories_controller.dart';
import 'core/state/offline_pack_controller.dart';
import 'core/state/passport_controller.dart';
import 'core/state/reminders_controller.dart';
import 'core/state/submissions_controller.dart';
import 'core/state/sync_service.dart';
import 'core/state/yatra_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: Brand.defaultApiBase);
  final settings = AppSettings(prefs, api);
  final auth = AuthController(prefs, api);
  final repo = TempleRepository(api);
  final passport = PassportController(prefs);
  final yatras = YatraController(prefs);
  final memories = MemoriesController(prefs);
  final submissions = SubmissionsController(prefs);
  final sync = SyncService(prefs: prefs, api: api, auth: auth, settings: settings, passport: passport, yatras: yatras, memories: memories, submissions: submissions);
  // Anything recorded offline goes out now; the account comes in.
  sync.sync();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<TempleRepository>.value(value: repo),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider(create: (_) => DayController(repo)),
        ChangeNotifierProvider<PassportController>.value(value: passport),
        ChangeNotifierProvider(create: (_) => FavouritesController(prefs, auth)),
        ChangeNotifierProvider<YatraController>.value(value: yatras),
        ChangeNotifierProvider<MemoriesController>.value(value: memories),
        ChangeNotifierProvider<SyncService>.value(value: sync),
        ChangeNotifierProvider(create: (_) => FamilyController(prefs)),
        ChangeNotifierProvider(create: (_) => MantraPlayer(prefs)),
        ChangeNotifierProvider(create: (_) => RemindersController(prefs)),
        ChangeNotifierProvider(create: (_) => OfflinePackController(prefs, repo)),
        ChangeNotifierProvider(create: (_) => BookingsController(prefs)),
        ChangeNotifierProvider<SubmissionsController>.value(value: submissions),
      ],
      child: const TempleApp(),
    ),
  );
}
