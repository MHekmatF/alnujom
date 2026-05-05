import 'package:flutter/material.dart';

import 'color_palette.dart';
import 'colors.dart';
import 'radii.dart';
import 'spacing.dart';
import 'typography.dart';

ThemeData appLightTheme({
  ColorPalette palette = ColorPalette.defaultPalette,
  Locale locale = const Locale('ar'),
}) => buildAppTheme(
  palette: palette,
  brightness: Brightness.light,
  locale: locale,
);

ThemeData appDarkTheme({
  ColorPalette palette = ColorPalette.defaultPalette,
  Locale locale = const Locale('ar'),
}) => buildAppTheme(
  palette: palette,
  brightness: Brightness.dark,
  locale: locale,
);

ThemeData buildAppTheme({
  required ColorPalette palette,
  required Brightness brightness,
  required Locale locale,
}) {
  final tokens = palette.tokens(brightness);
  final colors = AppColors.fromTokens(tokens);
  final textStyles = AppTextStyles.forLocale(
    locale,
    textColor: colors.onSurface,
    secondaryTextColor: colors.onSurfaceVariant,
    primaryColor: colors.primary,
  );
  final radius = BorderRadius.circular(AppRadii.md);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: palette.scheme(brightness),
    scaffoldBackgroundColor: colors.surface,
    cardColor: colors.card,
    dividerColor: colors.divider,
    extensions: <ThemeExtension<dynamic>>[AppColorTokens.fromPalette(tokens)],
    textTheme: TextTheme(
      displayLarge: textStyles.displayLarge,
      displayMedium: textStyles.displayMedium,
      headlineLarge: textStyles.headlineLarge,
      headlineMedium: textStyles.headlineMedium,
      titleLarge: textStyles.titleLarge,
      titleMedium: textStyles.titleMedium,
      bodyLarge: textStyles.bodyLarge,
      bodyMedium: textStyles.bodyMedium,
      labelLarge: textStyles.labelLarge,
      labelMedium: textStyles.labelMedium,
    ),
    iconTheme: IconThemeData(color: colors.onSurface, size: AppSpacing.xl),
    appBarTheme: AppBarTheme(
      backgroundColor: colors.surface,
      foregroundColor: colors.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textStyles.headlineMedium,
      iconTheme: IconThemeData(color: colors.onSurface, size: AppSpacing.xl),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        disabledBackgroundColor: colors.disabledOverlay,
        disabledForegroundColor: colors.onSurfaceVariant,
        minimumSize: const Size(AppSpacing.xxxl, AppSpacing.xxxl),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
        ),
        textStyle: textStyles.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.primary,
        disabledForegroundColor: colors.onSurfaceVariant,
        minimumSize: const Size(AppSpacing.xxxl, AppSpacing.xxxl),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.lg,
        ),
        side: BorderSide(color: colors.outline),
        textStyle: textStyles.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.primary,
        disabledForegroundColor: colors.onSurfaceVariant,
        minimumSize: const Size(AppSpacing.xxxl, AppSpacing.xxxl),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.md,
        ),
        textStyle: textStyles.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    ),
  );
}
