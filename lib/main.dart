import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/api/temple_repository.dart';
import 'core/ads/ads.dart';
import 'core/brand.dart';
import 'core/platform.dart';
import 'core/services/push_service.dart';
import 'core/state/app_config_controller.dart';
import 'core/state/app_settings.dart';
import 'core/state/auth_controller.dart';
import 'core/state/bookings_controller.dart';
import 'core/state/day_controller.dart';
import 'core/state/family_controller.dart';
import 'core/state/favourites_controller.dart';
import 'core/state/mantra_player.dart';
import 'core/state/location_controller.dart';
import 'core/state/memories_controller.dart';
import 'core/state/notifications_controller.dart';
import 'core/state/offline_pack_controller.dart';
import 'core/state/passport_controller.dart';
import 'core/state/photo_store.dart';
import 'core/state/reminders_controller.dart';
import 'core/state/submissions_controller.dart';
import 'core/state/subscription_controller.dart';
import 'core/state/sync_service.dart';
import 'core/state/yatra_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  try {
    AppPlatform.version = (await PackageInfo.fromPlatform()).version;
  } catch (_) {}
  final api = ApiClient(baseUrl: Brand.defaultApiBase)
    ..platform = AppPlatform.name
    ..appVersion = AppPlatform.version;
  final settings = AppSettings(prefs, api);
  final auth = AuthController(prefs, api);
  final repo = TempleRepository(api);
  final passport = PassportController(prefs);
  final yatras = YatraController(prefs);
  final memories = MemoriesController(prefs);
  final submissions = SubmissionsController(prefs);
  final favourites = FavouritesController(prefs, auth);
  final family = FamilyController(prefs);
  final bookings = BookingsController(prefs);
  final reminders = RemindersController(prefs);
  final location = LocationController(prefs)..refreshIfAllowed();
  final sync = SyncService(prefs: prefs, api: api, auth: auth, settings: settings, passport: passport, yatras: yatras, memories: memories, submissions: submissions);
  // Signing out leaves nothing of the account on the device. The outbox
  // goes first, so nothing of the old account is sent while the rest clears.
  for (final clear in [sync.clearAll, passport.clearAll, memories.clearAll, yatras.clearAll, favourites.clearAll, family.clearAll, bookings.clearAll, submissions.clearAll, reminders.clearAll, PhotoStore.wipe]) {
    auth.onSignOut(clear);
  }
  final appConfig = AppConfigController(prefs, api);
  final inbox = NotificationsController(prefs, api, auth);
  final push = PushService(prefs: prefs, api: api, auth: auth, config: appConfig, inbox: inbox);
  final ads = AdsController(appConfig, auth);
  final subscriptions = SubscriptionController(api, auth);
  // Anything recorded offline goes out now; the account comes in.
  sync.sync();
  // Maintenance, updates, ads and push: from the admin panel, in the
  // background — the last answer is already loaded, so nothing waits.
  appConfig.load().then((_) => push.start());
  inbox.load();
  // A new sign-in (or sign-out) re-registers the device under the account,
  // and a plan bought or ended changes whether ads show.
  var signedIn = auth.isSignedIn;
  auth.addListener(() {
    if (auth.isSignedIn == signedIn) return;
    signedIn = auth.isSignedIn;
    appConfig.load().then((_) => push.start());
  });

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<TempleRepository>.value(value: repo),
        ChangeNotifierProvider<AppSettings>.value(value: settings),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider(create: (_) => DayController(repo)),
        ChangeNotifierProvider<PassportController>.value(value: passport),
        ChangeNotifierProvider<FavouritesController>.value(value: favourites),
        ChangeNotifierProvider<YatraController>.value(value: yatras),
        ChangeNotifierProvider<MemoriesController>.value(value: memories),
        ChangeNotifierProvider<SyncService>.value(value: sync),
        ChangeNotifierProvider<FamilyController>.value(value: family),
        ChangeNotifierProvider(create: (_) => MantraPlayer(prefs)),
        ChangeNotifierProvider<RemindersController>.value(value: reminders),
        ChangeNotifierProvider<LocationController>.value(value: location),
        ChangeNotifierProvider(create: (_) => OfflinePackController(prefs, repo)),
        ChangeNotifierProvider<BookingsController>.value(value: bookings),
        ChangeNotifierProvider<SubmissionsController>.value(value: submissions),
        ChangeNotifierProvider<AppConfigController>.value(value: appConfig),
        ChangeNotifierProvider<NotificationsController>.value(value: inbox),
        ChangeNotifierProvider<SubscriptionController>.value(value: subscriptions),
        ChangeNotifierProvider<AdsController>.value(value: ads),
        Provider<PushService>.value(value: push),
      ],
      child: const TempleApp(),
    ),
  );
}
