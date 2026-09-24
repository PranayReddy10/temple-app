import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/ads/ads.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/data/sample_data.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/platform.dart';
import 'package:temple_app/core/state/app_config_controller.dart';
import 'package:temple_app/core/state/app_settings.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/favourites_controller.dart';
import 'package:temple_app/core/state/notifications_controller.dart';
import 'package:temple_app/core/state/passport_controller.dart';
import 'package:temple_app/core/state/subscription_controller.dart';
import 'package:temple_app/features/app_gate/app_gate.dart';
import 'package:temple_app/features/auth/auth_screen.dart';
import 'package:temple_app/features/media/in_app_browser.dart';
import 'package:temple_app/features/notifications/notifications_screen.dart';
import 'package:temple_app/features/premium/premium_screen.dart';

Map<String, dynamic> config({bool maintenance = false, bool available = false, bool required = false, bool google = false, bool apple = false, bool password = true, bool ads = false, bool payments = false, bool elsewhere = false}) => {
      'maintenance': {'enabled': maintenance, 'title': 'Back soon', 'message': 'Lamps are being lit.'},
      'update': {'available': available || required, 'required': required, 'latest_version': '0.9.0', 'store_url': 'https://play.google.com/store/apps/details?id=x', 'title': 'New version'},
      'auth': {'password': password, 'google': {'enabled': google, 'server_client_id': 'web.apps.googleusercontent.com'}, 'apple': {'enabled': apple}},
      'push': {'enabled': false},
      'ads': {'enabled': ads, 'network': 'admob', 'units': {'native': 'ca-app-pub-3940256099942544/2247696110'}, 'list_interval': 5, 'placements': {'temple_detail': true, 'explore': false}},
      'payments': {'enabled': payments, 'available_elsewhere': elsewhere, 'gateways': payments ? [{'code': 'razorpay', 'name': 'Razorpay'}] : [], 'default_gateway': payments ? 'razorpay' : null},
    };

class Server {
  Server(this.appConfig);

  Map<String, dynamic> appConfig;
  final List<http.Request> requests = [];

  Future<http.Response> handle(http.Request r) async {
    requests.add(r);
    final path = r.url.path.replaceFirst('/api/v1/', '');
    http.Response json(Object o, [int s = 200]) => http.Response(jsonEncode(o), s, headers: {'content-type': 'application/json; charset=utf-8'});
    return switch (path) {
      'app/config' => json({'data': appConfig}),
      'notifications' => json({'data': [
          {'id': 1, 'title': 'Karthika Deepam', 'body': 'Lamps tonight', 'link': {'type': 'none'}, 'sent_at': DateTime.now().toIso8601String(), 'is_read': null},
          {'id': 2, 'title': 'New temple', 'body': 'Srisailam added', 'link': {'type': 'temple', 'value': 'srisailam'}, 'sent_at': DateTime.now().toIso8601String(), 'is_read': null},
        ]}),
      'plans' => json({'data': [
          {'code': 'yatri-plus', 'name': 'Yatri Plus', 'price': '₹49', 'period': 'per month', 'badge': 'Most popular', 'benefits': {'no_ads': true, 'memory_photos_per_visit': 10}},
        ]}),
      _ => json({'message': 'not found'}, 404),
    };
  }
}

Future<({Widget app, Server server, AppConfigController cfg, AuthController auth})> harness(Widget home, Map<String, dynamic> cfgJson, {Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues({...prefs});
  final store = await SharedPreferences.getInstance();
  final server = Server(cfgJson);
  final api = ApiClient(baseUrl: 'http://api.test', client: MockClient(server.handle));
  final auth = AuthController(store, api);
  final cfg = AppConfigController(store, api);
  await cfg.load();
  final app = MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: cfg),
      ChangeNotifierProvider(create: (_) => AppSettings(store, api)),
      ChangeNotifierProvider(create: (_) => FavouritesController(store, auth)),
      ChangeNotifierProvider(create: (_) => NotificationsController(store, api, auth)),
      ChangeNotifierProvider(create: (_) => SubscriptionController(api, auth)),
      ChangeNotifierProvider(create: (_) => AdsController(cfg, auth)),
    ],
    child: MaterialApp(navigatorKey: rootNavigatorKey, builder: (context, child) => AppGate(child: child!), home: home),
  );
  return (app: app, server: server, cfg: cfg, auth: auth);
}

