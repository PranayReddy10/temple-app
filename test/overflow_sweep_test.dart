import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:temple_app/core/data/sample_data.dart';
import 'package:temple_app/features/auth/auth_screen.dart';
import 'package:temple_app/features/days/day_screen.dart';
import 'package:temple_app/features/shell/shell_screen.dart';
import 'package:temple_app/features/temple/temple_screen.dart';
import 'package:temple_app/features/bookings/bookings_screen.dart';
import 'package:temple_app/features/calendar/calendar_screen.dart';
import 'package:temple_app/features/certificates/certificates_screen.dart';
import 'package:temple_app/features/explore/explore_screen.dart';
import 'package:temple_app/features/explore/search_screen.dart';
import 'package:temple_app/features/family/family_screen.dart';
import 'package:temple_app/features/guide/guide_screen.dart';
import 'package:temple_app/features/profile/edit_profile_screen.dart';
import 'package:temple_app/features/profile/memories_screen.dart';
import 'package:temple_app/features/profile/profile_screen.dart';
import 'package:temple_app/features/qr/qr_screens.dart';
import 'package:temple_app/features/submissions/submissions_screen.dart';
import 'package:temple_app/features/yatra/yatra_screen.dart';

import 'widget_test.dart' show harness;

/// Every secondary screen, on a small phone (320 wide) and with large text,
/// must lay out without overflow. Text running into text is what devotees
/// notice first and report last.
void main() {
  final screens = <String, Widget Function()>{
    'guide, temples near me': () => const GuideScreen(initialQuestion: 'Temples near me'),
    'guide, jyotirlinga': () => const GuideScreen(initialQuestion: 'Jyotirlinga temples'),
    'explore': () => const Scaffold(body: ExploreScreen()),
    'search': () => const SearchScreen(),
    'calendar': () => const CalendarScreen(),
    'bookings': () => const BookingsScreen(),
    'help & support': () => const SubmissionsScreen(),
    'family': () => const FamilyScreen(),
    'certificates': () => const CertificatesScreen(),
    'memories': () => const MemoriesScreen(),
    'profile': () => const Scaffold(body: ProfileScreen()),
    'edit profile': () => const EditProfileScreen(),
    'sign in': () => const AuthScreen(),
    'register': () => const AuthScreen(register: true),
    'yatra': () => const Scaffold(body: YatraScreen()),
    'my passport QR': () => const MyQrScreen(),
    'home tab': () => const ShellScreen(),
    'passport tab': () => const ShellScreen(initialIndex: 2),
    'yatra tab': () => const ShellScreen(initialIndex: 3),
    'profile tab': () => const ShellScreen(initialIndex: 4),
    'temple page': () => TempleScreen(slug: 'meenakshi-amman-temple', preview: SampleData.bySlug('meenakshi-amman-temple')),
    'day page': () => const DayScreen(weekday: 4),
  };

  // English at two sizes and scales; every other language at the common
  // phone size, where longer words are what push text into text.
  final runs = <(Size, double, String)>[
    for (final size in const [Size(320, 640), Size(360, 740)])
      for (final scale in const [1.0, 1.3]) (size, scale, 'en'),
    for (final lang in const ['te', 'hi', 'ta', 'kn']) (const Size(360, 740), 1.15, lang),
  ];
  for (final (size, scale, lang) in runs) {
    {
      for (final e in screens.entries) {
        testWidgets('${e.key} fits at ${size.width.toInt()}w, text ×$scale, $lang', (tester) async {
          tester.view.physicalSize = size * 3;
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          final errors = <FlutterErrorDetails>[];
          final old = FlutterError.onError;
          FlutterError.onError = errors.add;
          await tester.pumpWidget(MediaQuery(data: MediaQueryData(textScaler: TextScaler.linear(scale), size: size), child: await harness(e.value(), locale: Locale(lang))));
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 300));
          }
          // Scroll the page itself (the first vertical scrollable) down twice.
          final vertical = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
          for (var k = 0; k < 2 && vertical.evaluate().isNotEmpty; k++) {
            await tester.drag(vertical.first, const Offset(0, -700), warnIfMissed: false);
            await tester.pump(const Duration(milliseconds: 300));
          }
          FlutterError.onError = old;
          final overflows = errors.where((d) => d.toString().contains('overflowed')).map((d) {
            final lines = d.toString().split('\n');
            final where = lines.where((l) => l.contains('file:///') && l.contains('/lib/')).take(2).map((l) => l.trim()).join(' | ');
            return '${d.exception.toString().split('\n').first} @ $where';
          }).toSet();
          expect(overflows, isEmpty, reason: overflows.join('\n'));
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
        });
      }
    }
  }
}
