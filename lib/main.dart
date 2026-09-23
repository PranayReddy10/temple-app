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
import 'core/state/offline_pack_controller.dart';
import 'core/state/passport_controller.dart';
import 'core/state/reminders_controller.dart';
import 'core/state/submissions_controller.dart';
import 'core/state/yatra_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: Brand.defaultApiBase);
  final settings = AppSettings(prefs, api);
  final auth = AuthController(prefs, api);
  final repo = TempleRepository(api);

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<TempleRepository>.value(value: repo),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider(create: (_) => DayController(repo)),
        ChangeNotifierProvider(create: (_) => PassportController(prefs)),
        ChangeNotifierProvider(create: (_) => FavouritesController(prefs, auth)),
        ChangeNotifierProvider(create: (_) => YatraController(prefs)),
        ChangeNotifierProvider(create: (_) => FamilyController(prefs)),
        ChangeNotifierProvider(create: (_) => RemindersController(prefs)),
        ChangeNotifierProvider(create: (_) => OfflinePackController(prefs, repo)),
        ChangeNotifierProvider(create: (_) => BookingsController(prefs)),
        ChangeNotifierProvider(create: (_) => SubmissionsController(prefs)),
      ],
      child: const TempleApp(),
    ),
  );
}
