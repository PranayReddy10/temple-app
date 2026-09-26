import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../api/engagement_repository.dart';
import '../models/models.dart';
import 'auth_controller.dart';

/// Likes and follows, remembered on the device and mirrored to the account.
///
/// A like is one tap and means nothing more. A follow asks to be told about
/// the temple, and carries which reminders: festivals, events, both or
/// neither, per temple. Both are recorded here at once so the button flips
/// under the finger, and sent when the server can be reached; the server's
/// answer (with the counts) then replaces the guess.
class EngagementController extends ChangeNotifier {
  EngagementController(this._prefs, this._auth, {ApiClient? api}) : _repo = api == null ? null : EngagementRepository(api) {
    _liked.addAll(_prefs.getStringList('liked_temples') ?? const []);
    final raw = _prefs.getString('followed_temples');
    if (raw != null) {
      try {
        for (final e in jsonDecode(raw) as List) {
          final f = FollowedTemple.fromStored(Map<String, dynamic>.from(e as Map));
          _follows[f.temple.slug] = f;
        }
      } catch (_) {}
    }
  }

  final SharedPreferences _prefs;
  final AuthController _auth;
  final EngagementRepository? _repo;
  final Set<String> _liked = {};
  final Map<String, FollowedTemple> _follows = {};

  /// The latest counts the server gave for a temple, by slug.
  final Map<String, Engagement> _states = {};

  /// Which temple's follow changed last, for the push topic.
  void Function(int? templeId, bool follow)? onFollowChanged;

  bool get canSync => _repo != null && _auth.isSignedIn;

  bool isLiked(String slug) => _liked.contains(slug);
  bool isFollowing(String slug) => _follows.containsKey(slug);
  FollowedTemple? followOf(String slug) => _follows[slug];
  List<FollowedTemple> get follows => _follows.values.toList()..sort((a, b) => a.temple.name.compareTo(b.temple.name));
  Set<String> get likedSlugs => Set.unmodifiable(_liked);

  /// Counts for a temple: what the server last said, adjusted for taps it
  /// has not heard about yet.
  Engagement stateFor(String slug, Engagement fromDetail) {
    final base = _states[slug] ?? fromDetail;
    // The reviews come from whichever answer carried them: an answer to a
    // tap from an older server has none, and must not blank the section.
    final reviews = base.reviews.hasData ? base.reviews : fromDetail.reviews;
    return base.copyWith(
      reviews: reviews,
      viewer: ViewerEngagement(
        liked: _liked.contains(slug),
        following: _follows.containsKey(slug),
        notifyFestivals: _follows[slug]?.notifyFestivals ?? false,
        notifyEvents: _follows[slug]?.notifyEvents ?? false,
        saved: base.viewer?.saved ?? false,
        myReview: base.viewer?.myReview ?? fromDetail.viewer?.myReview,
      ),
    );
  }

  /// The server's word on a temple, from the temple page: adopted as the
  /// truth for the account, so a like made on another phone shows here.
  /// The devotee's own review, as the server just returned it, so the
  /// temple page shows it before the page itself is fetched again.
  void setMyReview(String slug, Review review) {
    final base = _states[slug] ?? Engagement.none;
    final v = base.viewer ?? const ViewerEngagement();
    _states[slug] = base.copyWith(
      viewer: ViewerEngagement(liked: v.liked, following: v.following, notifyFestivals: v.notifyFestivals, notifyEvents: v.notifyEvents, saved: v.saved, myReview: review),
    );
    notifyListeners();
  }

  void adopt(String slug, Engagement e) {
    _states[slug] = e;
    final v = e.viewer;
    if (v == null) return;
    var changed = false;
    if (v.liked != _liked.contains(slug)) {
      v.liked ? _liked.add(slug) : _liked.remove(slug);
      changed = true;
    }
    if (!v.following && _follows.containsKey(slug)) {
      _follows.remove(slug);
      changed = true;
    }
    if (changed) _save();
  }

