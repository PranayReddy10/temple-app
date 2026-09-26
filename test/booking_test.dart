import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:temple_app/core/ads/ads.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/audio/audio_queue.dart';
import 'package:temple_app/core/api/booking_repository.dart';
import 'package:temple_app/core/api/seva_repository.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/services/push_service.dart';
import 'package:temple_app/core/state/app_config_controller.dart';
import 'package:temple_app/core/state/app_settings.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/bookings_controller.dart';
import 'package:temple_app/core/state/day_controller.dart';
import 'package:temple_app/core/state/engagement_controller.dart';
import 'package:temple_app/core/state/family_controller.dart';
import 'package:temple_app/core/state/favourites_controller.dart';
import 'package:temple_app/core/state/location_controller.dart';
import 'package:temple_app/core/state/mantra_player.dart';
import 'package:temple_app/core/state/memories_controller.dart';
import 'package:temple_app/core/state/notifications_controller.dart';
import 'package:temple_app/core/state/offline_pack_controller.dart';
import 'package:temple_app/core/state/passport_controller.dart';
import 'package:temple_app/core/state/reminders_controller.dart';
import 'package:temple_app/core/state/submissions_controller.dart';
import 'package:temple_app/core/state/subscription_controller.dart';
import 'package:temple_app/core/state/sync_service.dart';
import 'package:temple_app/core/state/yatra_controller.dart';
import 'package:temple_app/core/theme/app_theme.dart';
import 'package:temple_app/core/theme/day_theme.dart';
import 'package:temple_app/features/bookings/bookings_screen.dart';
import 'package:temple_app/features/temple/temple_screen.dart';

/// A booking exactly as `POST /temples/{slug}/pujas/{id}/bookings` and
/// `GET /me/bookings` return it, captured from PujaBookingResource.
Map<String, dynamic> bookingJson({String status = 'confirmed', String label = 'Confirmed', int amount = 0, bool canCancel = true}) => {
      'reference': 'SV7K3M9Q2X',
      'code': 'abcdefghijklmnopqrstuvwxyz12',
      'qr_url': 'http://localhost/bookings/abcdefghijklmnopqrstuvwxyz12',
      'status': {'value': status, 'label': label},
      'is_live': status == 'confirmed' || status == 'verified',
      'temple': {'id': 1, 'slug': 'booking-temple', 'name': 'Booking Temple', 'city': 'Warangal'},
      'puja': {'id': 5, 'name': 'Archana', 'kind': 'puja', 'starts_at': '06:00', 'image_url': null, 'instructions': 'Report at the seva counter.'},
      'booked_for': '2030-01-15',
      'people': 2,
      'devotee_name': 'Anu',
      'devotee_phone': '9876543210',
      'gotram': 'Bharadwaja',
      'nakshatram': null,
      'note': null,
      'amount_paise': amount,
      'amount': amount == 0 ? 'Free' : '₹${(amount / 100).toStringAsFixed(2)}',
      'is_free': amount == 0,
      'payment': amount == 0 ? null : {'id': 'pay-uuid', 'status': 'pending', 'gateway': 'razorpay', 'paid_at': null},
      'confirmed_at': null,
      'verified_at': null,
      'cancelled_at': null,
      'cancel_reason': null,
      'can_cancel': canCancel,
      'created_at': '2026-09-26T10:00:00+00:00',
    };

/// `GET /api/v1/temples/booking-temple` with one free seva open for booking
/// in the app and one priced one that is information only.
Map<String, dynamic> templeJson() => {
      'id': 1,
      'slug': 'booking-temple',
      'name': 'Sri Someshwara Swamy Temple',
      'deity': {'slug': 'shiva', 'name': 'Shiva'},
      'categories': [],
      'location': {'address': 'Temple Street', 'city': 'Kolanupaka', 'district': 'Yadadri Bhuvanagiri', 'state': 'Telangana', 'pincode': '508101', 'latitude': 17.6, 'longitude': 79.0},
      'about': {'short_description': 'An old Shiva temple.'},
      'visitor_rules': {},
      'contact': {},
      'trust': {'level': 'verified', 'label': 'Verified'},
      'timings': [
        {'kind': 'opening', 'label': 'Darshan', 'opens_at': '06:00', 'closes_at': '12:00', 'window': '06:00 – 12:00'},
      ],
      'pujas': [
        {
          'id': 5, 'kind': 'puja', 'name': 'Archana',
          'fee': {'is_free': true, 'amount': null, 'label': 'Free'},
          'booking': {'url': null, 'is_official': false},
          'app_booking': {'enabled': true, 'requires_payment': false, 'fee_per_person': true, 'amount_paise': 0, 'max_people': 4, 'advance_days': 7, 'instructions': 'Report at the seva counter.'},
        },
        {
          'id': 6, 'kind': 'seva', 'name': 'Abhishekam',
          'fee': {'is_free': false, 'amount': 1500, 'label': '₹1,500.00'},
          'booking': {'url': 'https://temple.example/seva', 'is_official': true, 'label': 'Official booking'},
          'app_booking': {'enabled': false},
        },
      ],
      'photos': [],
      'closures': [],
      'events': [],
      'facilities': [],
      'is_closed_today': false,
    };

