import 'package:flutter/material.dart';

sealed class ColorPalette {
  const ColorPalette();

  static const ColorPalette defaultPalette = ModernPalette();

  String get name;

  ColorScheme lightScheme() => _scheme(_lightTokens, Brightness.light);

  ColorScheme darkScheme() => _scheme(_darkTokens, Brightness.dark);

  AppPaletteTokens lightTokens() => _lightTokens;

  AppPaletteTokens darkTokens() => _darkTokens;

  ColorScheme scheme(Brightness brightness) => switch (brightness) {
    Brightness.light => lightScheme(),
    Brightness.dark => darkScheme(),
  };

  AppPaletteTokens tokens(Brightness brightness) => switch (brightness) {
    Brightness.light => lightTokens(),
    Brightness.dark => darkTokens(),
  };

  static ColorPalette fromName(String name) => switch (name.toLowerCase()) {
    'trust' => const TrustPalette(),
    _ => defaultPalette,
  };

  AppPaletteTokens get _lightTokens;

  AppPaletteTokens get _darkTokens;

  ColorScheme _scheme(AppPaletteTokens tokens, Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: tokens.primary,
      brightness: brightness,
    ).copyWith(
      primary: tokens.primary,
      onPrimary: tokens.onPrimary,
      primaryContainer: tokens.primaryContainer,
      onPrimaryContainer: tokens.onPrimaryContainer,
      secondary: tokens.secondary,
      onSecondary: tokens.onSecondary,
      tertiary: tokens.tertiary,
      error: tokens.error,
      surface: tokens.surface,
      onSurface: tokens.onSurface,
      onSurfaceVariant: tokens.onSurfaceVariant,
      outline: tokens.outline,
    );
  }
}

final class ModernPalette extends ColorPalette {
  const ModernPalette();

  @override
  String get name => 'modern';

  // Phase 25 restyle — "keep & refine the blue": trustworthy royal-blue primary
  // (the established identity) kept, with a warm coral accent (Airbnb/VRBO warmth)
  // for highlights, cleaner cool-neutral surfaces (Zillow), and deeper ink/muted
  // text for stronger contrast (WCAG AA; avoids the washed-out-gray trap).
  @override
  AppPaletteTokens get _lightTokens => const AppPaletteTokens(
    primary: Color(0xFF1D4ED8),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE4ECFD),
    onPrimaryContainer: Color(0xFF0A234F),
    accent: Color(0xFFEF7C46),
    secondary: Color(0xFF0F172A),
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFFF57C00),
    success: Color(0xFF15803D),
    warning: Color(0xFFD97706),
    error: Color(0xFFDC2626),
    surface: Color(0xFFF6F8FC),
    surfaceVariant: Color(0xFFEDF1F8),
    card: Color(0xFFFFFFFF),
    outline: Color(0xFFE3E9F1),
    outlineStrong: Color(0xFF64748B),
    onSurface: Color(0xFF0F1A2E),
    onSurfaceVariant: Color(0xFF566276),
    textMuted: Color(0xFF7C8AA0),
  );

  @override
  AppPaletteTokens get _darkTokens => const AppPaletteTokens(
    primary: Color(0xFF7DB0FF),
    onPrimary: Color(0xFF0A1A33),
    primaryContainer: Color(0xFF1E3A78),
    onPrimaryContainer: Color(0xFFDCE8FF),
    accent: Color(0xFFFF9E6B),
    secondary: Color(0xFFE2E8F0),
    onSecondary: Color(0xFF0B1220),
    tertiary: Color(0xFFFFB74D),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    surface: Color(0xFF0B111E),
    surfaceVariant: Color(0xFF1B2433),
    card: Color(0xFF131C2B),
    outline: Color(0xFF26303F),
    outlineStrong: Color(0xFF94A3B8),
    onSurface: Color(0xFFF1F5FB),
    onSurfaceVariant: Color(0xFFA7B4C7),
    textMuted: Color(0xFF7E8DA3),
  );
}

final class TrustPalette extends ColorPalette {
  const TrustPalette();

  @override
  String get name => 'trust';

  @override
  AppPaletteTokens get _lightTokens => const AppPaletteTokens(
    primary: Color(0xFF2457A6),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD9E5FF),
    onPrimaryContainer: Color(0xFF001A41),
    accent: Color(0xFF00897B),
    secondary: Color(0xFF0F172A),
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFFF57C00),
    success: Color(0xFF16A34A),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFDC2626),
    surface: Color(0xFFF8FAFC),
    surfaceVariant: Color(0xFFE1E5EE),
    card: Color(0xFFFFFFFF),
    outline: Color(0xFFE2E8F0),
    outlineStrong: Color(0xFF74777F),
    onSurface: Color(0xFF111827),
    onSurfaceVariant: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
  );

  @override
  AppPaletteTokens get _darkTokens => const AppPaletteTokens(
    primary: Color(0xFF9FC5FF),
    onPrimary: Color(0xFF002C72),
    primaryContainer: Color(0xFF1F4488),
    onPrimaryContainer: Color(0xFFD9E5FF),
    accent: Color(0xFF4DB6AC),
    secondary: Color(0xFFE2E8F0),
    onSecondary: Color(0xFF0B1220),
    tertiary: Color(0xFFFFB74D),
    success: Color(0xFF22C55E),
    warning: Color(0xFFFBBF24),
    error: Color(0xFFF87171),
    surface: Color(0xFF0B1220),
    surfaceVariant: Color(0xFF3E4856),
    card: Color(0xFF0F172A),
    outline: Color(0xFF1E293B),
    outlineStrong: Color(0xFF8E9099),
    onSurface: Color(0xFFF8FAFC),
    onSurfaceVariant: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
  );
}

@immutable
final class AppPaletteTokens {
  const AppPaletteTokens({
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
  });

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
}
