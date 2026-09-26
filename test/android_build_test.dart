import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Flutter's Gradle plugin refuses Gradle, AGP and Kotlin versions below its
/// minimums, and reports it as "Starting AGP 9+, only the new DSL interface
/// will be read", which points at the wrong thing. These are the minimums of
/// Flutter 3.47 (DependencyVersionChecker); raise them with Flutter.
void main() {
  final settings = File('android/settings.gradle.kts').readAsStringSync();
  final wrapper = File('android/gradle/wrapper/gradle-wrapper.properties').readAsStringSync();
  final app = File('android/app/build.gradle.kts').readAsStringSync();

  List<int> version(String v) => v.split('.').map(int.parse).toList();
  bool atLeast(String v, String min) {
    final a = version(v), b = version(min);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return true;
  }

  String plugin(String id) => RegExp('id\\("${RegExp.escape(id)}"\\) version "([0-9.]+)"').firstMatch(settings)!.group(1)!;

  test('Android Gradle Plugin is at least 8.11.1, and still 8.x', () {
    final agp = plugin('com.android.application');
    expect(atLeast(agp, '8.11.1'), isTrue, reason: 'AGP $agp');
    expect(agp.startsWith('8.'), isTrue, reason: 'AGP 9 needs the new DSL, which the payment and ad plugins do not support yet');
  });

  test('Kotlin is at least 2.2.20', () {
    final kgp = plugin('org.jetbrains.kotlin.android');
    expect(atLeast(kgp, '2.2.20'), isTrue, reason: 'Kotlin $kgp');
  });

  test('Gradle is at least 8.14', () {
    final gradle = RegExp(r'gradle-([0-9.]+)-(all|bin)\.zip').firstMatch(wrapper)!.group(1)!;
    expect(atLeast(gradle, '8.14'), isTrue, reason: 'Gradle $gradle');
  });

  test('the app uses Java 17 and compilerOptions, not kotlinOptions', () {
    expect(app.contains('VERSION_17'), isTrue);
    expect(RegExp(r'^\s*kotlinOptions\s*\{', multiLine: true).hasMatch(app), isFalse, reason: 'an error from Kotlin 2.2');
  });
}
