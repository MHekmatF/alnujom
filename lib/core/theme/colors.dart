import 'package:flutter/material.dart';

import 'color_palette.dart';

@immutable
final class AppColors {
  const AppColors._({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.secondary,
    required this.onSecondary,
    required this.tertiary,
    required this.success,
    required this.warning,
    required this.error,
    required this.surface,
    required this.surfaceVariant,
    required this.card,
    required this.outline,
    required this.outlineStrong,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.textMuted,
    required this.divider,
    required this.disabledOverlay,
  });

  factory AppColors.fromTokens(AppPaletteTokens tokens) => AppColors._(
    primary: tokens.primary,
    onPrimary: tokens.onPrimary,
    primaryContainer: tokens.primaryContainer,
    onPrimaryContainer: tokens.onPrimaryContainer,
    accent: tokens.accent,
    secondary: tokens.secondary,
    onSecondary: tokens.onSecondary,
    tertiary: tokens.tertiary,
    success: tokens.success,
    warning: tokens.warning,
    error: tokens.error,
    surface: tokens.surface,
    surfaceVariant: tokens.surfaceVariant,
    card: tokens.card,
    outline: tokens.outline,
    outlineStrong: tokens.outlineStrong,
    onSurface: tokens.onSurface,
    onSurfaceVariant: tokens.onSurfaceVariant,
    textMuted: tokens.textMuted,
    divider: tokens.outline,
    disabledOverlay: tokens.onSurface.withAlpha(0x61),
  );

  factory AppColors.of(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<AppColorTokens>();

    return AppColors._(
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      primaryContainer: scheme.primaryContainer,
      onPrimaryContainer: scheme.onPrimaryContainer,
      accent: tokens?.accent ?? scheme.tertiary,
      secondary: scheme.secondary,
      onSecondary: scheme.onSecondary,
      tertiary: scheme.tertiary,
      success: tokens?.success ?? scheme.tertiary,
      warning: tokens?.warning ?? scheme.tertiary,
      error: scheme.error,
      surface: scheme.surface,
      surfaceVariant: tokens?.surfaceVariant ?? scheme.surfaceContainerHighest,
      card: tokens?.card ?? scheme.surface,
      outline: scheme.outline,
      outlineStrong: tokens?.outlineStrong ?? scheme.outline,
      onSurface: scheme.onSurface,
      onSurfaceVariant: scheme.onSurfaceVariant,
      textMuted: tokens?.textMuted ?? scheme.onSurfaceVariant,
      divider: scheme.outline,
      disabledOverlay: scheme.onSurface.withAlpha(0x61),
    );
  }

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color accent;
  final Color secondary;
  final Color onSecondary;
  final Color tertiary;
  final Color success;
  final Color warning;
  final Color error;
  final Color surface;
  final Color surfaceVariant;
  final Color card;
  final Color outline;
  final Color outlineStrong;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color textMuted;
  final Color divider;
  final Color disabledOverlay;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppColors &&
          primary == other.primary &&
          onPrimary == other.onPrimary &&
          primaryContainer == other.primaryContainer &&
          onPrimaryContainer == other.onPrimaryContainer &&
          accent == other.accent &&
          secondary == other.secondary &&
          onSecondary == other.onSecondary &&
          tertiary == other.tertiary &&
          success == other.success &&
          warning == other.warning &&
          error == other.error &&
          surface == other.surface &&
          surfaceVariant == other.surfaceVariant &&
          card == other.card &&
          outline == other.outline &&
          outlineStrong == other.outlineStrong &&
          onSurface == other.onSurface &&
          onSurfaceVariant == other.onSurfaceVariant &&
          textMuted == other.textMuted &&
          divider == other.divider &&
          disabledOverlay == other.disabledOverlay;

  @override
  int get hashCode => Object.hashAll([
    primary,
    onPrimary,
    primaryContainer,
    onPrimaryContainer,
    accent,
    secondary,
    onSecondary,
    tertiary,
    success,
    warning,
    error,
    surface,
    surfaceVariant,
    card,
    outline,
    outlineStrong,
    onSurface,
    onSurfaceVariant,
    textMuted,
    divider,
    disabledOverlay,
  ]);
}

@immutable
final class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.accent,
    required this.success,
    required this.warning,
    required this.surfaceVariant,
    required this.card,
    required this.outlineStrong,
    required this.textMuted,
  });

  factory AppColorTokens.fromPalette(AppPaletteTokens tokens) => AppColorTokens(
    accent: tokens.accent,
    success: tokens.success,
    warning: tokens.warning,
    surfaceVariant: tokens.surfaceVariant,
    card: tokens.card,
    outlineStrong: tokens.outlineStrong,
    textMuted: tokens.textMuted,
  );

  final Color accent;
  final Color success;
  final Color warning;
  final Color surfaceVariant;
  final Color card;
  final Color outlineStrong;
  final Color textMuted;

  @override
  AppColorTokens copyWith({
    Color? accent,
    Color? success,
    Color? warning,
    Color? surfaceVariant,
    Color? card,
    Color? outlineStrong,
    Color? textMuted,
  }) {
    return AppColorTokens(
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      card: card ?? this.card,
      outlineStrong: outlineStrong ?? this.outlineStrong,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  AppColorTokens lerp(ThemeExtension<AppColorTokens>? other, double t) {
    if (other is! AppColorTokens) {
      return this;
    }

    return AppColorTokens(
      accent: Color.lerp(accent, other.accent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      card: Color.lerp(card, other.card, t)!,
      outlineStrong: Color.lerp(outlineStrong, other.outlineStrong, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }
}
