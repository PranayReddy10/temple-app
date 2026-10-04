import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:provider/provider.dart';
import 'package:temple_app/core/state/engagement_controller.dart';
import 'package:temple_app/features/events/raise_bhajan_screen.dart';

import 'booking_test.dart' show templeHarness;

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

/// A devotee organises a bhajan at a temple, as they would a seva drive. The
/// form sends the day, the time and the songs; it never sends a price, and
/// what comes back is free and waiting for the editors.
void main() {
  testWidgets('raising a bhajan posts it to the temple, free, and says it is under review', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 1500 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    Map<String, dynamic>? sent;
    final client = MockClient((r) async {
      if (r.url.path == '/api/v1/temples/sri-rama/bhajans' && r.method == 'POST') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return _json({
          'data': {
            'id': 77,
            'type': 'bhajan',
            'title': sent!['title'],
            'starts_on': sent!['starts_on'],
            'recurrence': sent!['recurrence'],
            'raised_by_devotee': true,
            'registration': {'enabled': true, 'is_paid': false, 'price_paise': 0},
            'status': {'value': 'pending_review', 'label': 'Waiting for review'},
          }
        }, 201);
      }
      return _json({'data': []});
    });
    const temple = TempleSummary(slug: 'sri-rama', name: 'Sri Rama Temple', location: Location(city: 'Bhadrachalam'), trust: Trust(level: TrustLevel.community));
    await tester.pumpWidget(await templeHarness(client, home: const RaiseBhajanScreen(temple: temple)));
    await tester.pumpAndSettle();

    expect(find.text('Organise a bhajan here'), findsOneWidget);
    expect(find.textContaining('Always free'), findsOneWidget);

    // Nothing is sent without a name.
    await tester.tap(find.text('Send to the editors'));
    await tester.pumpAndSettle();
    expect(sent, isNull);

    await tester.enterText(find.widgetWithText(TextFormField, 'What is it called'), 'Friday Rama Bhajan');
    await tester.enterText(find.widgetWithText(TextFormField, 'Mandali or group (optional)'), 'Sri Rama Bhajan Mandali');
    await tester.enterText(find.widgetWithText(TextFormField, 'What will be sung (one per line, optional)'), 'Raghupati Raghava\nSri Rama Jaya Rama');
    await tester.ensureVisible(find.text('Send to the editors'));
    await tester.tap(find.text('Send to the editors'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(sent, isNotNull);
    expect(sent!['title'], 'Friday Rama Bhajan');
    expect(sent!['group_name'], 'Sri Rama Bhajan Mandali');
    expect(sent!['recurrence'], 'weekly');
    expect(sent!['open_to_all'], isTrue);
    expect(sent!['starts_at'], '18:30');
    expect(sent!['ends_at'], '20:00');
    expect(sent!['songs'], 'Raghupati Raghava\nSri Rama Jaya Rama');
    expect(sent!.containsKey('ticket_price'), isFalse);
    expect(sent!.containsKey('registration_enabled'), isFalse);

    expect(find.text('Sent for review'), findsOneWidget);
    expect(find.textContaining("Sri Rama Temple's page, free"), findsOneWidget);
  });

  testWidgets('from Home, a temple is picked first: the followed ones, or any by name', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 1200 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final client = MockClient((r) async {
      if (r.url.path == '/api/v1/temples' && r.url.queryParameters['q'] == 'tiru') {
        return _json({'data': [{'slug': 'tirumala', 'name': 'Tirumala Venkateswara', 'city': 'Tirupati', 'trust': {'level': 'official'}}], 'meta': {'current_page': 1, 'last_page': 1}});
      }
      return _json({'data': []});
    });
    const followed = TempleSummary(slug: 'sri-rama', name: 'Sri Rama Temple', location: Location(city: 'Bhadrachalam'), trust: Trust(level: TrustLevel.community));
    late BuildContext ctx;
    await tester.pumpWidget(await templeHarness(client, home: Builder(builder: (c) {
      ctx = c;
      return Scaffold(body: Center(child: TextButton(onPressed: () => raiseBhajanSomewhere(c), child: const Text('Organise one'))));
    })));
    await tester.pump();
    await ctx.read<EngagementController>().toggleFollow(followed);
    await tester.pump();

    await tester.tap(find.text('Organise one'));
    await tester.pumpAndSettle();
    expect(find.text('At which temple?'), findsOneWidget);
    expect(find.text('Sri Rama Temple'), findsOneWidget, reason: 'a followed temple is offered first');

    await tester.enterText(find.byType(TextField), 'tiru');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Tirumala Venkateswara'), findsOneWidget);

    await tester.tap(find.text('Tirumala Venkateswara'));
    await tester.pumpAndSettle();
    expect(find.text('Organise a bhajan here'), findsOneWidget);
    expect(find.textContaining('A bhajan at Tirumala Venkateswara'), findsOneWidget);
  });
}
