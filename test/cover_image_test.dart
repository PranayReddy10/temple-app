import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/widgets/app_image.dart';
import 'package:temple_app/core/widgets/temple_widgets.dart';

void main() {
  test('a photo offers every size, best first, with no repeats', () {
    const p = Photo(medium: 'https://x/m.webp', original: 'https://x/o.jpg', thumbnail: 'https://x/t.webp');
    expect(p.candidates, ['https://x/m.webp', 'https://x/o.jpg', 'https://x/t.webp']);
    expect(p.smallCandidates, ['https://x/t.webp', 'https://x/m.webp', 'https://x/o.jpg']);
    const onlyOriginal = Photo(original: 'https://x/o.jpg', medium: 'https://x/o.jpg');
    expect(onlyOriginal.candidates, ['https://x/o.jpg']);
    expect(const Photo().candidates, isEmpty);
  });

  testWidgets('a cover whose resized copy is missing falls back to the original', (tester) async {
    // No network in tests: every Image.network fails, so the widget must
    // walk the whole list of sizes and end on the placeholder, not stop at
    // the first failure.
    const p = Photo(medium: 'https://example.invalid/m.webp', original: 'https://example.invalid/o.jpg');
    await tester.pumpWidget(const MaterialApp(home: SizedBox(width: 300, height: 200, child: TempleImage(photo: p, deitySlug: 'shiva'))));
    final first = tester.widget<AppImage>(find.byType(AppImage).first);
    expect(first.url, 'https://example.invalid/m.webp');
    expect(first.fallbacks, ['https://example.invalid/o.jpg']);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    // Twice: the fitted photo and the blurred copy behind it both fell back.
    expect(find.byWidgetPredicate((w) => w is AppImage && w.url == 'https://example.invalid/o.jpg'), findsNWidgets(2));
  });
}