void main() {
  setUp(() => AppPlatform.debugOverride = 'android');
  tearDown(() => AppPlatform.debugOverride = null);

  test('the config is read, and asks for this platform and version', () async {
    final h = await harness(const SizedBox(), config(available: true));
    expect(h.cfg.config.updateAvailable, isTrue);
    expect(h.cfg.shouldOfferUpdate, isTrue);
    final q = h.server.requests.single.url.queryParameters;
    expect(q['platform'], 'android');
    expect(q['version'], AppPlatform.version);
    await h.cfg.dismissUpdate();
    expect(h.cfg.shouldOfferUpdate, isFalse, reason: 'offered once per version');
  });

  testWidgets('maintenance covers the app, and a required update blocks it', (tester) async {
    final h = await harness(const Text('HOME'), config(maintenance: true));
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(find.text('Back soon'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);

    h.server.appConfig = config(required: true);
    await tester.runAsync(h.cfg.load);
    await tester.pump();
    expect(find.text('New version'), findsOneWidget);
    expect(find.text('Update now'), findsOneWidget);
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('an optional update is offered in a popup that can be put off', (tester) async {
    final h = await harness(const Text('HOME'), config(available: true));
    await tester.pumpWidget(h.app);
    await tester.pump();
    await tester.pump();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('New version'), findsOneWidget);
    await tester.tap(find.text('Later'));
    await tester.pumpAndSettle();
    expect(find.text('New version'), findsNothing);
    expect(h.cfg.shouldOfferUpdate, isFalse);
  });

  testWidgets('sign-in offers Google when the admin panel enables it, and Apple only on iPhone', (tester) async {
    var h = await harness(const AuthScreen(), config(google: true, apple: true));
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign in with Apple'), findsNothing);
    expect(find.text('Email or phone'), findsOneWidget);

    AppPlatform.debugOverride = 'ios';
    h = await harness(const AuthScreen(), config(google: true, apple: true, password: false));
    await tester.pumpWidget(h.app);
    await tester.pump();
    expect(find.text('Sign in with Apple'), findsOneWidget);
    // Password sign-in off: the form waits behind a link.
    expect(find.text('Email or phone'), findsNothing);
    await tester.tap(find.text('Use email or phone instead'));
    await tester.pump();
    expect(find.text('Email or phone'), findsOneWidget);
  });

  testWidgets('premium lists plans; buying is offered only where payments are on', (tester) async {
    var h = await harness(const PremiumScreen(), config(payments: true));
    await tester.pumpWidget(h.app);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('Yatri Plus'), findsOneWidget);
    expect(find.text('No ads anywhere in the app'), findsOneWidget);
    expect(find.text('10 memory photos with every visit'), findsOneWidget);
    expect(find.textContaining('Choose'), findsOneWidget);

    AppPlatform.debugOverride = 'ios';
    h = await harness(const PremiumScreen(), config(elsewhere: true));
    await tester.pumpWidget(h.app);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.textContaining('Choose'), findsNothing);
    expect(find.textContaining('A plan already on your account works here too'), findsOneWidget);
  });

  testWidgets('the inbox lists notices and a guest\'s read state is kept on the device', (tester) async {
    final h = await harness(const NotificationsScreen(), config());
    await tester.pumpWidget(h.app);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(find.text('Karthika Deepam'), findsOneWidget);
    final inbox = tester.element(find.byType(NotificationsScreen)).read<NotificationsController>();
    expect(inbox.unreadCount, 2);
    await tester.tap(find.text('Mark all read'));
    await tester.pump();
    expect(inbox.unreadCount, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('notices_read'), containsAll(['1', '2']));
  });

  test('ads follow the placement settings and never show on a no-ads plan', () async {
    final h = await harness(const SizedBox(), config(ads: true));
    final ads = AdsController(h.cfg, h.auth);
    expect(ads.shows('temple_detail'), isTrue);
    expect(ads.shows('explore'), isFalse);
    expect(ads.listInterval, 5);

    SharedPreferences.setMockInitialValues({
      'devotee_token': 't',
      'devotee': jsonEncode({'id': 1, 'name': 'Anu', 'entitlements': {'no_ads': true, 'memory_photos_per_visit': 10}}),
    });
    final store = await SharedPreferences.getInstance();
    final premium = AuthController(store, ApiClient(baseUrl: 'http://api.test', client: MockClient((_) async => http.Response('{}', 404))));
    expect(AdsController(h.cfg, premium).shows('temple_detail'), isFalse);
    expect(premium.devotee!.entitlements.memoryPhotosPerVisit, 10);

    AppPlatform.debugOverride = 'web';
    expect(ads.shows('temple_detail'), isFalse);
  });

  test('a plan raises the memory photo limit on the device too', () async {
    SharedPreferences.setMockInitialValues({});
    final passport = PassportController(await SharedPreferences.getInstance());
    final v = await passport.checkIn(SampleData.temples.first);
    for (var i = 0; i < 3; i++) {
      await passport.addMemoryPhoto(v, '/m$i.jpg');
    }
    expect(await passport.addMemoryPhoto(v, '/m3.jpg'), isNull);
    expect(await passport.addMemoryPhoto(v, '/m3.jpg', limit: 10), isNotNull);
  });

  test('UPI intent links become the URL the UPI app understands', () {
    expect(InAppBrowserScreen.fromIntentUrl('intent://pay?pa=temple@upi&am=49#Intent;scheme=upi;package=com.phonepe.app;end').toString(), 'upi://pay?pa=temple@upi&am=49');
    expect(InAppBrowserScreen.fromIntentUrl('https://example.com'), isNull);
  });

  test('entitlements and sign-in methods round-trip through the stored profile', () {
    final d = Devotee.fromJson({'id': 3, 'name': 'Meera', 'sign_in_methods': ['google'], 'entitlements': {'no_ads': true, 'memory_photos_per_visit': 10, 'premium_passport': true}, 'subscription': {'plan': 'Yatri Plus', 'ends_at': '2026-12-01T00:00:00Z'}, 'home_state_id': 36});
    final again = Devotee.fromJson(d.toJson());
    expect(again.signInMethods, ['google']);
    expect(again.entitlements.premiumPassport, isTrue);
    expect(again.subscriptionPlan, 'Yatri Plus');
    expect(again.homeStateId, 36);
    expect(Devotee.fromJson({'name': 'Old'}).entitlements.memoryPhotosPerVisit, 3);
  });
}