  Future<void> clearAll() async {
    // Unsubscribed first: forgetting a follow here does not stop the phone
    // receiving that temple's pushes, which would reach the next account.
    for (final f in _follows.values) {
      onFollowChanged?.call(f.temple.id, false);
    }
    _liked.clear();
    _follows.clear();
    _states.clear();
    await _prefs.remove('liked_temples');
    await _prefs.remove('followed_temples');
    notifyListeners();
  }

  Future<void> toggleLike(TempleSummary t) async {
    final now = !_liked.contains(t.slug);
    now ? _liked.add(t.slug) : _liked.remove(t.slug);
    _bump(t.slug, likes: now ? 1 : -1);
    await _save();
    if (!canSync) return;
    try {
      _states[t.slug] = now ? await _repo!.like(t.slug) : await _repo!.unlike(t.slug);
      notifyListeners();
    } catch (_) {
      // Sent again on the next refresh; the tap stands meanwhile.
    }
  }

  Future<void> toggleFollow(TempleSummary t) async {
    if (_follows.containsKey(t.slug)) {
      _follows.remove(t.slug);
      _bump(t.slug, follows: -1);
      await _save();
      onFollowChanged?.call(t.id, false);
      if (canSync) {
        try {
          _states[t.slug] = await _repo!.unfollow(t.slug);
          notifyListeners();
        } catch (_) {}
      }
      return;
    }
    _follows[t.slug] = FollowedTemple(temple: t);
    _bump(t.slug, follows: 1);
    await _save();
    onFollowChanged?.call(t.id, true);
    if (canSync) {
      try {
        _states[t.slug] = await _repo!.follow(t.slug);
        notifyListeners();
      } catch (_) {}
    }
  }

  /// Which reminders this followed temple may send.
  Future<void> setReminders(String slug, {bool? festivals, bool? events}) async {
    final f = _follows[slug];
    if (f == null) return;
    _follows[slug] = f.copyWith(notifyFestivals: festivals, notifyEvents: events);
    await _save();
    if (!canSync) return;
    try {
      _states[slug] = await _repo!.follow(slug, notifyFestivals: festivals, notifyEvents: events);
      notifyListeners();
    } catch (_) {}
  }

  /// The account's likes and follows, merged over what the device has:
  /// anything tapped here while offline is pushed, anything tapped
  /// elsewhere is adopted.
  Future<void> refresh() async {
    if (!canSync) return;
    try {
      final remoteFollows = await _repo!.follows();
      final remoteLikes = await _repo.likes();
      final remoteFollowSlugs = remoteFollows.map((f) => f.temple.slug).toSet();
      final remoteLikeSlugs = remoteLikes.map((t) => t.slug).toSet();
      // Local taps the server has not heard: send them.
      for (final slug in _liked.difference(remoteLikeSlugs)) {
        try {
          await _repo.like(slug);
        } catch (_) {}
      }
      for (final f in _follows.values.where((f) => !remoteFollowSlugs.contains(f.temple.slug)).toList()) {
        try {
          await _repo.follow(f.temple.slug, notifyFestivals: f.notifyFestivals, notifyEvents: f.notifyEvents);
        } catch (_) {}
      }
      _liked.addAll(remoteLikeSlugs);
      for (final f in remoteFollows) {
        _follows[f.temple.slug] = f;
      }
      await _save();
    } catch (_) {
      // Offline: the device's record serves.
    }
  }

  void _bump(String slug, {int likes = 0, int follows = 0}) {
    final s = _states[slug];
    if (s == null) return;
    _states[slug] = s.copyWith(likesCount: (s.likesCount + likes).clamp(0, 1 << 30), followsCount: (s.followsCount + follows).clamp(0, 1 << 30));
  }

  Future<void> _save() async {
    await _prefs.setStringList('liked_temples', _liked.toList());
    await _prefs.setString('followed_temples', jsonEncode(_follows.values.map((f) => f.toJson()).toList()));
    notifyListeners();
  }
}
