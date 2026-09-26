package app.templepassport.temple_app

import com.ryanheise.audioservice.AudioServiceFragmentActivity

// Two plugins decide what this activity must be:
//
// - audio_service shares the Flutter engine with its media service, so the
//   lock-screen player and the app are one player. It needs one of its own
//   activities (AudioServiceActivity or AudioServiceFragmentActivity).
// - phonepe_payment_sdk casts the activity to FlutterFragmentActivity as soon
//   as it attaches, at launch. On a plain FlutterActivity (which
//   AudioServiceActivity is) that cast throws and the app dies before its
//   first frame.
//
// AudioServiceFragmentActivity is both. test/android_activity_test.dart
// keeps it that way.
class MainActivity : AudioServiceFragmentActivity()
