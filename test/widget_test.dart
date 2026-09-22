import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/motifs/architecture.dart';
import 'package:temple_app/core/state/app_settings.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/day_controller.dart';
import 'package:temple_app/core/state/favourites_controller.dart';
import 'package:temple_app/core/state/passport_controller.dart';
import 'package:temple_app/core/state/yatra_controller.dart';
import 'package:temple_app/core/theme/app_theme.dart';
import 'package:temple_app/core/theme/day_theme.dart';
import 'package:temple_app/core/widgets/temple_door.dart';
import 'package:temple_app/core/data/sample_data.dart';
import 'package:temple_app/features/shell/shell_screen.dart';
import 'package:temple_app/features/temple/temple_screen.dart';

Future<Widget> harness(Widget child) async {
  SharedPreferences.setMockInitialValues({'door_animations': false});
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: 'http://localhost:1', timeout: const Duration(milliseconds: 50));
  final auth = AuthController(prefs, api);
  final repo = TempleRepository(api);
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      Provider<TempleRepository>.value(value: repo),
      ChangeNotifierProvider(create: (_) => AppSettings(prefs, api)),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => DayController(repo)),
      ChangeNotifierProvider(create: (_) => PassportController(prefs)),
      ChangeNotifierProvider(create: (_) => FavouritesController(prefs, auth)),
      ChangeNotifierProvider(create: (_) => YatraController(prefs)),
    ],
    child: MaterialApp(theme: AppTheme.light(DayTheme.today()), home: child),
  );
}

void main() {
  _themeTests();
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

  testWidgets('passport tab shows empty state until a check-in', (tester) async {
    await tester.pumpWidget(await harness(const ShellScreen(initialIndex: 2)));
    await tester.pump(const Duration(milliseconds: 300));
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
