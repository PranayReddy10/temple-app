import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/state/temple_covers.dart';
import 'package:temple_app/core/widgets/app_image.dart';
import 'package:temple_app/core/widgets/temple_widgets.dart';

void main() {
  setUp(() => TempleCovers.instance.clear());

  test('covers are learnt from temple lists and from temples nested in other answers', () {
    TempleCovers.harvest({
      'data': [
        {'slug': 'kolanupaka', 'name': 'Someshwara', 'primary_photo': {'id': 1, 'urls': {'medium': 'https://x/k-m.webp', 'thumbnail': 'https://x/k-t.webp', 'original': 'https://x/k.jpg'}}},
        {'slug': 'no-photo', 'name': 'Bare', 'primary_photo': null},
      ],
    });
    TempleCovers.harvest({
      'data': {'reference': 'B-1', 'temple': {'slug': 'yadagiri', 'name': 'Yadadri', 'cover': {'thumbnail': 'https://x/y-t.webp', 'medium': 'https://x/y-m.webp', 'original': null}}},
    });

    expect(TempleCovers.instance.of('kolanupaka')?.medium, 'https://x/k-m.webp');
    expect(TempleCovers.instance.of('yadagiri')?.thumbnail, 'https://x/y-t.webp');
    expect(TempleCovers.instance.of('no-photo'), isNull);
  });

  testWidgets('a screen naming a temple shows its cover by slug', (tester) async {
    TempleCovers.harvest({'temple': {'slug': 'yadagiri', 'cover': {'thumbnail': 'https://x/y-t.webp', 'medium': 'https://x/y-m.webp'}}});
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox(width: 60, height: 60, child: TempleCover(slug: 'yadagiri'))));
    expect(find.byWidgetPredicate((w) => w is AppImage && w.url == 'https://x/y-t.webp'), findsOneWidget);
  });
}
