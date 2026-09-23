import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/platform.dart';
import '../calendar/calendar_screen.dart';
import '../days/day_screen.dart';
import '../media/in_app_browser.dart';
import '../premium/premium_screen.dart';
import '../temple/temple_screen.dart';
import 'notifications_screen.dart';

/// Opens what a notification points at: a temple, a weekday, an app screen
/// or a web page. Works from a push tap, where there is no screen context.
Future<void> openNoticeLink(AppNotice n, {BuildContext? context}) async {
  final nav = context != null ? Navigator.of(context) : rootNavigatorKey.currentState;
  if (nav == null) return;
  final value = n.linkValue ?? '';
  switch (n.linkType) {
    case 'temple' when value.isNotEmpty:
      await nav.push(MaterialPageRoute(builder: (_) => TempleScreen(slug: value)));
    case 'day':
      final w = int.tryParse(value);
      if (w != null && w >= 0 && w <= 6) await nav.push(MaterialPageRoute(builder: (_) => DayScreen(weekday: w)));
    case 'url' when value.startsWith('http'):
      final ctx = context ?? nav.context;
      if (ctx.mounted) await InAppBrowserScreen.open(ctx, value);
    case 'screen':
      switch (value) {
        case 'passport':
          nav.popUntil((r) => r.isFirst);
          shellTabRequest.value = 2;
        case 'yatra':
          nav.popUntil((r) => r.isFirst);
          shellTabRequest.value = 3;
        case 'calendar':
          await nav.push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
        case 'premium':
          await nav.push(MaterialPageRoute(builder: (_) => const PremiumScreen()));
        case 'notifications':
          await nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
      }
    default:
      // Nothing to open; from a push tap, show the inbox.
      if (context == null) await nav.push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }
}
