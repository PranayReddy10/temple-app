import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/motifs/architecture.dart';
import 'package:temple_app/core/state/app_settings.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/bookings_controller.dart';
import 'package:temple_app/core/state/day_controller.dart';
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

Future<Widget> harness(Widget child, {Locale? locale}) async {
  SharedPreferences.setMockInitialValues({'door_animations': false});
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: 'http://localhost:1', timeout: const Duration(milliseconds: 50));
  final auth = AuthController(prefs, api);
  final repo = TempleRepository(api);
  final settings = AppSettings(prefs, api);
  final passport = PassportController(prefs);
  final yatras = YatraController(prefs);
  final memories = MemoriesController(prefs);
  final submissions = SubmissionsController(prefs);
  final sync = SyncService(prefs: prefs, api: api, auth: auth, settings: settings, passport: passport, yatras: yatras, memories: memories, submissions: submissions);
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      Provider<TempleRepository>.value(value: repo),
      ChangeNotifierProvider.value(value: settings),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => DayController(repo)),
      ChangeNotifierProvider.value(value: passport),
      ChangeNotifierProvider(create: (_) => FavouritesController(prefs, auth)),
      ChangeNotifierProvider.value(value: yatras),
      ChangeNotifierProvider.value(value: memories),
      ChangeNotifierProvider.value(value: sync),
      ChangeNotifierProvider(create: (_) => FamilyController(prefs)),
      ChangeNotifierProvider(create: (_) => MantraPlayer(prefs)),
      ChangeNotifierProvider(create: (_) => RemindersController(prefs)),
      ChangeNotifierProvider(create: (_) => OfflinePackController(prefs, repo)),
      ChangeNotifierProvider(create: (_) => BookingsController(prefs)),
      ChangeNotifierProvider.value(value: submissions),
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
