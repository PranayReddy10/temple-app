import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:temple_app/core/audio/audio_queue.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/features/temple/temple_screen.dart';

import 'booking_test.dart' show templeHarness, templeJson;

/// Stands in for the real player, which needs a device to make sound.
class _Songs extends AudioQueueController {
  List<DevotionalMedia> played = const [];
  DevotionalMedia? _current;
  bool _on = false;
  int stops = 0;

  @override
  DevotionalMedia? get current => _current;
  @override
  bool get isPlaying => _on;

  @override
  Future<void> playQueue(List<DevotionalMedia> items, {DevotionalMedia? start}) async {
    played = items;
    _current = items.first;
    _on = true;
    notifyListeners();
  }

  @override
  Future<void> toggle() async {
    _on = !_on;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    stops++;
    _current = null;
    _on = false;
    notifyListeners();
  }
}

Map<String, dynamic> _song(String title, String url, {String type = 'song', String? belongsTo, String kind = 'audio'}) => {
      'type': type,
      'title': title,
      'url': url,
      'source_type': 'external',
      if (belongsTo != null) 'belongs_to': belongsTo,
      'playback': {'kind': kind, 'is_playable': kind == 'audio', 'needs_embed': kind == 'youtube'},
    };

http.Response _json(Object body) => http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json; charset=utf-8'});

http.Client _api(List<Map<String, dynamic>> media) => MockClient((r) async {
      if (r.url.path == '/api/v1/temples/booking-temple') {
        return _json({'data': {...templeJson(), 'devotional_media': media}});
      }
      return _json({'data': []});
    });

final _media = [
  _song('Om Namah Shivaya', 'https://cdn.test/deity.mp3', belongsTo: 'deity'),
  _song('Someshwara Suprabhatam', 'https://cdn.test/temple.mp3', belongsTo: 'temple'),
  _song('On YouTube', 'https://www.youtube.com/watch?v=x', belongsTo: 'temple', kind: 'youtube'),
];

/// A page that opens the temple, so going back can be tested.
Widget _opener() => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TempleScreen(slug: 'booking-temple'))),
            child: const Text('Open temple'),
          ),
        ),
      ),
    );

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Open temple'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  test('a temple plays its own songs, else its deity\'s, and never a YouTube page', () {
    final all = _media.map(DevotionalMedia.fromJson).toList();
    expect(AudioQueue.templeSongs(all).map((m) => m.title), ['Someshwara Suprabhatam']);

    final deityOnly = all.where((m) => m.belongsTo == 'deity').toList();
    expect(AudioQueue.templeSongs(deityOnly).map((m) => m.title), ['Om Namah Shivaya']);

    // An older server sends no owner: the first playable song, as listed.
    final unmarked = [_song('First', 'https://cdn.test/a.mp3'), _song('Second', 'https://cdn.test/b.mp3')].map(DevotionalMedia.fromJson).toList();
    expect(AudioQueue.templeSongs(unmarked).first.title, 'First');

    final video = DevotionalMedia.fromJson({..._song('A video', 'https://cdn.test/v.mp4', kind: 'video'), 'type': 'video'});
    expect(AudioQueue.templeSongs([video]), isEmpty);
  });

  testWidgets('opening a temple plays its song; Stop stops it; going back stops it', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final songs = _Songs();
    await tester.pumpWidget(await templeHarness(_api(_media), songs: songs, home: _opener()));
    await _open(tester);

    expect(songs.played.map((m) => m.title), ['Someshwara Suprabhatam']);
    expect(find.text('Someshwara Suprabhatam'), findsWidgets);
    expect(find.byKey(const ValueKey('temple-song-bar')), findsOneWidget);

    // Pause and play again from the bar.
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(songs.isPlaying, isFalse);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump();
    expect(songs.isPlaying, isTrue);

    // Stop by hand: the bar goes.
    await tester.tap(find.byKey(const ValueKey('temple-song-stop')));
    await tester.pump();
    expect(songs.stops, 1);
    expect(find.byKey(const ValueKey('temple-song-bar')), findsNothing);

    // Played again from the list, then the devotee goes back: it stops.
    await songs.playQueue(AudioQueue.templeSongs(_media.map(DevotionalMedia.fromJson).toList()));
    await tester.pump();
    final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(songs.stops, 2);
    expect(songs.current, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no song plays when the devotee has turned it off', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final songs = _Songs();
    await tester.pumpWidget(await templeHarness(_api(_media), songs: songs, home: _opener(), prefs: {'temple_song_autoplay': false}));
    await _open(tester);

    expect(songs.played, isEmpty);
    expect(find.byKey(const ValueKey('temple-song-bar')), findsNothing);
  });

  testWidgets('a song the devotee is already listening to is not cut short', (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final songs = _Songs();
    final mine = DevotionalMedia.fromJson(_song('My bhajan', 'https://cdn.test/mine.mp3'));
    await songs.playQueue([mine]);
    await tester.pumpWidget(await templeHarness(_api(_media), songs: songs, home: _opener()));
    await _open(tester);

    expect(songs.current?.title, 'My bhajan');
    // Leaving the temple does not stop what was not the temple's.
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(songs.current?.title, 'My bhajan');
  });
}
