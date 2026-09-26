import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'day_theme.dart';
import 'palette.dart';

/// Builds a Material theme tinted by the day's deity.
///
/// The structure (type, shapes, spacing) is constant; only the seed colour
/// and tint change, so Monday's ash-blue and Friday's kumkum feel like one
/// app in two moods rather than two apps.
class AppTheme {
  AppTheme._();

  static const _serif = 'NotoSerif';
  static const _sans = 'NotoSans';
  static const fallback = ['NotoSansDevanagari', 'NotoSansTelugu', 'NotoSansTamil', 'NotoSansKannada'];

  static ThemeData light(DayTheme day) => _build(Brightness.light, day);
  static ThemeData dark(DayTheme day) => _build(Brightness.dark, day);

  static ThemeData _build(Brightness brightness, DayTheme day) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? Palette.ebony : Palette.sandal;
    final onSurface = isDark ? Palette.sandal : Palette.deep;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? _lift(day.accent) : day.accent,
      onPrimary: day.onAccent(),
      secondary: Palette.gold,
      onSecondary: Palette.ebony,
      tertiary: Palette.kumkum,
      onTertiary: Colors.white,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: isDark ? Palette.darkStone : Palette.ivory,
      surfaceContainer: isDark ? const Color(0xFF2A1A15) : const Color(0xFFFAF2E4),
      outline: isDark ? Palette.gold.withValues(alpha: 0.35) : Palette.stone,
      outlineVariant: isDark ? Palette.gold.withValues(alpha: 0.18) : Palette.stone.withValues(alpha: 0.45),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? Palette.sandal : Palette.deep,
      onInverseSurface: isDark ? Palette.deep : Palette.sandal,
      inversePrimary: day.secondary,
      surfaceTint: day.accent,
    );

    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true, fontFamily: _sans, fontFamilyFallback: fallback);
    final text = base.textTheme.apply(bodyColor: onSurface, displayColor: onSurface, fontFamily: _sans, fontFamilyFallback: fallback);

    return base.copyWith(
      scaffoldBackgroundColor: day.tint(brightness),
      textTheme: text.copyWith(
        displayLarge: text.displayLarge?.copyWith(fontFamily: _serif, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        displayMedium: text.displayMedium?.copyWith(fontFamily: _serif, fontWeight: FontWeight.w600),
        displaySmall: text.displaySmall?.copyWith(fontFamily: _serif, fontWeight: FontWeight.w600),
        headlineLarge: text.headlineLarge?.copyWith(fontFamily: _serif, fontWeight: FontWeight.w600),
        headlineMedium: text.headlineMedium?.copyWith(fontFamily: _serif, fontWeight: FontWeight.w600),
        headlineSmall: text.headlineSmall?.copyWith(fontFamily: _serif, fontWeight: FontWeight.w600),
        titleLarge: text.titleLarge?.copyWith(fontFamily: _serif, fontWeight: FontWeight.w600),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        labelLarge: text.labelLarge?.copyWith(letterSpacing: 1.0, fontWeight: FontWeight.w700),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge?.copyWith(fontFamily: _serif, fontWeight: FontWeight.w600, color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHighest,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: text.labelLarge?.copyWith(letterSpacing: 0.2, fontWeight: FontWeight.w600),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: text.labelLarge?.copyWith(letterSpacing: 0.8),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: scheme.primary),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? Palette.darkStone : Palette.ivory,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        labelTextStyle: WidgetStatePropertyAll(text.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? scheme.primary : onSurface.withValues(alpha: 0.65)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.deep,
        contentTextStyle: const TextStyle(color: Palette.sandal),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  /// Dark schemes need a brighter accent to read on ebony.
  static Color _lift(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 0.85)).toColor();
  }
}
