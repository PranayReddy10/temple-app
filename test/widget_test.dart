import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/ads/ads.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/audio/audio_queue.dart';
import 'package:temple_app/core/services/push_service.dart';
import 'package:temple_app/core/state/app_config_controller.dart';
import 'package:temple_app/core/state/notifications_controller.dart';
import 'package:temple_app/core/state/subscription_controller.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/motifs/architecture.dart';
import 'package:temple_app/core/state/app_settings.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/bookings_controller.dart';
import 'package:temple_app/core/state/day_controller.dart';
import 'package:temple_app/core/state/engagement_controller.dart';
import 'package:temple_app/core/state/family_controller.dart';
import 'package:temple_app/core/state/favourites_controller.dart';
import 'package:temple_app/core/state/mantra_player.dart';
import 'package:temple_app/core/state/memories_controller.dart';
import 'package:temple_app/core/state/offline_pack_controller.dart';
import 'package:temple_app/core/state/passport_controller.dart';
import 'package:temple_app/core/state/reminders_controller.dart';
import 'package:temple_app/core/state/submissions_controller.dart';
import 'package:temple_app/core/state/sync_service.dart';
import 'package:temple_app/core/state/yatra_controller.dart';
import 'package:temple_app/core/theme/app_theme.dart';
import 'package:temple_app/core/theme/day_theme.dart';
import 'package:temple_app/core/widgets/temple_door.dart';
import 'package:temple_app/core/data/sample_data.dart';
import 'package:temple_app/features/shell/shell_screen.dart';
import 'package:temple_app/features/days/day_screen.dart';
import 'package:temple_app/features/temple/temple_screen.dart';
import 'package:temple_app/features/passport/visit_detail_screen.dart';
import 'package:temple_app/features/passport/passport_view_screen.dart';
import 'package:temple_app/features/qr/qr_screens.dart';

Future<Widget> harness(Widget child, {Map<String, Object> prefs = const {}, Locale? locale}) async {
  SharedPreferences.setMockInitialValues({'door_animations': false, ...prefs});
  final store = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: 'http://localhost:1', timeout: const Duration(milliseconds: 50));
  final auth = AuthController(store, api);
  final repo = TempleRepository(api);
  final settings = AppSettings(store, api);
  final passport = PassportController(store);
  final yatras = YatraController(store);
  final memories = MemoriesController(store);
  final submissions = SubmissionsController(store);
  final sync = SyncService(prefs: store, api: api, auth: auth, settings: settings, passport: passport, yatras: yatras, memories: memories, submissions: submissions);
  final appConfig = AppConfigController(store, api);
  final inbox = NotificationsController(store, api, auth);
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      Provider<TempleRepository>.value(value: repo),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => DayController(repo)),
      ChangeNotifierProvider.value(value: passport),
      ChangeNotifierProvider(create: (_) => FavouritesController(store, auth)),
      ChangeNotifierProvider.value(value: yatras),
      ChangeNotifierProvider.value(value: memories),
      ChangeNotifierProvider.value(value: sync),
      ChangeNotifierProvider(create: (_) => FamilyController(store)),
      ChangeNotifierProvider(create: (_) => MantraPlayer(store)),
      ChangeNotifierProvider(create: (_) => EngagementController(store, auth, api: api)),
      ChangeNotifierProvider(create: (_) => AudioQueueController()),
      ChangeNotifierProvider(create: (_) => RemindersController(store)),
      ChangeNotifierProvider(create: (_) => OfflinePackController(store, repo)),
      ChangeNotifierProvider(create: (_) => BookingsController(store)),
      ChangeNotifierProvider.value(value: submissions),
      ChangeNotifierProvider.value(value: appConfig),
      ChangeNotifierProvider.value(value: inbox),
      ChangeNotifierProvider(create: (_) => SubscriptionController(api, auth)),
      ChangeNotifierProvider(create: (_) => AdsController(appConfig, auth)),
      Provider(create: (_) => PushService(prefs: store, api: api, auth: auth, config: appConfig, inbox: inbox)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(DayTheme.today()),
      locale: locale,
      supportedLocales: AppSettings.supportedLocales,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: child,
    ),
  );
}

