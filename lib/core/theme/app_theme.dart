import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'day_theme.dart';
import 'palette.dart';

/// Builds a Material theme tinted by the day's deity.
///
/// The structure (type, shapes, spacing) is constant; only the seed colour
/// and tint change, so Monday's ash-blue and Friday's kumkum feel like one
/// app in two moods rather than two apps. Cards sit on a soft shadow rather
/// than an outline, headings are set in the serif, and every control shares
/// one radius.
class AppTheme {
  AppTheme._();

  static const _serif = 'NotoSerif';
  static const _sans = 'NotoSans';
  static const fallback = ['NotoSansDevanagari', 'NotoSansTelugu', 'NotoSansTamil', 'NotoSansKannada'];

  /// The corner every card, sheet and field shares.
  static const double radius = 20;

  static ThemeData light(DayTheme day) => _build(Brightness.light, day);
  static ThemeData dark(DayTheme day) => _build(Brightness.dark, day);

  static ThemeData _build(Brightness brightness, DayTheme day) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? Palette.ebony : Palette.sandal;
    final onSurface = isDark ? Palette.sandal : Palette.deep;
    final card = isDark ? Palette.darkStone : Palette.paper;
    final accent = isDark ? _lift(day.accent) : day.accent;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: day.onAccent(),
      primaryContainer: Color.lerp(card, day.accent, isDark ? 0.35 : 0.14)!,
      onPrimaryContainer: isDark ? Palette.sandal : Color.lerp(day.accent, Palette.ebony, 0.45)!,
      secondary: Palette.gold,
      onSecondary: Palette.ebony,
      secondaryContainer: isDark ? const Color(0xFF4A3A10) : const Color(0xFFF7EBC4),
      onSecondaryContainer: isDark ? const Color(0xFFE8CF7A) : const Color(0xFF5C4600),
      tertiary: Palette.kumkum,
      onTertiary: Colors.white,
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: isDark ? Palette.stone : const Color(0xFF6E5B4E),
      surfaceContainerLowest: isDark ? const Color(0xFF170D0A) : Colors.white,
      surfaceContainerLow: isDark ? const Color(0xFF24150F) : const Color(0xFFFBF4E8),
      surfaceContainer: isDark ? const Color(0xFF2A1A15) : const Color(0xFFFAF2E4),
      surfaceContainerHigh: isDark ? const Color(0xFF33211B) : Palette.ivory,
      surfaceContainerHighest: card,
      outline: isDark ? Palette.gold.withValues(alpha: 0.35) : Palette.stone,
      outlineVariant: isDark ? Palette.gold.withValues(alpha: 0.16) : Palette.stone.withValues(alpha: 0.35),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: isDark ? Palette.sandal : Palette.deep,
      onInverseSurface: isDark ? Palette.deep : Palette.sandal,
      inversePrimary: day.secondary,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(brightness: brightness, colorScheme: scheme, useMaterial3: true, fontFamily: _sans, fontFamilyFallback: fallback);
    final text = base.textTheme.apply(bodyColor: onSurface, displayColor: onSurface, fontFamily: _sans, fontFamilyFallback: fallback);
    TextStyle? heading(TextStyle? t, {double spacing = -0.2, double? size}) => t?.copyWith(fontFamily: _serif, fontFamilyFallback: fallback, fontWeight: FontWeight.w600, letterSpacing: spacing, fontSize: size);

    final textTheme = text.copyWith(
      displayLarge: heading(text.displayLarge, spacing: -0.5),
      displayMedium: heading(text.displayMedium, spacing: -0.5),
      displaySmall: heading(text.displaySmall, spacing: -0.4),
      headlineLarge: heading(text.headlineLarge),
      headlineMedium: heading(text.headlineMedium),
      headlineSmall: heading(text.headlineSmall),
      titleLarge: heading(text.titleLarge, size: 21),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      labelLarge: text.labelLarge?.copyWith(letterSpacing: 0.6, fontWeight: FontWeight.w700),
      labelSmall: text.labelSmall?.copyWith(letterSpacing: 1.0, fontWeight: FontWeight.w700),
      bodySmall: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
      bodyMedium: text.bodyMedium?.copyWith(height: 1.4),
    );

    final cardShadow = [
      BoxShadow(color: (isDark ? Colors.black : Palette.deep).withValues(alpha: isDark ? 0.4 : 0.07), blurRadius: 18, offset: const Offset(0, 6)),
    ];

    return base.copyWith(
      scaffoldBackgroundColor: day.tint(brightness),
      textTheme: textTheme,
      iconTheme: IconThemeData(color: onSurface),
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: onSurface, fontSize: 19),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: accent,
        titleTextStyle: textTheme.titleMedium,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: card,
        selectedColor: accent.withValues(alpha: 0.18),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        labelStyle: textTheme.labelLarge?.copyWith(letterSpacing: 0.2, fontSize: 13),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14.5),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: BorderSide(color: accent.withValues(alpha: 0.6), width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 14.5),
          foregroundColor: accent,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: const StadiumBorder(), textStyle: textTheme.labelLarge, foregroundColor: accent),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: accent,
          selectedForegroundColor: day.onAccent(),
          backgroundColor: card,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: day.onAccent(),
        elevation: 4,
        shape: const StadiumBorder(),
        extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.outlineVariant)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: accent, width: 1.6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? Palette.darkStone : Palette.ivory,
        indicatorColor: accent.withValues(alpha: 0.16),
        elevation: 0,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? accent : onSurface.withValues(alpha: 0.65)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Palette.deep,
        contentTextStyle: const TextStyle(color: Palette.sandal, fontFamily: _sans, fontFamilyFallback: fallback),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      popupMenuTheme: PopupMenuThemeData(color: card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
      extensions: [AppStyle(cardShadow: cardShadow)],
    );
  }

  /// Dark schemes need a brighter accent to read on ebony.
  static Color _lift(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + 0.18).clamp(0.0, 0.85)).toColor();
  }
}

/// What the theme cannot carry by itself: the soft shadow under a card.
class AppStyle extends ThemeExtension<AppStyle> {
  const AppStyle({required this.cardShadow});

  final List<BoxShadow> cardShadow;

  static AppStyle of(BuildContext context) => Theme.of(context).extension<AppStyle>() ?? const AppStyle(cardShadow: []);

  @override
  AppStyle copyWith({List<BoxShadow>? cardShadow}) => AppStyle(cardShadow: cardShadow ?? this.cardShadow);

  @override
  AppStyle lerp(AppStyle? other, double t) => other == null ? this : AppStyle(cardShadow: t < 0.5 ? cardShadow : other.cardShadow);
}
