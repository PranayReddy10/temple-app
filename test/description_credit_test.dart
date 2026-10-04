import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/models/models.dart';

void main() {
  test('a description from Wikipedia carries its credit', () {
    final d = TempleDetail.fromJson({
      'slug': 'ramappa',
      'name': 'Ramappa Temple',
      'about': {
        'short_description': 'The Ramappa Temple is a Kakatiya-style Hindu temple.',
        'description_source': 'wikipedia',
        'description_credit': {'text': 'From Wikipedia, CC BY-SA 4.0', 'url': 'https://en.wikipedia.org/wiki/Ramappa_Temple'},
      },
    });
    expect(d.descriptionCredit, 'From Wikipedia, CC BY-SA 4.0');
    expect(d.descriptionCreditUrl, 'https://en.wikipedia.org/wiki/Ramappa_Temple');

    final ours = TempleDetail.fromJson({'slug': 'x', 'name': 'X', 'about': {'short_description': 'Written by us.', 'description_credit': null}});
    expect(ours.descriptionCredit, isNull);
  });
}
