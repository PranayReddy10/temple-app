import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/widgets/temple_door.dart';

import 'widget_test.dart' show harness;

/// Entering a temple: the doors hold shut while the page builds, then open
/// fully. They used to start opening at once and lose the first frames to
/// the page's build, so they seemed to begin half open.
void main() {
  testWidgets('the doors hold shut first, then open completely', (tester) async {
    await tester.pumpWidget(await harness(
      Builder(
        builder: (context) => Scaffold(
          body: Center(child: TextButton(onPressed: () => enterTemple(context, const Scaffold(body: Text('Sanctum'))), child: const Text('Enter'))),
        ),
      ),
      prefs: {'door_animations': true},
    ));
    await tester.tap(find.text('Enter'));
    await tester.pump();

    double progress() => tester.widget<TempleDoorReveal>(find.byType(TempleDoorReveal)).progress;

    // A quarter of the way through the entrance the doors are still shut.
    await tester.pump(const Duration(milliseconds: 420));
    expect(progress(), 0);

    // Past the hold they are opening...
    await tester.pump(const Duration(milliseconds: 500));
    expect(progress(), inExclusiveRange(0, 1));

    // ...and at the end they stand fully open on the page.
    await tester.pumpAndSettle();
    expect(find.text('Sanctum'), findsOneWidget);
    expect(find.byType(TempleDoorReveal).evaluate().isEmpty || progress() == 1, isTrue);
  });
}
