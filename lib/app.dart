import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/brand.dart';
import 'core/state/app_settings.dart';
import 'core/state/day_controller.dart';
import 'core/platform.dart';
import 'core/theme/app_theme.dart';
import 'features/app_gate/app_gate.dart';
import 'features/splash/splash_screen.dart';

class TempleApp extends StatelessWidget {
  const TempleApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final day = context.watch<DayController>().theme;
    return MaterialApp(
      title: Brand.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(day),
      darkTheme: AppTheme.dark(day),
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: AppSettings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: rootNavigatorKey,
      scaffoldMessengerKey: rootMessengerKey,
      // Maintenance and required updates cover every screen.
      builder: (context, child) => AppGate(child: child ?? const SizedBox.shrink()),
      home: const SplashScreen(),
    );
  }
}
