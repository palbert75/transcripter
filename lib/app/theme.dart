import 'package:flutter/material.dart';

/// Warm-minimalist palette from spec section 2.
/// No pure black, no harsh grays. Accent is reserved for the record action.
class ColorTokens {
  ColorTokens._();

  static const Color cream = Color(0xFFFBF5EC);
  static const Color cream2 = Color(0xFFF4ECDE);
  static const Color paper = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFECDFCF);
  static const Color lineSoft = Color(0xFFF4ECDE);
  static const Color ink = Color(0xFF2A1F17);
  static const Color inkSoft = Color(0xFF6B5B4A);
  static const Color inkFaint = Color(0xFFA5957F);
  static const Color accent = Color(0xFFD96A3A);
  static const Color accentDeep = Color(0xFFB85428);
  static const Color accentSoft = Color(0xFFF7E5D8);
  static const Color record = Color(0xFFC0432A);
  static const Color success = Color(0xFF4A7C4D);
  static const Color danger = Color(0xFFB3261E);
}

/// Typography roles from spec section 2.
class AppTextStyles {
  AppTextStyles._();

  // Serif family fallback chain. New York is system-provided on recent macOS;
  // Georgia is the universal fallback.
  static const String _serif = 'New York';
  static const List<String> _serifFallback = <String>['Georgia', 'serif'];

  static const TextStyle display = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 32,
    height: 1.1,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.32,
    color: ColorTokens.ink,
  );

  static const TextStyle sessionTitle = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 24,
    height: 1.15,
    fontWeight: FontWeight.w400,
    color: ColorTokens.ink,
  );

  static const TextStyle uiTitle = TextStyle(
    fontSize: 17,
    height: 1.2,
    fontWeight: FontWeight.w600,
    color: ColorTokens.ink,
  );

  static const TextStyle transcript = TextStyle(
    fontFamily: _serif,
    fontFamilyFallback: _serifFallback,
    fontSize: 15,
    height: 1.55,
    color: Color(0xFF3A2E24),
  );

  static const TextStyle body = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: ColorTokens.ink,
  );

  static const TextStyle meta = TextStyle(
    fontSize: 11,
    height: 1.3,
    fontWeight: FontWeight.w500,
    color: ColorTokens.inkSoft,
    letterSpacing: 1.32, // 0.12em at 11px
  );

  static const TextStyle timer = TextStyle(
    fontFamily: 'SF Mono',
    fontFamilyFallback: <String>['ui-monospace', 'monospace'],
    fontSize: 30,
    height: 1.0,
    fontWeight: FontWeight.w300,
    color: ColorTokens.ink,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    letterSpacing: 1.5,
  );

  static const TextStyle mono = TextStyle(
    fontFamily: 'SF Mono',
    fontFamilyFallback: <String>['ui-monospace', 'monospace'],
    fontSize: 11,
    color: ColorTokens.inkSoft,
    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: ColorTokens.accent,
      brightness: Brightness.light,
      surface: ColorTokens.paper,
      onSurface: ColorTokens.ink,
      primary: ColorTokens.ink,
      onPrimary: ColorTokens.cream,
      secondary: ColorTokens.accent,
      onSecondary: Colors.white,
      error: ColorTokens.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: ColorTokens.cream,
      textTheme: const TextTheme(
        displayMedium: AppTextStyles.display,
        titleLarge: AppTextStyles.sessionTitle,
        titleMedium: AppTextStyles.uiTitle,
        bodyMedium: AppTextStyles.body,
        bodySmall: AppTextStyles.meta,
      ),
    );
  }
}
