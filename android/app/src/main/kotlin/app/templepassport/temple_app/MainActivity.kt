package app.templepassport.temple_app

import io.flutter.embedding.android.FlutterFragmentActivity

// phonepe_payment_sdk casts the activity to FlutterFragmentActivity as soon
// as it attaches, at launch; on a plain FlutterActivity that cast throws and
// the app dies before its first frame. test/android_activity_test.dart keeps
// it that way.
class MainActivity : FlutterFragmentActivity()
