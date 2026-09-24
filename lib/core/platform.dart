import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Which platform the server should answer for. Ads, payments, sign-in
/// methods and update rules all differ between them.
class AppPlatform {
  const AppPlatform._();

  /// Overridable for tests.
  static String? debugOverride;

  static String get name {
    if (debugOverride != null) return debugOverride!;
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) { TargetPlatform.iOS || TargetPlatform.macOS => 'ios', _ => 'android' };
  }

  static bool get isMobile => name == 'android' || name == 'ios';
  static bool get isIOS => name == 'ios';

  /// Set at startup from the installed build; the pubspec version otherwise.
  static String version = '0.6.0';
}

/// For opening a screen from a push notification, where no BuildContext of
/// a screen is at hand.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// Asks the shell to switch tab (0 Home … 4 Profile), for a notification
/// that opens the Passport or the Yatra planner.
final ValueNotifier<int?> shellTabRequest = ValueNotifier<int?>(null);
