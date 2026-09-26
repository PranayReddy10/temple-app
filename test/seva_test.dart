import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/seva_repository.dart';
import 'package:temple_app/core/models/seva.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/location_controller.dart';
import 'package:temple_app/features/seva/raise_drive_screen.dart';
import 'package:temple_app/features/seva/seva_drive_screen.dart';
import 'package:temple_app/features/seva/seva_screen.dart';
import 'package:temple_app/features/seva/seva_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A verified drive exactly as `GET /api/v1/seva-drives/{id}` returns it,
/// captured from the backend's SevaDriveResource.
Map<String, dynamic> verifiedDrive() => {
      'id': 1,
      'title': 'Clean the stepwell at Hampi',
      'cause': {'value': 'water_body', 'label': 'Temple tank / stepwell'},
      'status': {'value': 'verified', 'label': 'Verified'},
      'is_verified': true,
      'place': {'name': 'Pushkarini', 'address': null, 'city': 'Hampi', 'state': null, 'latitude': 15.33, 'longitude': 76.46, 'meeting_point': null},
      'temple': null,
      'problem': 'Silt and plastic have filled the lower steps.',
      'plan': 'Remove the plastic by hand and carry the silt out.',
      'what_to_bring': 'Gloves, sacks',
      'starts_at': '2026-09-25T09:25:40+00:00',
      'ends_at': null,
      'volunteers_needed': 10,
      'volunteers_joined': 3,
      'signups': 1,
      'organiser': {'name': 'Ravi Kumar', 'avatar_url': null, 'is_team': false},
      'is_misleading': false,
      'misleading_note': null,
      'is_multi_day': false,
      'contact_phone': null,
      'cover_url': 'http://localhost/storage/seva-drives/1/after/b.jpg',
      'media': {
        'before': [
          {'id': 1, 'stage': 'before', 'type': 'photo', 'url': 'http://localhost/storage/seva-drives/1/before/a.jpg', 'is_link': false, 'caption': null},
        ],
        'after': [
          {'id': 2, 'stage': 'after', 'type': 'photo', 'url': 'http://localhost/storage/seva-drives/1/after/b.jpg', 'is_link': false, 'caption': null},
          {'id': 3, 'stage': 'after', 'type': 'video', 'url': 'https://youtu.be/x', 'is_link': true, 'caption': null},
        ],
      },
      'completion_note': 'Done well.',
      'completed_at': '2026-09-26T09:25:40+00:00',
      'verified_at': null,
      'donations': {
        'open': true,
        'upi_id': 'ravi@okaxis',
        'upi_name': 'Ravi Kumar',
        'upi_link': 'upi://pay?pa=ravi@okaxis&pn=Ravi%20Kumar&cu=INR&tn=Seva%3A%20Clean%20the%20stepwell%20at%20Hampi',
        'goal': 5000,
        'purpose': null,
        'raised': 700,
        'donors': 2,
      },
      'viewer': {'is_organiser': false, 'has_joined': false, 'can_join': false, 'can_edit': false, 'can_complete': false},
      'created_at': '2026-09-26T09:25:40+00:00',
    };

