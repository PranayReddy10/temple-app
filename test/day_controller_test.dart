import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/api/temple_repository.dart';
import 'package:temple_app/core/data/sample_media.dart';
import 'package:temple_app/core/state/day_controller.dart';
import 'package:temple_app/core/theme/day_theme.dart';

void main() {
  TempleRepository offlineRepo() => TempleRepository(ApiClient(baseUrl: 'http://localhost:1', client: MockClient((_) async => throw http.ClientException('offline'))));

  test('previews stack and Home keeps today', () async {
    final c = DayController(offlineRepo());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final today = c.todayTheme;
    c.preview(DayTheme.all[3]); // Wednesday page
    expect(c.theme.deitySlug, 'krishna');
    expect(c.todayTheme.weekday, today.weekday);
    c.preview(DayTheme.forDeity('shiva')); // a Shiva temple opened from it
    expect(c.theme.deitySlug, 'shiva');
    c.endPreview();
    expect(c.theme.deitySlug, 'krishna', reason: 'popping the temple returns to Wednesday, not today');
    c.endPreview();
    expect(c.theme.weekday, today.weekday);
    c.endPreview(); // extra pops are harmless
    expect(c.theme.weekday, today.weekday);
  });

  test('today media comes from the bundled catalogue offline', () async {
    final c = DayController(offlineRepo());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.todayMedia, isNotEmpty);
    expect(c.todayMedia.every((m) => m.license != null && m.url != null), isTrue, reason: 'rights travel with every item');
  });

  test('every weekday deity has chants, songs and videos', () {
    for (final d in DayTheme.all) {
      final m = SampleMedia.forDeity(d.deitySlug);
      expect(m.where((x) => x.type == 'chant'), isNotEmpty, reason: d.deitySlug);
      expect(m.where((x) => x.type == 'song'), isNotEmpty, reason: d.deitySlug);
      expect(m.where((x) => x.type == 'video'), isNotEmpty, reason: d.deitySlug);
    }
  });

  test('temple media puts the temple\'s own videos first', () {
    final m = SampleMedia.forTemple('Mahakaleshwar Temple, Ujjain', 'shiva');
    expect(m.first.title, contains('Mahakaleshwar'));
    final r = offlineRepo();
    expect(SampleMedia.galleryFor('konark-sun-temple'), hasLength(2));
    expect(r, isNotNull);
  });
}
