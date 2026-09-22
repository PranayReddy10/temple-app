import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/theme/day_theme.dart';

void main() {
  test('every weekday has a distinct deity and accent', () {
    expect(DayTheme.all.length, 7);
    for (var i = 0; i < 7; i++) {
      expect(DayTheme.all[i].weekday, i);
    }
    expect(DayTheme.all.map((d) => d.deitySlug).toSet().length, 7);
    expect(DayTheme.all.map((d) => d.accent).toSet().length, 7);
  });

  test('traditional associations hold', () {
    expect(DayTheme.all[1].deitySlug, 'shiva');
    expect(DayTheme.all[2].deitySlug, 'hanuman');
    expect(DayTheme.all[3].deitySlug, 'krishna');
    expect(DayTheme.all[4].deitySlug, 'vishnu');
    expect(DayTheme.all[5].deitySlug, 'devi');
    expect(DayTheme.all[6].deitySlug, 'venkateswara');
    expect(DayTheme.all[0].deitySlug, 'surya');
  });

  test('forDate matches Dart weekday to Sunday-first index', () {
    expect(DayTheme.forDate(DateTime(2026, 9, 21)).dayName, 'Monday');
    expect(DayTheme.forDate(DateTime(2026, 9, 27)).dayName, 'Sunday');
  });

  test('forDeity falls back to today for unknown deities', () {
    expect(DayTheme.forDeity('ganesha').deityName, 'Ganesha');
    expect(DayTheme.forDeity('unknown').weekday, DayTheme.today().weekday);
  });
}
