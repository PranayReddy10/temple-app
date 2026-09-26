import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/api/temple_suggestion_repository.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/location_controller.dart';
import 'package:temple_app/features/add_temple/add_temple_screen.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget screen, http.Client client) async {
    SharedPreferences.setMockInitialValues({'devotee_token': 't', 'devotee': jsonEncode({'id': 7, 'name': 'Sita'})});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(baseUrl: 'http://localhost', client: client);
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        Provider<TempleRepository>.value(value: TempleRepository(api)),
        ChangeNotifierProvider(create: (_) => AuthController(prefs, api)),
        ChangeNotifierProvider(create: (_) => LocationController(prefs)),
      ],
      child: MaterialApp(home: screen),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('the add-a-temple form lays out at phone width and starts from the name', (tester) async {
    await pump(tester, const AddTempleScreen(initialName: 'Someshwara'), MockClient((req) async => http.Response(jsonEncode({'data': [], 'meta': {'current_page': 1, 'last_page': 1}}), 200)));
    expect(find.text('Temple name'), findsOneWidget);
    expect(find.text('Where it is'), findsOneWidget);
    expect(find.text('Photos & you'), findsOneWidget);
    expect(find.text('Not listed yet — add it'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a temple member is told what happens next', (tester) async {
    await pump(tester, const AddTempleScreen(initialName: 'Someshwara'), MockClient((_) async => http.Response(jsonEncode({'data': []}), 200)));
    await tester.tap(find.text('Photos & you'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Trustee'));
    await tester.pumpAndSettle();
    expect(find.textContaining('their own app'), findsOneWidget);
    expect(find.text('Your phone'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('temples I added show what the team did', (tester) async {
    await pump(
      tester,
      const MyAddedTemplesScreen(),
      MockClient((_) async => http.Response(jsonEncode({'data': [
            {'id': 1, 'name': 'Sri Someshwara Swamy Temple', 'city': 'Kolanupaka', 'status': {'value': 'pending', 'label': 'Being reviewed'}},
            {'id': 2, 'name': 'Old Hanuman shrine', 'city': 'Alair', 'status': {'value': 'duplicate', 'label': 'Already listed'}, 'review_note': 'Listed as Alair Anjaneya.', 'temple': {'slug': 'alair-anjaneya', 'name': 'Alair Anjaneya'}},
          ]}), 200)),
    );
    expect(find.text('Being reviewed'), findsOneWidget);
    expect(find.text('Already listed'), findsOneWidget);
    expect(find.textContaining('Listed as Alair Anjaneya.'), findsOneWidget);
  });

  test('temple members are the roles that must leave a number', () {
    expect(TempleSuggestionRepository.isTempleMember('trustee'), isTrue);
    expect(TempleSuggestionRepository.isTempleMember('priest'), isTrue);
    expect(TempleSuggestionRepository.isTempleMember('devotee'), isFalse);
    expect(TempleSuggestionRepository.isTempleMember('other'), isFalse);
  });
}
