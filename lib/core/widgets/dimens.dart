/// Kit-internal dimensional constants that are not part of the spacing/radii
/// scales. Feature code MUST NOT import these — feature surfaces consume
/// `AppSpacing` / `AppRadii` / `AppColors` / `AppTextStyles` only. The lint
/// guard's L3 rule does not fire here because these declarations are typed
/// `static const double` outside any `EdgeInsets` / `BorderRadius` / `BoxShadow`
/// constructor.
abstract final class AppDimens {
  // Stroke widths used by borders and thin accent bars.
  static const double strokeThin = 1;
  static const double strokeMedium = 2;

  // Component dimensions that don't fit the spacing scale cleanly.
  static const double buttonDenseHeight = 36;
  static const double bottomNavItemHeight = 60;
  static const double bottomNavAddIconSize = 28;
  static const int bottomNavAddIndex = 2;
  static const double skeletonCardHeight = 192;

  // PropertyCard fixed dimensions (per component-library contract).
  static const double propertyCardVerticalWidth = 336;
  static const double propertyCardHorizontalWidth = 280;
  static const double propertyCardHorizontalImageWidth = 112;

  // Common aspect ratios.
  static const double aspect4x3 = 4 / 3;
  static const double aspect16x10 = 16 / 10;
  static const double aspect16x9 = 16 / 9;
}
