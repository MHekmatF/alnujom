import 'package:flutter/material.dart';

import 'colors.dart';

@immutable
final class AppTextStyles {
  const AppTextStyles._({
    required this.displayLarge,
    required this.displayMedium,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.titleLarge,
    required this.titleMedium,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.labelLarge,
    required this.labelMedium,
    required this.priceLarge,
    required this.priceMedium,
  });

  factory AppTextStyles.of(BuildContext context) {
    final colors = AppColors.of(context);
    return AppTextStyles.forLocale(
      Localizations.localeOf(context),
      textColor: colors.onSurface,
      secondaryTextColor: colors.onSurfaceVariant,
      primaryColor: colors.primary,
    );
  }

  factory AppTextStyles.forLocale(
    Locale locale, {
    required Color textColor,
    Color? secondaryTextColor,
    Color? primaryColor,
  }) {
    final isArabic = locale.languageCode.toLowerCase() == 'ar';
    final displayFamily = isArabic ? 'Cairo' : 'Inter';
    final bodyFamily = isArabic ? 'IBMPlexSansArabic' : 'Inter';
    final secondary = secondaryTextColor ?? textColor;
    final primary = primaryColor ?? textColor;

    return AppTextStyles._(
      displayLarge: _style(
        family: displayFamily,
        size: 34,
        lineHeight: 41,
        weight: FontWeight.w700,
        color: textColor,
      ),
      displayMedium: _style(
        family: displayFamily,
        size: 28,
        lineHeight: 36,
        weight: FontWeight.w700,
        color: textColor,
      ),
      headlineLarge: _style(
        family: displayFamily,
        size: 26,
        lineHeight: 33,
        weight: FontWeight.w700,
        color: textColor,
      ),
      headlineMedium: _style(
        family: displayFamily,
        size: 22,
        lineHeight: 29,
        weight: FontWeight.w600,
        color: textColor,
      ),
      titleLarge: _style(
        family: displayFamily,
        size: 19,
        lineHeight: 25,
        weight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.15,
      ),
      titleMedium: _style(
        family: displayFamily,
        size: 16,
        lineHeight: 24,
        weight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.15,
      ),
      bodyLarge: _style(
        family: bodyFamily,
        size: 16,
        lineHeight: 24,
        weight: FontWeight.w400,
        color: textColor,
        letterSpacing: 0.5,
      ),
      bodyMedium: _style(
        family: bodyFamily,
        size: 14,
        lineHeight: 20,
        weight: FontWeight.w400,
        color: secondary,
        letterSpacing: 0.25,
      ),
      labelLarge: _style(
        family: bodyFamily,
        size: 14,
        lineHeight: 20,
        weight: FontWeight.w600,
        color: textColor,
        letterSpacing: 0.1,
      ),
      labelMedium: _style(
        family: bodyFamily,
        size: 12,
        lineHeight: 16,
        weight: FontWeight.w600,
        color: secondary,
        letterSpacing: 0.3,
      ),
      priceLarge: _style(
        family: displayFamily,
        size: 22,
        lineHeight: 28,
        weight: FontWeight.w700,
        color: primary,
      ),
      priceMedium: _style(
        family: displayFamily,
        size: 16,
        lineHeight: 22,
        weight: FontWeight.w700,
        color: primary,
      ),
    );
  }

  final TextStyle displayLarge;
  final TextStyle displayMedium;
  final TextStyle headlineLarge;
  final TextStyle headlineMedium;
  final TextStyle titleLarge;
  final TextStyle titleMedium;
  final TextStyle bodyLarge;
  final TextStyle bodyMedium;
  final TextStyle labelLarge;
  final TextStyle labelMedium;
  final TextStyle priceLarge;
  final TextStyle priceMedium;

  static TextStyle _style({
    required String family,
    required double size,
    required double lineHeight,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }
}
