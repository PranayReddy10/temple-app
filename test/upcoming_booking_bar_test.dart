import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:temple_app/core/models/models.dart';
import 'package:temple_app/core/state/bookings_controller.dart';
import 'package:temple_app/features/home/upcoming_booking_bar.dart';

PujaBooking _booking(String ref, {required DateTime day, String status = 'confirmed', String name = 'Abhishekam'}) => PujaBooking(
      reference: ref,
      code: 'c$ref',
      status: status,
      statusLabel: status,
      templeSlug: 'sri-rama',
      templeName: 'Sri Rama Temple',
      templeCity: 'Bhadrachalam',
      templeLatitude: 17.67,
      templeLongitude: 80.89,
      pujaName: name,
      bookedFor: day,
      slotLabel: '9:00 – 10:00',
      devoteeName: 'Anu',
    );

Future<BookingsController> _controller(List<PujaBooking> bookings) async {
  SharedPreferences.setMockInitialValues({});
  final ctl = BookingsController(await SharedPreferences.getInstance());
  for (final b in bookings) {
    await ctl.put(b);
  }
  return ctl;
}

Widget _host(BookingsController ctl) => ChangeNotifierProvider.value(
      value: ctl,
      child: const MaterialApp(home: Scaffold(body: Align(alignment: Alignment.bottomCenter, child: UpcomingBookingBar()))),
    );

void main() {
  final today = DateTime.now();
  final tomorrow = DateTime(today.year, today.month, today.day + 1);

  testWidgets('the soonest booking shows at the bottom of Home with how many more', (tester) async {
    final ctl = await _controller([
      _booking('SV2', day: tomorrow.add(const Duration(days: 3)), name: 'Archana'),
      _booking('SV1', day: tomorrow),
    ]);
    await tester.pumpWidget(_host(ctl));

    expect(find.text('Abhishekam'), findsOneWidget);
    expect(find.textContaining('Tomorrow · 9:00 – 10:00 · Sri Rama Temple'), findsOneWidget);
    expect(find.text('+1 more'), findsOneWidget);
    expect(find.byIcon(Icons.directions_rounded), findsOneWidget);
  });

  testWidgets('a booking received, expired or cancelled leaves Home', (tester) async {
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final ctl = await _controller([
      _booking('SV3', day: tomorrow, status: 'verified'),
      _booking('SV4', day: yesterday),
      _booking('SV5', day: tomorrow, status: 'cancelled'),
    ]);
    await tester.pumpWidget(_host(ctl));

    expect(find.byType(Material), findsWidgets);
    expect(find.text('Abhishekam'), findsNothing);
  });

  test('the date reads as Today, Tomorrow, or the day', () {
    final now = DateTime.now();
    expect(UpcomingBookingBar.dayLabel(now), 'Today');
    expect(UpcomingBookingBar.dayLabel(DateTime(now.year, now.month, now.day + 1)), 'Tomorrow');
  });
}
