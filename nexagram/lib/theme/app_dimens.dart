/// Spacing, radius and elevation tokens shared by every screen.
///
/// Using a fixed 4pt-based scale keeps paddings and gaps visually
/// consistent across the whole app instead of ad-hoc magic numbers.
class AppDimens {
  AppDimens._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;
  static const double xxxl = 40;

  static const double radiusSmall = 10;
  static const double radiusMedium = 16;
  static const double radiusLarge = 22;
  static const double radiusPill = 999;

  static const double chatBubbleMaxWidthFraction = 0.78;
  static const double navBarHeight = 88;
  static const double appBarHeight = 56;
  static const double inputBarMinHeight = 56;
}
