import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/api/api_client.dart';
import 'package:temple_app/core/data/sample_data.dart';
import 'package:temple_app/core/state/auth_controller.dart';
import 'package:temple_app/core/state/favourites_controller.dart';

void main() {
  test('saved temples keep enough to render offline and migrate the old list', () async {
    SharedPreferences.setMockInitialValues({'favourites': ['legacy-slug']});
    final prefs = await SharedPreferences.getInstance();
    final auth = AuthController(prefs, ApiClient(baseUrl: 'http://localhost:1'));
    final favs = FavouritesController(prefs, auth);
    expect(favs.contains('legacy-slug'), isTrue);

    final t = SampleData.temples.first;
    await favs.toggle(t);
    expect(favs.contains(t.slug), isTrue);
    final saved = favs.items.first;
    expect(saved.name, t.name);
    expect(saved.deitySlug, 'venkateswara');
    expect(saved.toSummary().location.city, 'Tirumala');

    // Survives a restart.
    final again = FavouritesController(prefs, auth);
    expect(again.items.map((s) => s.slug), containsAll([t.slug, 'legacy-slug']));

    await again.toggle(t);
    expect(again.contains(t.slug), isFalse);
  });
}
