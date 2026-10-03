import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/time_format.dart';

void main() {
  test('times are shown on the 12-hour clock', () {
    expect(showTime('05:30'), '5:30 AM');
    expect(showTime('17:30:00'), '5:30 PM');
    expect(showTime('12:00'), '12:00 PM');
    expect(showTime('00:15'), '12:15 AM');
    expect(showTime(null), isNull);
    // A label the server already wrote is left as it is.
    expect(showTime('9:00 – 10:00 AM'), '9:00 – 10:00 AM');
    expect(showTimeRange('04:30', '21:00'), '4:30 AM – 9:00 PM');
    expect(showTimeRange('18:00', null), '6:00 PM');
  });
}
