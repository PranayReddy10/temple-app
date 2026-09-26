import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/platform.dart';
import 'package:temple_app/core/state/app_config_controller.dart';
import 'package:temple_app/core/state/app_settings.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/favourites_controller.dart';
import 'package:temple_app/features/auth/auth_screen.dart';
import 'package:temple_app/features/auth/auth_widgets.dart';

Map<String, dynamic> _config({bool reset = true, bool google = false}) => {
      'auth': {'password': true, 'password_reset': reset, 'google': {'enabled': google, 'server_client_id': 'web.apps.googleusercontent.com'}, 'apple': {'enabled': false}},
    };

const _devotee = {'id': 7, 'name': 'Asha', 'email': 'asha@example.com'};

class _Server {
  Map<String, dynamic> appConfig = _config();
  int loginStatus = 200;
  final List<(String, Map<String, dynamic>)> posts = [];

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst('/api/v1/', '');
    http.Response json(Object o, [int s = 200]) => http.Response(jsonEncode(o), s, headers: {'content-type': 'application/json; charset=utf-8'});
    if (r.method == 'POST') posts.add((path, r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, dynamic>));
    return switch (path) {
      'app/config' => json({'data': appConfig}),
      'auth/login' => loginStatus == 200 ? json({'data': {'devotee': _devotee, 'token': 't1'}}) : json({'message': 'Too Many Attempts.'}, loginStatus),
      'auth/register' => json({'data': {'devotee': _devotee, 'token': 't2'}}, 201),
      'auth/password/forgot' => json({'data': {'message': 'sent'}}),
      'auth/password/reset' => (jsonDecode(r.body) as Map)['code'] == '123456'
          ? json({'data': {'devotee': _devotee, 'token': 't3'}})
          : json({'message': 'bad', 'errors': {'code': ['That code is wrong or has expired. Ask for a new one.']}}, 422),
      _ => json({'data': []}),
    };
  }
}

Future<({Widget app, _Server server, AuthController auth, AppConfigController cfg})> _harness({bool register = false}) async {
  SharedPreferences.setMockInitialValues({});
  final store = await SharedPreferences.getInstance();
  final server = _Server();
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
    ],
    child: MaterialApp(
      home: Builder(builder: (context) => Scaffold(body: Center(child: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthScreen(register: register))), child: const Text('OPEN'))))),
    ),
  );
  return (app: app, server: server, auth: auth, cfg: cfg);
}

Future<void> _open(WidgetTester tester, Widget app) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.6;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  await tester.tap(find.text('OPEN'));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Key key) => tester.widget<EditableText>(find.descendant(of: find.byKey(key), matching: find.byType(EditableText))).controller.text;

void main() {
  setUp(() => AppPlatform.debugOverride = 'android');
  tearDown(() => AppPlatform.debugOverride = null);

  testWidgets('a password typed to sign in is not carried into create account', (tester) async {
    final h = await _harness();
    await _open(tester, h.app);

    await tester.enterText(find.byKey(const Key('auth-password')), 'old-secret-1');
    await tester.tap(find.text('Create account').first);
    await tester.pumpAndSettle();

    expect(_text(tester, const Key('auth-new-password')), isEmpty);
    expect(_text(tester, const Key('auth-confirm-password')), isEmpty);

    // Back again: still empty.
    await tester.tap(find.text('Sign in').first);
    await tester.pumpAndSettle();
    expect(_text(tester, const Key('auth-password')), isEmpty);
  });

  testWidgets('create account asks to confirm the password and signs in', (tester) async {
    final h = await _harness(register: true);
    await _open(tester, h.app);

    await tester.enterText(find.byKey(const Key('auth-name')), 'Asha');
    await tester.enterText(find.byKey(const Key('auth-email')), 'asha@example.com');
    await tester.enterText(find.byKey(const Key('auth-new-password')), 'a-good-pass-1');
    await tester.enterText(find.byKey(const Key('auth-confirm-password')), 'something-else');
    await tester.tap(find.widgetWithText(AuthSubmitButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(h.server.posts.where((p) => p.$1 == 'auth/register'), isEmpty);

    await tester.enterText(find.byKey(const Key('auth-confirm-password')), 'a-good-pass-1');
    await tester.tap(find.widgetWithText(AuthSubmitButton, 'Create account'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(h.auth.isSignedIn, isTrue);
    expect(find.text('OPEN'), findsOneWidget, reason: 'the screen closes once signed in');
  });

  testWidgets('too many attempts reads as "wait a minute", not a locked account', (tester) async {
    final h = await _harness();
    h.server.loginStatus = 429;
    await _open(tester, h.app);

    await tester.enterText(find.byKey(const Key('auth-identifier')), 'asha@example.com');
    await tester.enterText(find.byKey(const Key('auth-password')), 'whatever-1');
    await tester.tap(find.widgetWithText(AuthSubmitButton, 'Sign in'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.text('Too many tries. Please wait a minute and try again.'), findsOneWidget);
  });

  testWidgets('forgot password: email, code, new password, signed in', (tester) async {
    final h = await _harness();
    await _open(tester, h.app);

    await tester.enterText(find.byKey(const Key('auth-identifier')), 'asha@example.com');
    await tester.tap(find.byKey(const Key('auth-forgot')));
    await tester.pumpAndSettle();

    // The email carries over from the sign-in box.
    expect(_text(tester, const Key('reset-email')), 'asha@example.com');
    await tester.tap(find.text('Send code'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle(const Duration(milliseconds: 300));
    expect(h.server.posts.last.$1, 'auth/password/forgot');
    expect(find.textContaining('Resend in'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reset-code')), '999999');
    await tester.enterText(find.byKey(const Key('reset-password')), 'brand-new-pass');
    await tester.enterText(find.byKey(const Key('reset-confirm')), 'brand-new-pass');
    await tester.tap(find.text('Set password and sign in'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('code is wrong'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('reset-code')), '123456');
    await tester.tap(find.text('Set password and sign in'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(h.auth.isSignedIn, isTrue);
    expect(find.text('OPEN'), findsOneWidget, reason: 'both screens close');
    // Let the resend timer's widget go away cleanly.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('no "Forgot password?" when the admin panel turns it off', (tester) async {
    final h = await _harness();
    h.server.appConfig = _config(reset: false);
    await h.cfg.load();
    await _open(tester, h.app);
    expect(find.byKey(const Key('auth-forgot')), findsNothing);
  });

  testWidgets('Google appears as soon as the admin enables it, without restarting', (tester) async {
    final h = await _harness();
    expect(h.cfg.config.googleSignIn, isFalse);
    h.server.appConfig = _config(google: true);
    await _open(tester, h.app);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  test('password strength', () {
    expect(passwordStrength(''), 0);
    expect(passwordStrength('short'), 1);
    expect(passwordStrength('allletters'), 1);
    expect(passwordStrength('letters123'), 2);
    expect(passwordStrength('Letters-123-long'), 3);
  });
}
