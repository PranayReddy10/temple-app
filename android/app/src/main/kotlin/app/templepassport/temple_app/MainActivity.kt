package app.templepassport.temple_app

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity rather than FlutterActivity: it shares the Flutter
// engine with the media service, so the lock-screen player and the app are
// one and the same player.
class MainActivity : AudioServiceActivity()
