import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/booking_repository.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/bookings_controller.dart';
import 'package:temple_app/features/bookings/bookings_screen.dart';

import 'booking_test.dart' show bookingJson;

Future<void> _pumpTicket(WidgetTester tester, Map<String, dynamic> json) async {
  SharedPreferences.setMockInitialValues({'puja_bookings': jsonEncode([json])});
  final prefs = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => http.Response.bytes(utf8.encode(jsonEncode({'data': json})), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
  tester.view.physicalSize = const Size(360 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: api),
      ChangeNotifierProvider(create: (_) => BookingsController(prefs, api: api, auth: AuthController(prefs, api))),
    ],
    child: const MaterialApp(home: BookingDetailScreen(reference: 'SV7K3M9Q2X')),
  ));
  await tester.pump();
}

void main() {
  test('slots read places left, full and started', () {
    final open = PujaSlot.fromJson({'id': 3, 'starts_at': '09:00', 'ends_at': '10:00', 'label': '9:00 – 10:00 AM', 'capacity': 15, 'available': 2, 'started': false, 'bookable': true});
    expect(open.fits(2), isTrue);
    expect(open.fits(3), isFalse);
    final full = PujaSlot.fromJson({'id': 4, 'starts_at': '10:00', 'label': '10:00 AM', 'capacity': 15, 'available': 0, 'bookable': false});
    expect(full.isFull, isTrue);
    expect(full.fits(1), isFalse);
    final unlimited = PujaSlot.fromJson({'id': 5, 'starts_at': '18:00', 'label': 'From 6:00 PM', 'available': null});
    expect(unlimited.fits(50), isTrue);
  });

  test('the app asks for the slots of the chosen day and books into one', () async {
    final asked = <Uri>[];
    Map<String, dynamic>? sent;
    final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
      asked.add(r.url);
      if (r.method == 'POST') {
        sent = jsonDecode(r.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'data': bookingJson(), 'checkout': null}), 201);
      }
      return http.Response.bytes(utf8.encode(jsonEncode({'data': [{'id': 3, 'starts_at': '09:00', 'ends_at': '10:00', 'label': '9:00 – 10:00 AM', 'available': 11, 'bookable': true}]})), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final repo = BookingRepository(api);

    final slots = await repo.slots(templeSlug: 'booking-temple', pujaId: 5, day: DateTime(2030, 1, 2));
    expect(asked.last.path, '/api/v1/temples/booking-temple/pujas/5/slots');
    expect(asked.last.queryParameters['date'], '2030-01-02');
    expect(slots.single.label, '9:00 – 10:00 AM');

    await repo.book(templeSlug: 'booking-temple', pujaId: 5, day: DateTime(2030, 1, 2), slotId: slots.single.id, people: 2, platform: 'android');
    expect(sent!['slot_id'], 3);
    expect(sent!['booked_for'], '2030-01-02');
  });

  testWidgets('the ticket shows the day and time slot, valid on that day only', (tester) async {
    await _pumpTicket(tester, {...bookingJson(), 'slot': {'starts_at': '09:00', 'ends_at': '10:00', 'label': '9:00 – 10:00 AM'}});

    expect(find.text('DATE'), findsOneWidget);
    expect(find.text('15 Jan'), findsOneWidget);
    expect(find.text('TIME'), findsOneWidget);
    expect(find.text('9:00 – 10:00 AM'), findsOneWidget);
    expect(find.text('Valid on Tue, 15 Jan 2030 only'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a ticket whose day has passed shows Expired, with no code to use', (tester) async {
    await _pumpTicket(tester, {...bookingJson(status: 'expired', label: 'Expired', canCancel: false), 'booked_for': '2026-10-02', 'is_live': false, 'code': null, 'qr_url': null, 'slot': {'starts_at': '09:00', 'ends_at': '10:00', 'label': '9:00 – 10:00 AM'}});

    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('EXPIRED'), findsOneWidget);
    expect(find.textContaining('expired when the day ended'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pump();
    expect(find.text('Cancel booking'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('a confirmed booking for a past day reads as expired even before the server says so', () {
    final b = PujaBooking.fromJson({...bookingJson(), 'booked_for': '2020-01-01'});
    expect(b.isExpired, isTrue);
    expect(b.isPast, isTrue);
    final upcoming = PujaBooking.fromJson(bookingJson());
    expect(upcoming.isExpired, isFalse);
  });
}
