import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Typography scale modeled after iOS's SF Pro type ramp.
///
/// SF Pro Display is licensed by Apple and isn't bundled in this repo, so we
/// use Google Fonts' "Inter" everywhere instead, which has very similar
/// metrics to SF Pro. If licensed SF Pro Display font files are added later
/// under assets/fonts/ (and declared in pubspec.yaml's `fonts:` section),
/// change `_primaryFontFamily` back to that family name.
class AppTypography {
  AppTypography._();

  static final String _primaryFontFamily = GoogleFonts.inter().fontFamily!;

  /// Public accessor so other theme files (e.g. AppTheme's AppBar/button
  /// text styles) stay in sync with the font actually in use, instead of
  /// hardcoding a font family name that may not be bundled.
  static String get primaryFontFamily => _primaryFontFamily;

  static TextTheme textTheme(Color textColor, Color secondaryTextColor) {
    final TextTheme base = GoogleFonts.interTextTheme();
    return base
        .copyWith(
          displayLarge: _style(34, FontWeight.w700, textColor, -0.4),
          displayMedium: _style(28, FontWeight.w700, textColor, -0.3),
          headlineLarge: _style(24, FontWeight.w700, textColor, -0.2),
          headlineMedium: _style(20, FontWeight.w600, textColor, -0.2),
          headlineSmall: _style(17, FontWeight.w600, textColor, -0.1),
          titleLarge: _style(17, FontWeight.w600, textColor, 0),
          titleMedium: _style(15, FontWeight.w600, textColor, 0),
          titleSmall: _style(13, FontWeight.w600, secondaryTextColor, 0),
          bodyLarge: _style(17, FontWeight.w400, textColor, 0),
          bodyMedium: _style(15, FontWeight.w400, textColor, 0),
          bodySmall: _style(13, FontWeight.w400, secondaryTextColor, 0),
          labelLarge: _style(15, FontWeight.w600, textColor, 0),
          labelMedium: _style(13, FontWeight.w500, secondaryTextColor, 0),
          labelSmall: _style(11, FontWeight.w500, secondaryTextColor, 0.2),
        )
        .apply(fontFamily: _primaryFontFamily);
  }

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color,
    double letterSpacing,
  ) {
    return TextStyle(
      fontFamily: _primaryFontFamily,
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: letterSpacing,
      height: 1.28,
    );
  }

  // Chat-specific text styles, not part of the Material TextTheme.
  static TextStyle messageBody(Color color) => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.32,
      );

  static TextStyle messageTimestamp(Color color) => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0.1,
      );

  static const TextStyle chatListName = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
  );

  static TextStyle chatListPreview(Color color) => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static const TextStyle brandLogo = TextStyle(
    fontFamily: _primaryFontFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: Colors.white,
  );

  static TextStyle sectionHeader(Color color) => TextStyle(
        fontFamily: _primaryFontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.4,
      );
}

/// Convenience accessors bound to a [BuildContext]'s current brightness.
extension AppTextStyles on BuildContext {
  Color get _secondary => Theme.of(this).brightness == Brightness.dark
      ? AppColors.darkSecondaryText
      : AppColors.lightSecondaryText;

  TextStyle get messageBody => AppTypography.messageBody(
        Theme.of(this).brightness == Brightness.dark
            ? AppColors.darkText
            : AppColors.lightText,
      );

  TextStyle get messageTimestamp => AppTypography.messageTimestamp(_secondary);
}
