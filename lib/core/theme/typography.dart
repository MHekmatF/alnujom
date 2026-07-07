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
    required this.priceCurrency,
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
    // Phase 033 — Tajawal is the design-system Arabic typeface (carries UI,
    // body, and headings). Latin stays Inter.
    final displayFamily = isArabic ? 'Tajawal' : 'Inter';
    final bodyFamily = isArabic ? 'Tajawal' : 'Inter';
    final secondary = secondaryTextColor ?? textColor;
    final primary = primaryColor ?? textColor;

    return AppTextStyles._(
      // Phase 035 premium uplift — heavier weights per the New-design spec
      // (display 900 · headline 800 · title 700 · body 500 · label 700) so the
      // type reads confident/modern instead of timid.
      displayLarge: _style(
        family: displayFamily,
        size: 34,
        lineHeight: 41,
        weight: FontWeight.w800,
        color: textColor,
      ),
      displayMedium: _style(
        family: displayFamily,
        size: 28,
        lineHeight: 36,
        weight: FontWeight.w900,
        color: textColor,
      ),
      headlineLarge: _style(
        family: displayFamily,
        size: 26,
        lineHeight: 33,
        weight: FontWeight.w800,
        color: textColor,
      ),
      headlineMedium: _style(
        family: displayFamily,
        size: 22,
        lineHeight: 29,
        weight: FontWeight.w800,
        color: textColor,
      ),
      titleLarge: _style(
        family: displayFamily,
        size: 19,
        lineHeight: 25,
        weight: FontWeight.w700,
        color: textColor,
        letterSpacing: 0.15,
      ),
      titleMedium: _style(
        family: displayFamily,
        size: 16,
        lineHeight: 24,
        weight: FontWeight.w700,
        color: textColor,
        letterSpacing: 0.15,
      ),
      bodyLarge: _style(
        family: bodyFamily,
        size: 16,
        lineHeight: 24,
        weight: FontWeight.w500,
        color: textColor,
        letterSpacing: 0.5,
      ),
      bodyMedium: _style(
        family: bodyFamily,
        size: 14,
        lineHeight: 20,
        weight: FontWeight.w500,
        color: secondary,
        letterSpacing: 0.25,
      ),
      labelLarge: _style(
        family: bodyFamily,
        size: 14,
        lineHeight: 20,
        weight: FontWeight.w700,
        color: textColor,
        letterSpacing: 0.1,
      ),
      labelMedium: _style(
        family: bodyFamily,
        size: 12,
        lineHeight: 16,
        weight: FontWeight.w700,
        color: secondary,
        letterSpacing: 0.3,
      ),
      priceLarge: _style(
        family: displayFamily,
        size: 22,
        lineHeight: 28,
        weight: FontWeight.w700,
        color: primary,
        tabular: true,
      ),
      priceMedium: _style(
        family: displayFamily,
        size: 16,
        lineHeight: 22,
        weight: FontWeight.w700,
        color: primary,
        tabular: true,
      ),
      // Currency suffix beside a price — smaller + lighter than the number so
      // the amount leads and the unit (ل.س / USD) supports it.
      priceCurrency: _style(
        family: displayFamily,
        size: 14,
        lineHeight: 20,
        weight: FontWeight.w600,
        color: primary,
        letterSpacing: 0.2,
        tabular: true,
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
  final TextStyle priceCurrency;

  static TextStyle _style({
    required String family,
    required double size,
    required double lineHeight,
    required FontWeight weight,
    required Color color,
    double letterSpacing = 0,
    bool tabular = false,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
      // ui-ux-pro-max `number-tabular` rule — tabular (monospaced) figures for
      // prices so digits align in columns and don't cause layout shift when the
      // amount changes.
      fontFeatures: tabular
          ? const [FontFeature.tabularFigures()]
          : null,
    );
  }
}