void main() {
  _passportScreenTests();
  _themeTests();
  _overflowTests();
  _pageOverflowTests();
  testWidgets('shell shows five tabs and the day header', (tester) async {
    await tester.pumpWidget(await harness(const ShellScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('Passport'), findsOneWidget);
    expect(find.text('Yatra'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text(DayTheme.today().deityName), findsWidgets);
  });

  testWidgets('temple door reveal paints two leaves while shut', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: TempleDoorReveal(progress: 0, child: SizedBox.expand())));
    Finder leaves() => find.byWidgetPredicate((w) => w is CustomPaint && w.painter is DoorLeafPainter);
    expect(leaves(), findsNWidgets(2));
    await tester.pumpWidget(const MaterialApp(home: TempleDoorReveal(progress: 1, child: SizedBox.expand())));
    expect(leaves(), findsNothing);
  });

  testWidgets('passport book opens from its cover to an empty first visa page', (tester) async {
    await tester.pumpWidget(await harness(const ShellScreen(initialIndex: 2)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('TEMPLE PASSPORT'), findsWidgets);
    expect(find.text('Swipe to open'), findsOneWidget);
    // Cover, then the data page, then the first visa page.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('first stamp'), findsOneWidget);

    // One more turn reaches the back cover.
    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(find.text('Back cover'), findsWidgets);

    // Every page at once, and a tap turns the book to it.
    await tester.tap(find.byTooltip('All pages'));
    await tester.pumpAndSettle();
    expect(find.text('Cover'), findsOneWidget);
    expect(find.text('Data page'), findsOneWidget);
    await tester.tap(find.text('Data page'));
    await tester.pumpAndSettle();
    expect(find.text('Page 1 / 2'), findsOneWidget);
  });
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => enterTemple(context, TempleScreen(slug: 'vaishno-devi-temple-katra', preview: SampleData.bySlug('vaishno-devi-temple-katra'))),
            child: const Text('open'),
          ),
        ),
      );
}

void _themeTests() {
  testWidgets('leaving a temple page restores today\'s theme', (tester) async {
    await tester.pumpWidget(await harness(const _Launcher()));
    await tester.pump(const Duration(milliseconds: 100));
    final element = tester.element(find.text('open'));
    final ctl = element.read<DayController>();
    final today = ctl.todayTheme.deitySlug;

    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(ctl.theme.deitySlug, 'devi');
    expect(ctl.previewDepth, 1);

    // Pop it.
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    expect(ctl.previewDepth, 0);
    expect(ctl.theme.deitySlug, today);
  });
}

void _overflowTests() {
  for (final scale in [1.0, 1.3, 1.6]) {
    testWidgets('no layout overflow on the main tabs at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final errors = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d);
      await tester.pumpWidget(MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale), size: const Size(360, 740)), child: await harness(const ShellScreen())));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      for (final i in [1, 2, 3, 4]) {
        await tester.tap(find.byType(NavigationDestination).at(i));
        await tester.pump(const Duration(milliseconds: 400));
      }
      FlutterError.onError = old;
      final overflows = errors.where((e) => e.toString().contains('overflowed')).map((e) {
        final lines = e.toString().split('\n');
        final i = lines.indexWhere((l) => l.contains('error-causing widget'));
        final creator = lines.where((l) => l.contains('creator:')).map((l) => l.trim()).firstOrNull ?? '';
        final widget = i >= 0 ? '${lines.skip(i + 1).take(2).map((l) => l.trim()).join(' ')} $creator' : creator;
        return '${e.exception.toString().split('\n').first} @ $widget';
      }).toList();
      expect(overflows, isEmpty, reason: overflows.join('\n'));
    });
  }
}

void _pageOverflowTests() {
  for (final scale in [1.0, 1.4]) {
    testWidgets('no layout overflow on temple and day pages at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(360 * 3, 740 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final errors = <FlutterErrorDetails>[];
      final old = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d);
      for (final page in [TempleScreen(slug: 'meenakshi-amman-temple', preview: SampleData.bySlug('meenakshi-amman-temple')), const DayScreen(weekday: 1)]) {
        await tester.pumpWidget(MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale), size: const Size(360, 740)), child: await harness(page)));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
        await tester.pump(const Duration(milliseconds: 300));
      }
      FlutterError.onError = old;
      final overflows = errors.where((e) => e.toString().contains('overflowed')).map((e) {
        final lines = e.toString().split('\n');
        final i = lines.indexWhere((l) => l.contains('error-causing widget'));
        return '${lines.first} @ ${i >= 0 ? lines.skip(i + 1).take(2).map((l) => l.trim()).join(' ') : ''}';
      }).toList();
      expect(overflows, isEmpty, reason: overflows.join('\n'));
    });
  }
}

void _passportScreenTests() {
  for (final scale in [1.0, 1.6]) {
    testWidgets('visit detail with memory photos fits at text scale $scale', (tester) async {
      final t = SampleData.temples.first;
      final visit = Visit(templeSlug: t.slug, templeName: t.name, deitySlug: t.deity?.slug, visitedAt: DateTime(2026, 9, 1), city: t.location.city, note: 'With amma.', localKey: 'k1', memoryPhotos: const [MemoryPhoto(path: '/nowhere/m1.jpg'), MemoryPhoto(url: 'http://localhost:1/m2.jpg')]);
      tester.view.physicalSize = const Size(360 * 3, 780 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(await harness(const VisitDetailScreen(visitKey: 'k1'), prefs: {'visits': jsonEncode([visit.toJson()])}));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('In your passport'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Memories · 2/3'), 200);
      await tester.scrollUntilVisible(find.text('Add memory'), 200);
      expect(find.text('Add memory'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('my QR asks a guest to sign in, and a passport that cannot load says so', (tester) async {
    await tester.pumpWidget(await harness(const MyQrScreen()));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sign in to get your own passport QR.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(await harness(const PassportViewScreen(code: 'Ab3dEf6hIj9kLm2nOp4q')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