/// Every provider the temple page reaches for, over one mock API.
Future<Widget> templeHarness(http.Client client, {bool signedIn = true}) async {
  SharedPreferences.setMockInitialValues({'door_animations': false, if (signedIn) 'devotee_token': 't', if (signedIn) 'devotee': jsonEncode({'id': 1, 'name': 'Anu', 'phone': '9876543210'})});
  final store = await SharedPreferences.getInstance();
  final api = ApiClient(baseUrl: 'http://api.test', client: client);
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
      ChangeNotifierProvider(create: (_) => LocationController(store)),
      ChangeNotifierProvider(create: (_) => OfflinePackController(store, repo)),
      ChangeNotifierProvider(create: (_) => BookingsController(store, api: api, auth: auth)),
      ChangeNotifierProvider.value(value: submissions),
      ChangeNotifierProvider.value(value: appConfig),
      ChangeNotifierProvider.value(value: inbox),
      ChangeNotifierProvider(create: (_) => SubscriptionController(api, auth)),
      ChangeNotifierProvider(create: (_) => AdsController(appConfig, auth)),
      Provider(create: (_) => PushService(prefs: store, api: api, auth: auth, config: appConfig, inbox: inbox)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(DayTheme.today()),
      supportedLocales: AppSettings.supportedLocales,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      home: const TempleScreen(slug: 'booking-temple'),
    ),
  );
}

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  group('Puja app booking contract', () {
    test('a seva is bookable in the app only when the temple switched it on', () {
      final off = Puja.fromJson({'id': 1, 'name': 'Archana', 'fee': {'is_free': false, 'amount': 100, 'label': '₹100.00'}, 'booking': {}, 'app_booking': {'enabled': false}});
      expect(off.isBookableInApp, isFalse);
      expect(off.kind, 'puja');

      final on = Puja.fromJson({
        'id': 2, 'kind': 'seva', 'name': 'Abhishekam',
        'fee': {'is_free': false, 'amount': 1500, 'label': '₹1,500.00'},
        'booking': {},
        'app_booking': {'enabled': true, 'requires_payment': true, 'fee_per_person': false, 'amount_paise': 150000, 'max_people': 6, 'advance_days': 14, 'capacity_per_day': 3, 'instructions': 'Bring milk.'},
      });
      expect(on.isBookableInApp, isTrue);
      expect(on.kind, 'seva');
      expect(on.appBooking.totalFor(4), 150000, reason: 'one fee for the booking, not per person');
      expect(on.appBooking.maxPeople, 6);

      final perPerson = Puja.fromJson({'id': 3, 'name': 'Archana', 'fee': {}, 'booking': {}, 'app_booking': {'enabled': true, 'requires_payment': true, 'amount_paise': 10000}});
      expect(perPerson.appBooking.totalFor(3), 30000);

      // A server that predates the field: nothing is bookable, nothing breaks.
      final old = Puja.fromJson({'id': 4, 'name': 'Old', 'fee': {}, 'booking': {}});
      expect(old.isBookableInApp, isFalse);
      expect(Puja.kindLabel('prasadam'), 'Prasadam');
    });

    test('a booking parses, round-trips through storage and knows when it is over', () {
      final b = PujaBooking.fromJson(bookingJson(amount: 20000));
      expect(b.reference, 'SV7K3M9Q2X');
      expect(b.qrData, contains('/bookings/abcdefghijklmnopqrstuvwxyz12'));
      expect(b.isConfirmed, isTrue);
      expect(b.isFree, isFalse);
      expect(b.paymentId, 'pay-uuid');
      expect(b.isPast, isFalse);

      final again = PujaBooking.fromJson(b.toJson());
      expect(again.reference, b.reference);
      expect(again.bookedFor, b.bookedFor);
      expect(again.gotram, 'Bharadwaja');
      expect(again.instructions, 'Report at the seva counter.');

      expect(PujaBooking.fromJson(bookingJson(status: 'verified', label: 'Verified at the temple')).isPast, isTrue);
      expect(PujaBooking.fromJson(bookingJson(status: 'cancelled', label: 'Cancelled')).isPast, isTrue);
    });
  });

  group('Booking repository', () {
    test('a priced seva answers with the booking and the same checkout the plans use', () async {
      late http.Request sent;
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
        sent = r;
        // Bytes, not a string: the rupee sign is not Latin-1.
        return http.Response.bytes(utf8.encode(jsonEncode({
          'data': bookingJson(status: 'pending_payment', label: 'Awaiting payment', amount: 20000),
          'checkout': {
            'payment': {'id': 'pay-uuid', 'status': 'created', 'gateway': 'razorpay', 'purpose': 'puja_booking'},
            'sdk': {'gateway': 'razorpay', 'key': 'rzp_test', 'order_id': 'order_1', 'amount_paise': 20000},
            'sdk_error': null,
            'checkout_url': 'https://site/pay/pay-uuid?signature=x',
            'done_url': 'https://site/pay/pay-uuid/done',
          },
        })), 201, headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      final start = await BookingRepository(api).book(templeSlug: 'booking-temple', pujaId: 5, day: DateTime(2030, 1, 15), people: 2, gotram: 'Bharadwaja', platform: 'android');
      expect(sent.url.path, '/api/v1/temples/booking-temple/pujas/5/bookings');
      final body = jsonDecode(sent.body) as Map<String, dynamic>;
      expect(body['booked_for'], '2030-01-15');
      expect(body['people'], 2);
      expect(body['mode'], 'sdk');
      expect(start.needsPayment, isTrue);
      expect(start.paymentId, 'pay-uuid');
      expect(start.sdk!['order_id'], 'order_1');
      expect(start.booking.isPendingPayment, isTrue);
    });

    test('a free seva answers with no checkout and is already confirmed', () async {
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => http.Response(jsonEncode({'data': bookingJson(), 'checkout': null}), 201)));
      final start = await BookingRepository(api).book(templeSlug: 'booking-temple', pujaId: 5, day: DateTime(2030, 1, 15), people: 2, platform: 'android');
      expect(start.needsPayment, isFalse);
      expect(start.booking.isConfirmed, isTrue);
    });
  });

  group('Bookings controller', () {
    test('keeps bookings on the device and refreshes them from the server when signed in', () async {
      SharedPreferences.setMockInitialValues({'devotee_token': 't', 'devotee': jsonEncode({'id': 1, 'name': 'Anu'})});
      final prefs = await SharedPreferences.getInstance();
      var calls = 0;
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
        calls++;
        if (r.url.path.endsWith('/me/bookings')) return http.Response(jsonEncode({'data': [bookingJson(status: 'verified', label: 'Verified at the temple')]}), 200);
        if (r.url.path.endsWith('/cancel')) return http.Response(jsonEncode({'data': bookingJson(status: 'cancelled', label: 'Cancelled', canCancel: false)}), 200);
        return http.Response('{}', 404);
      }));
      final ctl = BookingsController(prefs, api: api, auth: AuthController(prefs, api));
      expect(ctl.canSync, isTrue);

      await ctl.put(PujaBooking.fromJson(bookingJson()));
      expect(ctl.upcomingBooked, hasLength(1));
      expect(ctl.upcomingCount, 1);

      // Survives a restart before any server contact.
      final again = BookingsController(prefs, api: api, auth: AuthController(prefs, api));
      expect(again.byReference('SV7K3M9Q2X')?.isConfirmed, isTrue);

      await ctl.refresh();
      expect(calls, 1);
      expect(ctl.byReference('SV7K3M9Q2X')?.isVerified, isTrue);
      expect(ctl.upcomingBooked, isEmpty);

      final cancelled = await ctl.cancel('SV7K3M9Q2X');
      expect(cancelled.status, 'cancelled');
      expect(ctl.byReference('SV7K3M9Q2X')?.canCancel, isFalse);
    });

    test('signed out, nothing is fetched and the noted bookings still work', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => throw StateError('must not be called')));
      final ctl = BookingsController(prefs, api: api, auth: AuthController(prefs, api));
      expect(ctl.canSync, isFalse);
      await ctl.refresh();
      await ctl.add(SevaBooking(id: 'n1', templeSlug: 't', templeName: 'T', pujaName: 'Archana', date: DateTime.now().add(const Duration(days: 2))));
      expect(ctl.upcomingCount, 1);
    });
  });

  group('Reverse geocoding', () {
    test('a dropped pin comes back as PIN code, village, district, state and street', () async {
      late Uri asked;
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
        asked = r.url;
        return http.Response(jsonEncode({'data': {
          'pincode': '508101', 'state': 'Telangana', 'state_id': 3, 'district': 'Yadadri Bhuvanagiri', 'city': 'Kolanupaka', 'address': 'Temple Street',
          'places': [{'name': 'Kolanupaka', 'block': null}], 'latitude': 17.6, 'longitude': 79.0,
        }}), 200);
      }));
      final info = await SevaRepository(api).reverseGeocode(17.6, 79.0);
      expect(asked.path, '/api/v1/geocode/reverse');
      expect(asked.queryParameters['lat'], '17.600000');
      expect(info!.pincode, '508101');
      expect(info.city, 'Kolanupaka');
      expect(info.address, 'Temple Street');
      expect(info.stateId, 3);
      expect(info.places, ['Kolanupaka']);
    });

    test('nothing at the spot is null; the map being down is an error the form can show', () async {
      final none = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => http.Response(jsonEncode({'message': 'Nothing is on the map at that spot.'}), 404)));
      expect(await SevaRepository(none).reverseGeocode(0, 0), isNull);

      final down = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => http.Response(jsonEncode({'message': 'The map could not be reached. Fill in the address yourself for now.'}), 503)));
      await expectLater(SevaRepository(down).reverseGeocode(1, 1), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('could not be reached'))));

      // The PIN code directory being down is told apart from a wrong code.
      final pinDown = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => http.Response(jsonEncode({'message': 'The PIN code directory could not be reached. Drop a pin where you are, or fill in the address yourself.'}), 503)));
      await expectLater(SevaRepository(pinDown).pincode('508101'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)));
    });
  });

  testWidgets('a booking shows its code, reference and status for the counter', (tester) async {
    SharedPreferences.setMockInitialValues({'puja_bookings': jsonEncode([bookingJson(amount: 20000)])});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => http.Response.bytes(utf8.encode(jsonEncode({'data': bookingJson(amount: 20000)})), 200, headers: {'content-type': 'application/json; charset=utf-8'})));
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
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
    expect(find.text('SV7K3M9Q2X'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Archana'), findsWidgets);
    // The instructions and the cancel button sit below the ticket.
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    expect(find.text('Report at the seva counter.'), findsOneWidget);
    expect(find.text('Cancel booking'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider(create: (_) => BookingsController(prefs, api: api, auth: AuthController(prefs, api))),
      ],
      child: const MaterialApp(home: BookingsScreen()),
    ));
    await tester.pump();
    expect(find.text('Archana'), findsOneWidget);
    expect(find.text('SV7K3M9Q2X'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the temple page offers booking only for the seva the temple opened, and books it', (tester) async {
    final posted = <http.Request>[];
    final client = MockClient((r) async {
      if (r.url.path == '/api/v1/temples/booking-temple') return _json({'data': templeJson()});
      if (r.url.path == '/api/v1/temples/booking-temple/pujas/5/bookings') {
        posted.add(r);
        return _json({'data': bookingJson(), 'checkout': null}, 201);
      }
      if (r.url.path == '/api/v1/me/bookings') return _json({'data': []});
      return _json({'data': []});
    });
    // The narrowest phone and large text: where a card overflows if it will.
    tester.view.physicalSize = const Size(320 * 3, 720 * 3);
    tester.view.devicePixelRatio = 3;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(await templeHarness(client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Sri Someshwara Swamy Temple'), findsWidgets);

    // Down to the seva section.
    for (var i = 0; i < 12 && find.text('Archana').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
    }
    expect(find.text('Archana'), findsOneWidget);
    expect(find.text('Abhishekam'), findsOneWidget);
    // One button, on the one seva the temple opened; the other keeps its official link.
    expect(find.textContaining('Book in the app'), findsWidgets);
    expect(find.text('Book'), findsOneWidget, reason: 'the official link on the seva that is information only');
    expect(tester.takeException(), isNull);

    // Into the middle of the viewport: the pinned bars would otherwise sit
    // over a button at the very top or bottom.
    await Scrollable.ensureVisible(tester.element(find.byIcon(Icons.event_available_rounded)), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.event_available_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Which day?'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Anu'), findsOneWidget, reason: 'the sankalpam name starts as the account holder');
    expect(tester.takeException(), isNull);

    // The sheet scrolls too; the button is under its own fold at this size.
    await Scrollable.ensureVisible(tester.element(find.widgetWithText(FilledButton, 'Book')), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Book'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(posted, hasLength(1));
    final body = jsonDecode(posted.first.body) as Map<String, dynamic>;
    expect(body['people'], 1);
    expect(body['devotee_name'], 'Anu');
    // The ticket, with its reference, straight after.
    expect(find.text('SV7K3M9Q2X'), findsOneWidget);
    expect(find.text('Booked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
