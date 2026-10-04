import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/booking_repository.dart';
import 'package:temple_app/core/api/donation_repository.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/bookings_controller.dart';
import 'package:temple_app/features/bookings/bookings_screen.dart';
import 'package:temple_app/features/donations/donate_screen.dart';
import 'package:temple_app/features/events/event_screen.dart';

import 'booking_test.dart' show bookingJson, templeHarness, templeJson;

Map<String, dynamic> bhajanJson() => {
      'id': 42,
      'type': 'bhajan',
      'title': 'Friday Rama Bhajan',
      'description': 'Sing along.',
      'image_url': null,
      'starts_on': '2026-09-04',
      // A weekly gathering that goes on has no last day.
      'ends_on': null,
      'date_label': 'Every Friday',
      'is_all_day': false,
      'starts_at': '18:30',
      'ends_at': '20:00',
      'is_happening_today': false,
      'recurrence': 'weekly',
      'next_on': '2026-10-09',
      'next_dates': ['2026-10-09', '2026-10-16', '2026-10-23'],
      'group_name': 'Sri Rama Bhajan Mandali',
      'open_to_all': true,
      'songs': ['Raghupati Raghava', ' ', 'Sri Rama Jaya Rama'],
      'registration': {'enabled': true, 'is_paid': true, 'price_paise': 10000, 'price': '₹100.00 per person', 'capacity': 40, 'max_people': 4, 'going': 38},
      'temple': {'id': 1, 'slug': 'ram-mandir', 'name': 'Sri Rama Mandiram', 'city': 'Hyderabad'},
    };

Map<String, dynamic> ticketJson({String status = 'pending_payment', bool canPay = true}) => {
      'kind': 'event',
      'reference': 'EV7K3M9QXA',
      'code': null,
      'qr_url': null,
      'status': {'value': status, 'label': status == 'confirmed' ? 'Confirmed' : 'Awaiting payment'},
      'is_live': status == 'confirmed',
      'event': {'id': 42, 'title': 'Friday Rama Bhajan', 'type': 'bhajan', 'group_name': 'Sri Rama Bhajan Mandali', 'starts_at': '18:30', 'ends_at': '20:00', 'image_url': null},
      'temple': {'id': 1, 'slug': 'ram-mandir', 'name': 'Sri Rama Mandiram', 'city': 'Hyderabad'},
      'occurs_on': '2099-10-09',
      'booked_for': '2099-10-09',
      'people': 2,
      'devotee_name': 'Anu',
      'devotee_phone': '9999999999',
      'amount_paise': 20000,
      'amount': '₹200.00',
      'is_free': false,
      'payment': null,
      'can_cancel': true,
      'can_pay': canPay,
      'created_at': '2026-10-02T10:00:00+05:30',
    };