void main() {
  group('SevaDrive contract', () {
    test('parses a verified drive from the API', () {
      final d = SevaDrive.fromJson(verifiedDrive());
      expect(d.isVerified, isTrue);
      expect(d.stage, 3);
      expect(d.cause.value, 'water_body');
      expect(d.where, 'Pushkarini, Hampi');
      expect(d.before, hasLength(1));
      expect(d.after, hasLength(2));
      expect(d.after.last.isLink, isTrue);
      expect(d.volunteerProgress, closeTo(0.3, 0.001));
      expect(d.donations.open, isTrue);
      expect(d.donations.upiId, 'ravi@okaxis');
      expect(d.donations.progress, closeTo(0.14, 0.001));
      expect(d.hasCoordinates, isTrue);
    });

    test('a pending drive shows no UPI ID and sits at the first stage', () {
      final json = verifiedDrive()
        ..['status'] = {'value': 'pending', 'label': 'Waiting for review'}
        ..['donations'] = {'open': false, 'upi_id': null, 'upi_name': null, 'upi_link': null, 'goal': 5000, 'purpose': null, 'raised': null}
        ..['viewer'] = {'is_organiser': true, 'has_joined': false, 'can_join': false, 'can_edit': true, 'can_complete': false}
        ..['mine'] = {'upi_id': 'ravi@okaxis', 'upi_name': null, 'donations_enabled': true, 'moderation_note': null};
      final d = SevaDrive.fromJson(json);
      expect(d.stage, 0);
      expect(d.donations.open, isFalse);
      expect(d.donations.upiId, isNull);
      expect(d.myUpiId, 'ravi@okaxis');
      expect(d.canEdit, isTrue);
    });

    test('an unknown cause falls back rather than failing', () {
      expect(SevaCause.of('something-new').value, 'other');
    });
  });

  group('SevaUpload', () {
    test('sends photos as an array Laravel reads, and the link as a field', () {
      const u = SevaUpload(photos: ['/a.jpg', '/b.jpg'], videoUrl: 'https://youtu.be/x');
      expect(u.files, {'photos[0]': '/a.jpg', 'photos[1]': '/b.jpg'});
      expect(u.fields, {'video_url': 'https://youtu.be/x'});
      expect(const SevaUpload().isEmpty, isTrue);
    });
  });

  testWidgets('a verified drive card shows before and after and the donation goal', (tester) async {
    await tester.pumpWidget(
      Provider<ApiClient>.value(
        value: ApiClient(baseUrl: 'http://localhost'),
        child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: SevaDriveCard(drive: SevaDrive.fromJson(verifiedDrive()), onTap: () {}))),
        ),
      ),
    );
    expect(find.text('Clean the stepwell at Hampi'), findsOneWidget);
    expect(find.text('BEFORE'), findsOneWidget);
    expect(find.text('AFTER'), findsOneWidget);
    expect(find.text('Accepting donations'), findsOneWidget);
    expect(find.textContaining('₹700'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  Future<void> pumpAtPhoneWidth(WidgetTester tester, Widget screen, Map<String, dynamic> drive) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // A listing answers with a page of drives; anything else with the one.
    final api = ApiClient(
      baseUrl: 'http://localhost',
      client: MockClient((req) async => http.Response(
            jsonEncode(req.url.path.endsWith('/seva-drives')
                ? {'data': [drive], 'meta': {'current_page': 1, 'last_page': 1, 'total': 1}}
                : {'data': drive}),
            200,
          )),
    );
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider(create: (_) => AuthController(prefs, api)),
        ],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  }

  testWidgets('the drive page lays out at phone width with the UPI card', (tester) async {
    await pumpAtPhoneWidth(tester, const SevaDriveScreen(driveId: 1), verifiedDrive());
    expect(find.text('Clean the stepwell at Hampi'), findsOneWidget);
    expect(find.text('Donate by UPI'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('ravi@okaxis'), 300, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the organiser sees their tools on a live drive', (tester) async {
    final json = verifiedDrive()
      ..['status'] = {'value': 'approved', 'label': 'Open for volunteers'}
      ..['donations'] = {'open': false, 'goal': 5000}
      ..['viewer'] = {'is_organiser': true, 'has_joined': false, 'can_join': false, 'can_edit': true, 'can_complete': true}
      ..['mine'] = {'upi_id': 'ravi@okaxis', 'moderation_note': null};
    await pumpAtPhoneWidth(tester, const SevaDriveScreen(driveId: 1), json);
    await tester.scrollUntilVisible(find.text('Mark as done'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Add after photos'), findsOneWidget);
    expect(find.text('Join hands'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a volunteer sees Join hands on an open drive', (tester) async {
    final json = verifiedDrive()
      ..['status'] = {'value': 'approved', 'label': 'Open for volunteers'}
      ..['donations'] = {'open': false}
      ..['viewer'] = {'is_organiser': false, 'has_joined': false, 'can_join': true};
    await pumpAtPhoneWidth(tester, const SevaDriveScreen(driveId: 1), json);
    expect(find.text('Join hands'), findsOneWidget);
    expect(find.text('ravi@okaxis'), findsNothing);
  });

  testWidgets('the raise form lays out at phone width', (tester) async {
    await pumpAtPhoneWidth(tester, const RaiseDriveScreen(templeSlug: 'hampi', templeName: 'Virupaksha Temple'), verifiedDrive());
    expect(find.text('The place'), findsOneWidget);
    expect(find.text('Send for review'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the seva hub lists drives at phone width', (tester) async {
    final json = verifiedDrive()
      ..['status'] = {'value': 'approved', 'label': 'Open for volunteers'}
      ..['donations'] = {'open': false};
    await pumpAtPhoneWidth(tester, const SevaScreen(), json);
    expect(find.text('Seva Drives'), findsOneWidget);
    expect(find.text('How a seva drive works'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Clean the stepwell at Hampi'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.textContaining('3 of 10 coming'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('Dates', () {
    test('one day with an end time reads as one day with hours', () {
      final d = SevaDrive.fromJson(verifiedDrive()
        ..['starts_at'] = '2026-10-10T07:00:00'
        ..['ends_at'] = '2026-10-10T11:00:00');
      expect(d.dayCount, 1);
      expect(sevaDateRange(d), 'Sat, 10 Oct · 7:00 AM – 11:00 AM');
    });

    test('several days reads as a span with the count', () {
      final d = SevaDrive.fromJson(verifiedDrive()
        ..['starts_at'] = '2026-10-10T07:00:00'
        ..['ends_at'] = '2026-10-12T17:00:00'
        ..['is_multi_day'] = true);
      expect(d.dayCount, 3);
      expect(sevaDateRange(d), 'Sat 10 Oct → Mon 12 Oct · 3 days');
    });
  });

  testWidgets('everyone sees the organiser, dates and how many are coming and raised', (tester) async {
    await pumpAtPhoneWidth(tester, const SevaDriveScreen(driveId: 1), verifiedDrive());
    expect(find.text('ORGANISER'), findsOneWidget);
    expect(find.text('Ravi Kumar'), findsWidgets);
    expect(find.text('ONE DAY'), findsOneWidget);
    expect(find.text('of 10 coming'), findsOneWidget);
    expect(find.text('₹700'), findsOneWidget);
    expect(find.text('from 2 donors'), findsOneWidget);
  });

  testWidgets('a misleading drive carries the warning and no Join or Donate', (tester) async {
    final json = verifiedDrive()
      ..['status'] = {'value': 'approved', 'label': 'Open for volunteers'}
      ..['is_misleading'] = true
      ..['misleading_note'] = 'The after photographs are of another temple.'
      ..['donations'] = {'open': false, 'raised': 0}
      ..['viewer'] = {'can_join': false};
    await pumpAtPhoneWidth(tester, const SevaDriveScreen(driveId: 1), json);
    expect(find.text('Flagged as misleading by the team'), findsOneWidget);
    expect(find.text('The after photographs are of another temple.'), findsOneWidget);
    expect(find.text('Donate by UPI'), findsNothing);
  });

  testWidgets('anyone can open the report sheet from the menu', (tester) async {
    await pumpAtPhoneWidth(tester, const SevaDriveScreen(driveId: 1), verifiedDrive());
    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report this drive'));
    await tester.pumpAndSettle();
    expect(find.text('Misleading — not what it claims'), findsOneWidget);
    expect(find.text('Send report'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the organiser sees who is coming on the page', (tester) async {
    final json = verifiedDrive()
      ..['status'] = {'value': 'approved', 'label': 'Open for volunteers'}
      ..['donations'] = {'open': false}
      ..['viewer'] = {'is_organiser': true, 'can_edit': true}
      ..['mine'] = {'upi_id': null};
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(
      baseUrl: 'http://localhost',
      client: MockClient((req) async => http.Response(
            jsonEncode(req.url.path.endsWith('/volunteers')
                ? {'data': [{'id': 1, 'name': 'Lakshmi', 'party_size': 3, 'note': 'Bringing sacks'}]}
                : {'data': json}),
            200,
          )),
    );
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [Provider<ApiClient>.value(value: api), ChangeNotifierProvider(create: (_) => AuthController(prefs, api))],
      child: const MaterialApp(home: SevaDriveScreen(driveId: 1)),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(find.text('Lakshmi'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text("Who's coming"), findsOneWidget);
    expect(find.text('Bringing sacks'), findsOneWidget);
    expect(find.text('+2 with them'), findsOneWidget);
    expect(find.text('More'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a PIN code fills in the district, state and town', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(
      baseUrl: 'http://localhost',
      client: MockClient((req) async => req.url.path.endsWith('/pincode/508101')
          ? http.Response(jsonEncode({'data': {'pincode': '508101', 'state': 'Telangana', 'state_id': 36, 'district': 'Yadadri Bhuvanagiri', 'places': [{'name': 'Kolanupaka'}, {'name': 'Alair'}]}}), 200)
          : http.Response('{}', 404)),
    );
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [Provider<ApiClient>.value(value: api), ChangeNotifierProvider(create: (_) => AuthController(prefs, api))],
      child: const MaterialApp(home: RaiseDriveScreen()),
    ));
    await tester.enterText(find.widgetWithText(TextField, 'PIN code'), '508101');
    await tester.pumpAndSettle();
    expect(find.text('Telangana'), findsOneWidget);
    expect(find.text('Yadadri Bhuvanagiri'), findsWidgets);
    expect(find.text('Which village or town?'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Kolanupaka'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Kolanupaka'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a drive card says how far away it is once location is known', (tester) async {
    SharedPreferences.setMockInitialValues({'loc_lat': 15.35, 'loc_lng': 76.46});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: ApiClient(baseUrl: 'http://localhost')),
        ChangeNotifierProvider(create: (_) => LocationController(prefs)),
      ],
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SevaDriveCard(drive: SevaDrive.fromJson(verifiedDrive()), onTap: () {})))),
    ));
    expect(find.text('2.2 km away'), findsOneWidget);
  });
}
