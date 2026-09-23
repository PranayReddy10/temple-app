import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/models/models.dart';

void main() {
  _playbackTests();
  group('Fee contract', () {
    test('an unpriced puja is not free', () {
      final fee = Fee.fromJson({'is_free': false, 'amount': null, 'label': 'No published price'});
      expect(fee.isFree, isFalse);
      expect(fee.display, 'No published price');
    });

    test('only is_free means free', () {
      expect(Fee.fromJson({'is_free': true, 'label': 'Free'}).display, 'Free');
      expect(Fee.fromJson({'is_free': false, 'amount': 500, 'currency': 'INR'}).display, 'INR 500');
    });
  });

  group('Booking contract', () {
    test('only is_official may be presented as official', () {
      final b = Booking.fromJson({'url': 'https://reseller.example', 'is_official': false, 'label': 'Third-party link'});
      expect(b.isOfficial, isFalse);
      expect(b.url, isNotNull);
    });
  });

  group('Trust', () {
    test('parses every level and defaults to unverified', () {
      expect(TrustLevel.parse('official'), TrustLevel.official);
      expect(TrustLevel.parse('community'), TrustLevel.community);
      expect(TrustLevel.parse('garbage'), TrustLevel.unverified);
      expect(TrustLevel.parse(null), TrustLevel.unverified);
    });
  });

  group('TempleDetail', () {
    test('parses the v1 detail shape tolerantly', () {
      final d = TempleDetail.fromJson({
        'id': 1,
        'slug': 'kashi-vishwanath-temple',
        'name': 'Kashi Vishwanath Temple',
        'deity': {'slug': 'shiva', 'name': 'Shiva'},
        'categories': [
          {'slug': 'jyotirlinga', 'name': 'Jyotirlinga', 'kind': 'circuit'},
        ],
        'location': {'city': 'Varanasi', 'state': 'Uttar Pradesh', 'latitude': '25.3109', 'longitude': 83.0107},
        'about': {'short_description': 'Jyotirlinga shrine.'},
        'visitor_rules': {'dress_code': 'Traditional', 'photography': null},
        'trust': {'level': 'verified', 'label': 'Verified', 'is_stale': false},
        'timings': [
          {'kind': 'aarti', 'label': 'Mangala aarti', 'opens_at': '03:00', 'closes_at': '04:00', 'window': '03:00 – 04:00'},
        ],
        'pujas': [],
        'photos': [
          {'id': 9, 'is_primary': true, 'urls': {'medium': 'https://x/m.jpg'}},
        ],
        'is_closed_today': false,
      });
      expect(d.summary.slug, 'kashi-vishwanath-temple');
      expect(d.summary.deity?.slug, 'shiva');
      expect(d.summary.location.latitude, closeTo(25.3109, 0.0001));
      expect(d.summary.categorySlugs, ['jyotirlinga']);
      expect(d.visitorRules, {'dress_code': 'Traditional'});
      expect(d.timings.single.window, '03:00 – 04:00');
      expect(d.summary.primaryPhoto?.best, 'https://x/m.jpg');
      expect(d.summary.trust.level, TrustLevel.verified);
    });

    test('missing sections do not throw', () {
      final d = TempleDetail.fromJson({'slug': 'x', 'name': 'X'});
      expect(d.timings, isEmpty);
      expect(d.summary.location.hasCoordinates, isFalse);
      expect(d.summary.trust.level, TrustLevel.unverified);
    });
  });

  test('DevotionalDay parses nested deity, media and temples', () {
    final day = DevotionalDay.fromJson({
      'weekday': 1,
      'weekday_name': 'Monday',
      'title': 'Somavara — Shiva',
      'mantra': 'ॐ नमः शिवाय',
      'accent_color': '#6B7FA8',
      'deity': {'slug': 'shiva', 'name': 'Shiva'},
      'media': [
        {'type': 'song', 'title': 'Shiva Tandava', 'artist': 'A', 'license': 'CC BY'},
      ],
      'temples': [
        {'slug': 'somnath-temple', 'name': 'Somnath', 'location': {}, 'trust': {'level': 'community'}},
      ],
    });
    expect(day.weekday, 1);
    expect(day.deity?.slug, 'shiva');
    expect(day.media.single.license, 'CC BY');
    expect(day.temples.single.slug, 'somnath-temple');
  });
}

void _playbackTests() {
  test('playback comes from the server when sent, and is guessed otherwise', () {
    final served = DevotionalMedia.fromJson({'type': 'song', 'title': 'x', 'url': 'https://youtu.be/dQw4w9WgXcQ', 'playback': {'kind': 'youtube', 'is_playable': false, 'needs_embed': true, 'embed_url': 'https://www.youtube.com/embed/dQw4w9WgXcQ', 'youtube_id': 'dQw4w9WgXcQ'}});
    expect(served.playback.youtubeId, 'dQw4w9WgXcQ');
    expect(served.posterUrl, contains('img.youtube.com/vi/dQw4w9WgXcQ'));

    final guessedYt = DevotionalMedia.fromJson({'title': 'x', 'url': 'https://www.youtube.com/watch?v=abc123def45&t=10'});
    expect(guessedYt.playback.kind, 'youtube');
    expect(guessedYt.playback.youtubeId, 'abc123def45');
    final search = DevotionalMedia.fromJson({'title': 'x', 'url': 'https://www.youtube.com/results?search_query=om'});
    expect(search.playback.kind, 'youtube');
    expect(search.playback.embedUrl, isNull, reason: 'a search page has no video to embed');
    final mp3 = DevotionalMedia.fromJson({'title': 'x', 'url': 'https://cdn.example/chant.mp3?sig=1'});
    expect(mp3.playback.kind, 'audio');
    expect(mp3.playback.isPlayable, isTrue);
  });

  test('a mantra carries its recording and falls back field by field', () {
    final m = Mantra.fromJson({'text': 'ॐ नमः शिवाय', 'transliteration': 'Om Namah Shivaya', 'meaning': 'Salutations to Shiva.', 'is_own': false, 'audio': {'type': 'chant', 'title': 'Chant', 'url': 'https://cdn.example/om.mp3', 'playback': {'kind': 'audio', 'is_playable': true}}});
    expect(m.isOwn, isFalse);
    expect(m.meaning, 'Salutations to Shiva.');
    expect(m.audio!.playback.kind, 'audio');
    final day = DevotionalDay.fromJson({'weekday': 1, 'title': 't', 'mantra_audio': {'text': 'x', 'is_own': true, 'audio': null}});
    expect(day.mantraAudio!.isOwn, isTrue);
    expect(day.mantraAudio!.audio, isNull);
  });

  test('the cover leads the gallery even when not among the published rows', () {
    final d = TempleDetail.fromJson({'slug': 'x', 'name': 'X', 'location': {}, 'trust': {}, 'photos': [{'id': 2, 'urls': {'medium': 'https://x/2.jpg'}}], 'primary_photo': {'id': 9, 'is_primary': true, 'urls': {'medium': 'https://x/cover.jpg'}}});
    expect(d.summary.primaryPhoto!.best, 'https://x/cover.jpg');
    expect(d.photos.first.id, 9);
    expect(d.photos, hasLength(2));
  });
}