/// A JSON answer in UTF-8: the rupee sign is not Latin-1.
http.Response _res(Object body, int status) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('Event model', () {
    test('a weekly bhajan reads its dates, songs and registration; a null ends_on is fine', () {
      final e = TempleEvent.fromJson(bhajanJson());
      expect(e.isBhajan, isTrue);
      expect(e.isWeekly, isTrue);
      expect(e.endsOn, isNull);
      expect(e.nextDate, DateTime(2026, 10, 9));
      expect(e.upcomingDates, hasLength(3));
      expect(e.groupName, 'Sri Rama Bhajan Mandali');
      expect(e.songs, ['Raghupati Raghava', 'Sri Rama Jaya Rama']);
      expect(e.startsAt, '18:30');
      expect(e.isAllDay, isFalse);
      expect(e.registration.enabled, isTrue);
      expect(e.registration.isPaid, isTrue);
      expect(e.registration.totalFor(3), 30000);
      expect(e.registration.left, 2);
      expect(e.registration.isFull, isFalse);
      expect(e.templeSlug, 'ram-mandir');
    });

    test('an event from an older server, with none of the new keys, still parses', () {
      final e = TempleEvent.fromJson({'id': 7, 'title': 'Brahmotsavam', 'starts_on': '2026-11-01'});
      expect(e.recurrence, 'none');
      expect(e.isWeekly, isFalse);
      expect(e.nextDates, isEmpty);
      expect(e.nextDate, DateTime(2026, 11, 1));
      expect(e.upcomingDates, [DateTime(2026, 11, 1)]);
      expect(e.songs, isEmpty);
      expect(e.openToAll, isTrue);
      expect(e.registration.enabled, isFalse);
      expect(e.registration.left, isNull);
      expect(e.registration.totalFor(2), 0);
    });
  });

  group('Event tickets', () {
    test('a ticket reads like a seva booking, and survives being saved on the device', () {
      final t = PujaBooking.fromJson(ticketJson());
      expect(t.isEvent, isTrue);
      expect(t.eventId, 42);
      expect(t.pujaName, 'Friday Rama Bhajan');
      expect(t.groupName, 'Sri Rama Bhajan Mandali');
      expect(t.bookedFor, DateTime(2099, 10, 9));
      expect(t.people, 2);
      expect(t.canPay, isTrue);
      expect(t.code, '');

      final again = PujaBooking.fromJson(jsonDecode(jsonEncode(t.toJson())) as Map<String, dynamic>);
      expect(again.isEvent, isTrue);
      expect(again.eventId, 42);
      expect(again.pujaName, 'Friday Rama Bhajan');
      expect(again.groupName, 'Sri Rama Bhajan Mandali');

      // A seva booking stays a seva booking.
      final seva = PujaBooking.fromJson({'reference': 'SV1', 'puja': {'id': 5, 'name': 'Archana'}, 'booked_for': '2099-01-01'});
      expect(seva.isEvent, isFalse);
      expect(PujaBooking.fromJson(seva.toJson()).isEvent, isFalse);
    });

    test('joining a paid gathering posts to the event and hands back the seva checkout', () async {
      late http.Request sent;
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
        sent = r;
        return _res({'data': ticketJson(), 'checkout': {'payment': {'id': 'pay-1', 'gateway': 'razorpay'}, 'checkout_url': 'https://pay.test/x', 'sdk': null}}, 201);
      }));
      final start = await BookingRepository(api).joinEvent(eventId: 42, occursOn: DateTime(2026, 10, 16), people: 2, name: 'Anu', platform: 'android');
      expect(sent.url.path, '/api/v1/events/42/join');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['occurs_on'], '2026-10-16');
      expect(body['people'], 2);
      expect(body['mode'], 'sdk');
      expect(start.booking.isEvent, isTrue);
      expect(start.needsPayment, isTrue);
      expect(start.checkout?.paymentId, 'pay-1');
      expect(start.checkout?.checkoutUrl, 'https://pay.test/x');
    });

    test('tickets sit in the bookings list, and are re-read and cancelled at their own address', () async {
      SharedPreferences.setMockInitialValues({'devotee_token': 't', 'devotee': jsonEncode({'id': 1, 'name': 'Anu'})});
      final prefs = await SharedPreferences.getInstance();
      final paths = <String>[];
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
        paths.add('${r.method} ${r.url.path}');
        if (r.url.path.endsWith('/me/event-tickets')) return _res({'data': [ticketJson(status: 'confirmed', canPay: false)]}, 200);
        if (r.url.path.endsWith('/me/bookings')) return _res({'data': []}, 200);
        if (r.url.path.endsWith('/cancel')) return _res({'data': ticketJson(status: 'cancelled', canPay: false)}, 200);
        return _res({'data': ticketJson(status: 'confirmed', canPay: false)}, 200);
      }));
      final ctl = BookingsController(prefs, api: api, auth: AuthController(prefs, api));
      await ctl.refreshAll();
      expect(ctl.byReference('EV7K3M9QXA')?.isEvent, isTrue);
      expect(ctl.upcomingCount, 1);

      // Refreshing seva bookings alone keeps the tickets.
      await ctl.refresh();
      expect(ctl.byReference('EV7K3M9QXA'), isNotNull);

      await ctl.reload('EV7K3M9QXA');
      expect(paths.last, 'GET /api/v1/me/event-tickets/EV7K3M9QXA');
      await ctl.cancel('EV7K3M9QXA');
      expect(paths.last, 'POST /api/v1/me/event-tickets/EV7K3M9QXA/cancel');
      expect(ctl.byReference('EV7K3M9QXA')?.status, 'cancelled');
    });
  });

  group('Online hundi', () {
    test('a temple says whether its hundi is open, with purposes and limits', () {
      final d = TempleDetail.fromJson({
        'slug': 'ram-mandir',
        'name': 'Sri Rama Mandiram',
        'donations': {
          'enabled': true,
          'purposes': [
            {'value': 'general', 'label': 'General'},
            {'value': 'annadanam', 'label': 'Annadanam'},
          ],
          'min_amount': 10,
          'max_amount': 500000,
          'suggested_amounts': [101, 251, 501],
        },
      });
      expect(d.donations.enabled, isTrue);
      expect(d.donations.purposes.map((p) => p.value), ['general', 'annadanam']);
      expect(d.donations.minAmount, 10);
      expect(d.donations.maxAmount, 500000);
      expect(d.donations.suggestedAmounts, [101, 251, 501]);

      // An older server: closed.
      expect(TempleDetail.fromJson({'slug': 'x', 'name': 'X'}).donations.enabled, isFalse);
    });

    test('a gift and its receipt parse, and giving posts the amount in rupees', () async {
      final json = {
        'reference': 'HN4K2M',
        'status': {'value': 'paid', 'label': 'Received'},
        'amount_paise': 50100,
        'amount': '₹501.00',
        'purpose': {'value': 'annadanam', 'label': 'Annadanam'},
        'donor_name': null,
        'is_anonymous': true,
        'note': null,
        'temple': {'id': 1, 'slug': 'ram-mandir', 'name': 'Sri Rama Mandiram', 'city': 'Hyderabad'},
        'paid_at': '2026-10-02T10:00:00+05:30',
        'created_at': '2026-10-02T09:59:00+05:30',
      };
      final d = Donation.fromJson(json);
      expect(d.isPaid, isTrue);
      expect(d.statusLabel, 'Received');
      expect(d.amountPaise, 50100);
      expect(d.purposeLabel, 'Annadanam');
      expect(d.isAnonymous, isTrue);
      expect(d.templeName, 'Sri Rama Mandiram');

      final sparse = Donation.fromJson({'reference': 'HN1', 'amount_paise': 1000});
      expect(sparse.isPending, isTrue);
      expect(sparse.amountLabel, '₹10');

      late http.Request sent;
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
        sent = r;
        return _res({'data': {...json, 'status': {'value': 'pending_payment', 'label': 'Awaiting payment'}}, 'checkout': {'payment': {'id': 'pay-9', 'gateway': 'payu'}, 'checkout_url': 'https://pay.test/h'}}, 201);
      }));
      final start = await DonationRepository(api).give(templeSlug: 'ram-mandir', amountRupees: 501, purpose: 'annadanam', anonymous: true, platform: 'web');
      expect(sent.url.path, '/api/v1/temples/ram-mandir/donations');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['amount'], 501);
      expect(body['is_anonymous'], isTrue);
      expect(body.containsKey('donor_name'), isFalse);
      expect(start.donation.isPending, isTrue);
      expect(start.checkout?.paymentId, 'pay-9');
    });
  });

  group('Screens at the narrowest phone and large text', () {
    Future<void> narrow(WidgetTester tester) async {
      tester.view.physicalSize = const Size(320 * 3, 720 * 3);
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    }

    testWidgets('a weekly bhajan shows every-weekday, its dates, songs and Buy tickets', (tester) async {
      await narrow(tester);
      final client = MockClient((r) async => r.url.path == '/api/v1/events/42' ? _res({'data': bhajanJson()}, 200) : _res({'data': []}, 200));
      await tester.pumpWidget(await templeHarness(client, home: const EventScreen(id: 42)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Friday Rama Bhajan'), findsOneWidget);
      expect(find.text('Buy tickets'), findsOneWidget);
      final list = find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(find.text('Every Friday'), 200, scrollable: list);
      expect(find.text('Every Friday'), findsOneWidget);
      // The chips sit a little further down; a list child is not built
      // until it scrolls into the cache, so scroll until all three are.
      for (var i = 0; i < 12 && find.byType(ChoiceChip).evaluate().length < 3; i++) {
        await tester.drag(list, const Offset(0, -150));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
      }
      expect(find.byType(ChoiceChip), findsNWidgets(3));
      await tester.scrollUntilVisible(find.text('Raghupati Raghava'), 200, scrollable: list);
      expect(find.text('Sri Rama Jaya Rama'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the hundi offers suggested amounts within the limits and a custom one', (tester) async {
      await narrow(tester);
      final client = MockClient((r) async => _res({'data': []}, 200));
      const temple = TempleSummary(slug: 'ram-mandir', name: 'Sri Rama Mandiram', location: Location(), trust: Trust(level: TrustLevel.community));
      const settings = DonationSettings(enabled: true, purposes: [DonationPurpose(value: 'general', label: 'General'), DonationPurpose(value: 'annadanam', label: 'Annadanam')], minAmount: 10, maxAmount: 1000, suggestedAmounts: [101, 501, 1001, 5001]);
      await tester.pumpWidget(await templeHarness(client, home: const DonateScreen(temple: temple, settings: settings)));
      await tester.pump();
      expect(find.text('₹101'), findsOneWidget);
      expect(find.text('₹5,001'), findsNothing, reason: 'above the temple\'s limit');
      expect(find.text('Give ₹101'), findsOneWidget);
      expect(find.text('Annadanam'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Anu'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Anu'), findsOneWidget, reason: 'the receipt name starts as the account holder');
      await tester.scrollUntilVisible(find.byType(TextField).first, -200, scrollable: find.byType(Scrollable).first);
      await tester.enterText(find.byType(TextField).first, '5');
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull, reason: 'below the minimum');
      expect(tester.takeException(), isNull);
    });
  
    testWidgets('event tickets sit beside seva bookings, with a kind badge and a filter', (tester) async {
      await narrow(tester);
      final client = MockClient((r) async {
        if (r.url.path == '/api/v1/me/bookings') return _res({'data': [bookingJson()]}, 200);
        if (r.url.path == '/api/v1/me/event-tickets') return _res({'data': [ticketJson(status: 'confirmed', canPay: false)]}, 200);
        return _res({'data': []}, 200);
      });
      await tester.pumpWidget(await templeHarness(client, home: const BookingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Archana'), findsOneWidget);
      expect(find.text('Seva'), findsOneWidget);
      await tester.tap(find.text('Events'));
      await tester.pump();
      expect(find.text('Archana'), findsNothing);
      expect(find.text('Friday Rama Bhajan'), findsOneWidget);
      expect(find.text('Event'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  
    testWidgets('a temple with its hundi open offers Give to the hundi', (tester) async {
      await narrow(tester);
      final client = MockClient((r) async {
        if (r.url.path == '/api/v1/temples/booking-temple') {
          return _res({
            'data': {
              ...templeJson(),
              'donations': {'enabled': true, 'purposes': [{'value': 'general', 'label': 'General'}], 'min_amount': 10, 'max_amount': 500000, 'suggested_amounts': [101, 251]},
            },
          }, 200);
        }
        return _res({'data': []}, 200);
      });
      await tester.pumpWidget(await templeHarness(client));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.scrollUntilVisible(find.text('Give to the hundi'), 200, scrollable: find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)).first);
      expect(find.text('Give to the hundi'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
