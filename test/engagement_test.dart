import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/audio/audio_queue.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/engagement_controller.dart';
import 'package:temple_app/features/notifications/follows_screen.dart';

import 'booking_test.dart' show templeHarness, templeJson;

Map<String, dynamic> engagementJson({int likes = 3, int follows = 2, bool liked = false, bool following = false}) => {
      'likes_count': likes,
      'follows_count': follows,
      'viewer': {'liked': liked, 'following': following, 'notify_festivals': following, 'notify_events': false, 'saved': false},
      'reviews': {
        'count': 2,
        'dimensions': {
          'queue_rating': {'label': 'Queue and waiting', 'average': 2.5, 'count': 2},
          'cleanliness_rating': {'label': 'Cleanliness', 'average': null, 'count': 0},
        },
        'average_wait_minutes': 40,
      },
    };

http.Response _json(Object body, [int status = 200]) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

const _summary = TempleSummary(id: 1, slug: 'booking-temple', name: 'Sri Someshwara Swamy Temple', location: Location(city: 'Kolanupaka'), trust: Trust(level: TrustLevel.verified));

void main() {
  group('Engagement models', () {
    test('the temple page block parses, and an old server means none of it', () {
      final e = Engagement.fromJson(engagementJson(liked: true));
      expect(e.likesCount, 3);
      expect(e.viewer!.liked, isTrue);
      expect(e.reviews.count, 2);
      expect(e.reviews.dimensions.first.average, 2.5);
      expect(e.reviews.dimensions[1].average, isNull);
      expect(e.reviews.averageWaitMinutes, 40);

      final old = TempleDetail.fromJson({'id': 1, 'slug': 's', 'name': 'T'});
      expect(old.engagement.likesCount, 0);
      expect(old.engagement.viewer, isNull);
    });

    test('a review carries its ratings, the reply, and status only for its author', () {
      final r = Review.fromJson({
        'id': 5, 'devotee': {'name': 'Anuradha R.'}, 'visited_on': '2026-09-20',
        'ratings': [{'key': 'queue_rating', 'label': 'Queue and waiting', 'value': 2}, {'key': 'accuracy_rating', 'label': 'Our listing was accurate', 'value': null}],
        'wait_minutes': 90, 'body': 'Long queue.', 'temple_reply': 'Come early.', 'is_mine': true, 'status': {'value': 'pending', 'label': 'Waiting for review'},
      });
      expect(r.devoteeName, 'Anuradha R.');
      expect(r.ratings.where((x) => x.value != null), hasLength(1));
      expect(r.isPending, isTrue);
      expect(r.templeReply, 'Come early.');
      expect(Review.fromJson({'id': 6, 'devotee': {'name': 'Sita'}}).status, isNull);
    });

    test('a devotee photo in the gallery says whose it is', () {
      final p = Photo.fromJson({'id': 1, 'urls': {'medium': 'u'}, 'is_devotee_photo': true, 'devotee': {'name': 'Lakshmi I.'}, 'credit': 'Lakshmi Iyer'});
      expect(p.isDevoteePhoto, isTrue);
      expect(p.devoteeName, 'Lakshmi I.');
      expect(Photo.fromJson({'id': 2, 'urls': {}}).isDevoteePhoto, isFalse);
    });
  });

  group('Engagement controller', () {
    test('a tap counts at once, is remembered, and the server\'s answer replaces the guess', () async {
      SharedPreferences.setMockInitialValues({'devotee_token': 't', 'devotee': jsonEncode({'id': 1, 'name': 'Anu'})});
      final prefs = await SharedPreferences.getInstance();
      final calls = <String>[];
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        if (r.url.path.endsWith('/me/likes/booking-temple')) return _json({'data': engagementJson(likes: r.method == 'PUT' ? 4 : 3, liked: r.method == 'PUT')}, r.method == 'PUT' ? 201 : 200);
        if (r.url.path.endsWith('/me/follows/booking-temple')) return _json({'data': engagementJson(follows: r.method == 'PUT' ? 3 : 2, following: r.method == 'PUT')}, r.method == 'PUT' ? 201 : 200);
        return _json({'data': []});
      }));
      final auth = AuthController(prefs, api);
      final ctl = EngagementController(prefs, auth, api: api);
      int? followedId;
      bool? followedNow;
      ctl.onFollowChanged = (id, f) {
        followedId = id;
        followedNow = f;
      };

      ctl.adopt('booking-temple', Engagement.fromJson(engagementJson()));
      expect(ctl.stateFor('booking-temple', Engagement.none).likesCount, 3);

      await ctl.toggleLike(_summary);
      expect(ctl.isLiked('booking-temple'), isTrue);
      expect(ctl.stateFor('booking-temple', Engagement.none).likesCount, 4);
      expect(calls, contains('PUT /api/v1/me/likes/booking-temple'));

      await ctl.toggleFollow(_summary);
      expect(ctl.isFollowing('booking-temple'), isTrue);
      expect(followedId, 1);
      expect(followedNow, isTrue);
      expect(ctl.stateFor('booking-temple', Engagement.none).followsCount, 3);
      expect(ctl.follows.single.notifyFestivals, isTrue);

      // Survives a restart.
      final again = EngagementController(prefs, auth, api: api);
      expect(again.isLiked('booking-temple'), isTrue);
      expect(again.isFollowing('booking-temple'), isTrue);

      await ctl.setReminders('booking-temple', events: false);
      expect(ctl.followOf('booking-temple')!.notifyEvents, isFalse);
      expect(ctl.followOf('booking-temple')!.notifyFestivals, isTrue);

      await ctl.toggleFollow(_summary);
      expect(ctl.isFollowing('booking-temple'), isFalse);
      expect(followedNow, isFalse);
      expect(calls, contains('DELETE /api/v1/me/follows/booking-temple'));
    });

    test('refresh pushes taps made offline and adopts the account\'s', () async {
      SharedPreferences.setMockInitialValues({'devotee_token': 't', 'devotee': jsonEncode({'id': 1, 'name': 'Anu'}), 'liked_temples': ['offline-liked']});
      final prefs = await SharedPreferences.getInstance();
      final calls = <String>[];
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async {
        calls.add('${r.method} ${r.url.path}');
        if (r.url.path.endsWith('/me/follows') && r.method == 'GET') {
          return _json({'data': [{'temple': {'slug': 'remote-followed', 'name': 'Remote', 'location': {}, 'trust': {}}, 'notify_festivals': false, 'notify_events': true}]});
        }
        if (r.url.path.endsWith('/me/likes') && r.method == 'GET') return _json({'data': [{'slug': 'remote-liked', 'name': 'R', 'location': {}, 'trust': {}}]});
        return _json({'data': engagementJson()}, 201);
      }));
      final ctl = EngagementController(prefs, AuthController(prefs, api), api: api);

      await ctl.refresh();
      expect(calls, contains('PUT /api/v1/me/likes/offline-liked'));
      expect(ctl.isLiked('remote-liked'), isTrue);
      expect(ctl.isLiked('offline-liked'), isTrue);
      expect(ctl.followOf('remote-followed')!.notifyEvents, isTrue);
      expect(ctl.followOf('remote-followed')!.notifyFestivals, isFalse);
    });

    test('signed out, nothing is sent and the tap still shows', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => throw StateError('must not be called')));
      final ctl = EngagementController(prefs, AuthController(prefs, api), api: api);
      await ctl.toggleLike(_summary);
      expect(ctl.isLiked('booking-temple'), isTrue);
      await ctl.refresh();
    });
  });

  group('Audio queue', () {
    const song1 = DevotionalMedia(type: 'song', title: 'Suprabhatam', url: 'https://cdn.example/suprabhatam.mp3', sourceType: 'upload');
    const song2 = DevotionalMedia(type: 'song', title: 'Aarti', url: 'https://cdn.example/aarti.m4a', sourceType: 'upload');
    const chant = DevotionalMedia(type: 'chant', title: 'Om', url: 'https://cdn.example/om.mp3', sourceType: 'upload');
    const video = DevotionalMedia(type: 'video', title: 'Live', url: 'https://youtu.be/abcdefgh123');
    const search = DevotionalMedia(type: 'song', title: 'Search', url: 'https://www.youtube.com/results?search_query=x', sourceType: 'external');

    test('only recordings go in; next wraps; up next is everything after', () {
      final q = AudioQueue.of([video, song1, search, song2, chant], start: song2);
      expect(q.items, [song1, song2, chant]);
      expect(q.current, song2);
      expect(q.upNext, [chant, song1]);
      expect(q.next().current, chant);
      expect(q.next().next().current, song1, reason: 'wraps to the start');
      expect(q.previous().current, song1);
      expect(q.at(9).current, chant, reason: 'clamped');
      expect(AudioQueue.of([video, search]).isEmpty, isTrue);
      expect(AudioQueue.isPlayable(song1), isTrue);
      expect(AudioQueue.isPlayable(video), isFalse);
    });

    test('the controller costs nothing until something plays', () {
      final ctl = AudioQueueController();
      expect(ctl.hasQueue, isFalse);
      expect(ctl.current, isNull);
      expect(ctl.isPlaying, isFalse);
      ctl.dispose();
    });
  });

  testWidgets('the temple page shows likes and follows, and how visits went', (tester) async {
    final client = MockClient((r) async {
      if (r.url.path == '/api/v1/temples/booking-temple') return _json({'data': {...templeJson(), 'engagement': engagementJson()}});
      if (r.url.path.endsWith('/me/likes/booking-temple')) return _json({'data': engagementJson(likes: 4, liked: true)}, 201);
      return _json({'data': []});
    });
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(await templeHarness(client));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // The heart with its count (in the hero and under the address), and the bell.
    expect(find.text('3'), findsNWidgets(2));
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.notifications_none_rounded), findsWidgets);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byIcon(Icons.favorite_rounded), findsWidgets);
    expect(find.text('4'), findsNWidgets(2));

    for (var i = 0; i < 14 && find.text('Write about your visit').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await tester.pump();
    }
    expect(find.text('Write about your visit'), findsOneWidget);
    expect(find.text('2 devotees wrote about visiting'), findsWidgets);
    expect(find.text('Queue and waiting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('followed temples list their reminder switches', (tester) async {
    SharedPreferences.setMockInitialValues({
      'followed_temples': jsonEncode([
        {'temple': {'slug': 'booking-temple', 'name': 'Sri Someshwara Swamy Temple', 'city': 'Kolanupaka', 'at': '2026-09-26T00:00:00Z'}, 'notify_festivals': true, 'notify_events': false},
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((r) async => _json({'data': []})));
    await tester.pumpWidget(MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => EngagementController(prefs, AuthController(prefs, api), api: api))],
      child: const MaterialApp(home: FollowsScreen()),
    ));
    await tester.pump();
    expect(find.text('Sri Someshwara Swamy Temple'), findsOneWidget);
    expect(find.text('Festival reminders'), findsOneWidget);
    final switches = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
    expect(switches[0].value, isTrue);
    expect(switches[1].value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
