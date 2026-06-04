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
    // Phase 25 restyle — component themes (previously stock Material). Rounded,
    // photo-forward cards; pill category chips; clean filled inputs; flat nav.
    cardTheme: CardThemeData(
      color: colors.card,
      surfaceTintColor: Colors.transparent,
      shadowColor: colors.secondary.withAlpha(0x1F),
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colors.card,
      selectedColor: colors.primaryContainer,
      secondarySelectedColor: colors.primaryContainer,
      disabledColor: colors.surfaceVariant,
      labelStyle: textStyles.labelLarge,
      secondaryLabelStyle: textStyles.labelLarge.copyWith(
        color: colors.onPrimaryContainer,
      ),
      side: BorderSide(color: colors.outline),
      shape: const StadiumBorder(),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      showCheckmark: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceVariant,
      hintStyle: textStyles.bodyMedium.copyWith(color: colors.textMuted),
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        borderSide: BorderSide(color: colors.error, width: 1.5),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.card,
      indicatorColor: colors.primaryContainer,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStatePropertyAll(textStyles.labelMedium),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.onPrimaryContainer
              : colors.onSurfaceVariant,
          size: AppSpacing.xl,
        ),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: colors.card,
      selectedItemColor: colors.primary,
      unselectedItemColor: colors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: textStyles.labelMedium,
      unselectedLabelStyle: textStyles.labelMedium,
      showUnselectedLabels: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      titleTextStyle: textStyles.headlineMedium,
      contentTextStyle: textStyles.bodyMedium.copyWith(color: colors.onSurface),
    ),
    dividerTheme: DividerThemeData(
      color: colors.divider,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: colors.secondary,
      contentTextStyle: textStyles.bodyMedium.copyWith(
        color: colors.onSecondary,
      ),
      actionTextColor: colors.accent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      showDragHandle: true,
      dragHandleColor: colors.outlineStrong,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
    ),
  );
}
