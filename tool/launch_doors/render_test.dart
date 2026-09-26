// Draws the closed temple doors, exactly as the splash's first frame shows
// them, for the native launch windows (Android and iOS):
//
//   flutter test tool/launch_doors/render_test.dart
//
// The launch window is on screen while the Flutter engine starts. Showing
// the same doors there means the app opens straight onto the doors, with no
// blank screen before them.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/theme/palette.dart';
import 'package:temple_app/core/widgets/temple_door.dart';

void main() {
  testWidgets('render the launch doors', (tester) async {
    const size = Size(360, 780); // a 19.5:9 phone; the launch window stretches it
    const ratio = 2.0; // 720 × 1560
    tester.view.physicalSize = size * ratio;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: key,
        child: const ColoredBox(
          color: Palette.deep,
          child: TempleDoorReveal(progress: 0, accent: Palette.gold, child: ColoredBox(color: Palette.deep)),
        ),
      ),
    ));
    await tester.pump();
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: ratio);
      return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    });
    for (final path in [
      'android/app/src/main/res/drawable-nodpi/launch_doors.png',
      'ios/Runner/Assets.xcassets/LaunchDoors.imageset/LaunchDoors.png',
    ]) {
      File(path)
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes!);
    }
  });
}
