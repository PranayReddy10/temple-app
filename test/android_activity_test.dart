import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Android activity must satisfy every plugin that inspects it at
/// launch, or the app closes before drawing anything (seen only on a device:
/// the build and the Dart tests pass).
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final activity = File('android/app/src/main/kotlin/app/templepassport/temple_app/MainActivity.kt').readAsStringSync();
  final base = RegExp(r'class MainActivity\s*:\s*([A-Za-z.]+)\(\)').firstMatch(activity)?.group(1);

  test('MainActivity extends a known Flutter activity', () {
    expect(base, isNotNull);
  });

  test('PhonePe gets the FlutterFragmentActivity it casts to on attach', () {
    if (!pubspec.contains('phonepe_payment_sdk:')) return;
    expect(base, anyOf('FlutterFragmentActivity', 'AudioServiceFragmentActivity'),
        reason: 'phonepe_payment_sdk casts the activity to FlutterFragmentActivity at launch');
  });

  test('audio_service gets one of its own activities, sharing its engine', () {
    if (!pubspec.contains('audio_service:')) return;
    expect(base, anyOf('AudioServiceActivity', 'AudioServiceFragmentActivity'));
  });
}
