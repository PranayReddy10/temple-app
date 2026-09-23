import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/data/sample_data.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/state/family_controller.dart';
import 'package:temple_app/core/state/passport_controller.dart';
import 'package:temple_app/core/state/reminders_controller.dart';
import 'package:temple_app/core/state/yatra_controller.dart';
import 'package:temple_app/features/guide/guide_engine.dart';
import 'package:temple_app/features/qr/qr_screens.dart';

YatraStop _stop(String slug) {
  final t = SampleData.bySlug(slug)!;
  return YatraStop(slug: slug, name: t.name, city: t.location.city, deitySlug: t.deity?.slug, lat: t.location.latitude, lng: t.location.longitude);
}

TempleRepository offlineRepo() => TempleRepository(ApiClient(baseUrl: 'http://localhost:1', client: MockClient((_) async => throw http.ClientException('offline'))));

void main() {
  group('YatraPlanner', () {
    test('optimise shortens a scrambled route', () {
      final scrambled = ['kedarnath-temple', 'ramanathaswamy-temple-rameswaram', 'badrinath-temple', 'meenakshi-amman-temple', 'kashi-vishwanath-temple', 'brihadeeswarar-temple-thanjavur'].map(_stop).toList();
      final before = YatraPlanner.pathKm(scrambled);
      final after = YatraPlanner.pathKm(YatraPlanner.optimise(scrambled));
      expect(after, lessThan(before * 0.6));
      expect(YatraPlanner.optimise(scrambled).map((s) => s.slug).toSet(), scrambled.map((s) => s.slug).toSet(), reason: 'no stop is lost');
    });

    test('stops without coordinates stay at the end', () {
      final stops = [_stop('somnath-temple'), const YatraStop(slug: 'x', name: 'Unknown'), _stop('dwarkadhish-temple'), _stop('kailasa-temple-ellora')];
      final out = YatraPlanner.optimise(stops);
      expect(out.last.slug, 'x');
    });

    test('splitIntoDays honours stop and distance limits', () {
      final ordered = YatraPlanner.optimise(['meenakshi-amman-temple', 'ramanathaswamy-temple-rameswaram', 'brihadeeswarar-temple-thanjavur', 'sabarimala-sree-dharmasastha-temple', 'guruvayur-sri-krishna-temple'].map(_stop).toList());
      final days = YatraPlanner.splitIntoDays(ordered, maxKmPerDay: 200, maxStopsPerDay: 2);
      expect(days.every((d) => d.length <= 2), isTrue);
      expect(days.every((d) => YatraPlanner.pathKm(d) <= 200), isTrue);
      expect(days.expand((d) => d).length, 5);
    });

    test('controller autoPlan rewrites the days', () async {
      SharedPreferences.setMockInitialValues({});
      final ctl = YatraController(await SharedPreferences.getInstance());
      final y = await ctl.create('South');
      for (final s in ['meenakshi-amman-temple', 'ramanathaswamy-temple-rameswaram', 'brihadeeswarar-temple-thanjavur', 'guruvayur-sri-krishna-temple']) {
        await ctl.addStop(y, 0, _stop(s));
      }
      await ctl.autoPlan(y, maxStopsPerDay: 2, maxKmPerDay: 500);
      expect(y.days.length, 2);
      expect(y.stopCount, 4);
      expect(y.distanceKm, greaterThan(0));
    });
  });

  group('GuideEngine', () {
    test('today names the weekday deity', () async {
      final r = await GuideEngine(offlineRepo()).ask('What is today?');
      expect(r.day, isNotNull);
      expect(r.text, contains(r.day!.deityName));
    });

    test('timings for a temple come from the record', () async {
      final r = await GuideEngine(offlineRepo()).ask('timings at Kashi Vishwanath');
      expect(r.text, contains('Kashi Vishwanath'));
      expect(r.text, contains('05:00'));
      expect(r.text, contains('community record'));
    });

    test('an alias finds the temple and pujas are never called free', () async {
      final r = await GuideEngine(offlineRepo()).ask('pujas at Tirupati');
      expect(r.temples.single.slug, 'sri-venkateswara-swamy-temple-tirumala');
      expect(r.text, contains('No published price'));
      expect(r.text.toLowerCase(), isNot(contains('is free')));
    });

    test('nearby needs a location, then answers with distances', () async {
      final g = GuideEngine(offlineRepo());
      expect((await g.ask('temples near me')).text, contains('Locate'));
      g
        ..lat = 17.385
        ..lng = 78.4867;
      final r = await g.ask('shiva temples near me');
      expect(r.temples, isNotEmpty);
      expect(r.temples.every((t) => t.deity?.slug == 'shiva'), isTrue);
      expect(r.text, contains('km'));
    });

    test('says so when nothing matches', () async {
      final r = await GuideEngine(offlineRepo()).ask('zzqx plorf');
      expect(r.text, contains('nothing matched'));
      expect(r.temples, isEmpty);
    });
  });

  group('TempleQr', () {
    test('accepts the three code forms and rejects others', () {
      expect(TempleQr.parse('templepassport://checkin/somnath-temple')?.slug, 'somnath-temple');
      expect(TempleQr.parse('https://example.com/temples/somnath-temple')?.slug, 'somnath-temple');
      expect(TempleQr.parse('somnath-temple')?.slug, 'somnath-temple');
      expect(TempleQr.parse('https://evil.example/pay?x=1'), isNull);
      expect(TempleQr.parse('Not A Slug!'), isNull);
    });
  });

  group('Passport verification and family', () {
    test('visits record how they were verified and who came', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final family = FamilyController(prefs);
      final amma = await family.add('Lakshmi', 'Mother');
      final passport = PassportController(prefs);
      await passport.checkIn(SampleData.temples.first, verification: Verification.gps, members: [amma.id]);
      await passport.checkIn(SampleData.temples[1]);
      expect(passport.verifiedCount, 1);
      expect(passport.stampsFor(amma.id).single.templeSlug, SampleData.temples.first.slug);
      expect(passport.earned.map((a) => a.slug), containsAll(['pramana', 'kutumba']));
      // Round-trips through storage.
      final again = PassportController(prefs);
      expect(again.visits.last.verification, Verification.gps);
      expect(again.visits.last.members, [amma.id]);
    });
  });

  test('reminder calendar link carries the dates', () {
    const e = TempleEvent(title: 'Brahmotsavam', startsOn: '2026-10-01', endsOn: '2026-10-09', templeName: 'Tirumala');
    final uri = RemindersController.calendarLink(e);
    expect(uri.host, 'calendar.google.com');
    expect(uri.queryParameters['dates'], '20261001/20261010');
    expect(uri.queryParameters['text'], contains('Brahmotsavam'));
  });
}
