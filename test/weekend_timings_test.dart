import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/models/models.dart';

void main() {
  final timings = [
    Timing.fromJson({'kind': 'darshan', 'label': 'Darshan', 'days': null, 'opens_at': '06:00', 'closes_at': '20:00'}),
    Timing.fromJson({'kind': 'darshan', 'label': 'Darshan', 'days': [6, 0], 'opens_at': '05:00', 'closes_at': '21:30'}),
    Timing.fromJson({'kind': 'aarti', 'label': 'Sandhya Arati', 'days': null, 'opens_at': '19:00'}),
    Timing.fromJson({'kind': 'aarti', 'label': 'Shayana Arati', 'days': null, 'opens_at': '20:10'}),
    Timing.fromJson({'kind': 'aarti', 'label': 'Shayana Arati', 'days': [6, 0], 'opens_at': '20:35'}),
  ];

  test('the weekend shows its own hours, not both', () {
    final saturday = Timing.forDay(timings, 6);
    expect(saturday.map((t) => '${t.label} ${t.opensAt}'), ['Darshan 05:00', 'Sandhya Arati 19:00', 'Shayana Arati 20:35']);

    final monday = Timing.forDay(timings, 1);
    expect(monday.map((t) => '${t.label} ${t.opensAt}'), ['Darshan 06:00', 'Sandhya Arati 19:00', 'Shayana Arati 20:10']);
  });

  test('an older server sends one day_of_week', () {
    final sunday = Timing.fromJson({'kind': 'darshan', 'day_of_week': 0});
    expect(sunday.appliesOn(0), isTrue);
    expect(sunday.appliesOn(1), isFalse);
    expect(Timing.fromJson({'kind': 'darshan', 'day_of_week': null}).isEveryDay, isTrue);
  });
}
