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
      onError: tokens.onError,
      scrim: tokens.scrim,
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

  // Phase 25 restyle — "Claude Design" language (user-chosen): a deep, calm,
  // trustworthy blue primary, a warm coral accent (favorites/CTAs), clean
  // cool-neutral surfaces, and a distinct GREEN verified-agency badge (trust is
  // the product). Values ported 1:1 from UiUX/CLaude Design/tokens.css. WCAG AA.
  @override
  AppPaletteTokens get _lightTokens => const AppPaletteTokens(
    primary: Color(0xFF13507D),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD7E6F3),
    onPrimaryContainer: Color(0xFF082B44),
    accent: Color(0xFFF4795B),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFBE2DA),
    secondary: Color(0xFF0F172A),
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFFC8842F),
    success: Color(0xFF2E9E6B),
    warning: Color(0xFFC98318),
    error: Color(0xFFD23F3F),
    surface: Color(0xFFF6F8FB),
    surfaceVariant: Color(0xFFECF1F6),
    card: Color(0xFFFFFFFF),
    outline: Color(0xFFD8E0E8),
    outlineStrong: Color(0xFF64748B),
    onSurface: Color(0xFF14202B),
    onSurfaceVariant: Color(0xFF475663),
    // Phase polish (Impeccable) — was #74838F (3.66:1 on surface, below the AA
    // 4.5:1 body minimum); darkened to #5F6C78 (5.06:1) so muted text
    // (timestamps, location, placeholders) is legible. Stays clearly lighter
    // than onSurfaceVariant (#475663, 7.1:1) to preserve the text hierarchy.
    textMuted: Color(0xFF5F6C78),
    verified: Color(0xFF1F7A4D),
    verifiedContainer: Color(0xFFDCF0E5),
    // Phase 25 premium uplift — explicit semantic foregrounds + over-photo /
    // modal overlay tokens (close the "filledSuccess assumes white" gap and the
    // 6 hardcoded Colors.white/black over-photo violations).
    onError: Color(0xFFFFFFFF),
    onSuccess: Color(0xFFFFFFFF),
    onPhoto: Color(0xFFFFFFFF),
    photoOverlay: Color(0x8C0B1118),
    scrim: Color(0x66000000),
  );

  @override
  AppPaletteTokens get _darkTokens => const AppPaletteTokens(
    primary: Color(0xFF6BB0E6),
    onPrimary: Color(0xFF062339),
    primaryContainer: Color(0xFF15466B),
    onPrimaryContainer: Color(0xFFCFE6F8),
    accent: Color(0xFFFF8E72),
    onAccent: Color(0xFF3A1207),
    accentContainer: Color(0xFF5A271A),
    secondary: Color(0xFFE2E8F0),
    onSecondary: Color(0xFF0B1220),
    tertiary: Color(0xFFE2A856),
    success: Color(0xFF4CB587),
    warning: Color(0xFFE2B25A),
    error: Color(0xFFF0706E),
    surface: Color(0xFF0E141A),
    surfaceVariant: Color(0xFF1A222B),
    card: Color(0xFF161E26),
    outline: Color(0xFF2B3640),
    outlineStrong: Color(0xFF94A3B8),
    onSurface: Color(0xFFE9EFF4),
    onSurfaceVariant: Color(0xFFAAB7C2),
    textMuted: Color(0xFF7E8C98),
    verified: Color(0xFF57C48C),
    verifiedContainer: Color(0xFF163A2A),
    // Phase 25 premium uplift — dark-mode semantic foregrounds read on the
    // lighter dark success/error fills; over-photo tokens stay theme-independent.
    onError: Color(0xFF420A0A),
    onSuccess: Color(0xFF04231A),
    onPhoto: Color(0xFFFFFFFF),
    photoOverlay: Color(0x8C0B1118),
    scrim: Color(0x99000000),
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
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFCCE8E4),
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
    verified: Color(0xFF1F7A4D),
    verifiedContainer: Color(0xFFDCF0E5),
    onError: Color(0xFFFFFFFF),
    onSuccess: Color(0xFFFFFFFF),
    onPhoto: Color(0xFFFFFFFF),
    photoOverlay: Color(0x8C0B1118),
    scrim: Color(0x66000000),
  );

  @override
  AppPaletteTokens get _darkTokens => const AppPaletteTokens(
    primary: Color(0xFF9FC5FF),
    onPrimary: Color(0xFF002C72),
    primaryContainer: Color(0xFF1F4488),
    onPrimaryContainer: Color(0xFFD9E5FF),
    accent: Color(0xFF4DB6AC),
    onAccent: Color(0xFF04231F),
    accentContainer: Color(0xFF134E48),
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
    verified: Color(0xFF57C48C),
    verifiedContainer: Color(0xFF163A2A),
    onError: Color(0xFF420A0A),
    onSuccess: Color(0xFF04231A),
    onPhoto: Color(0xFFFFFFFF),
    photoOverlay: Color(0x8C0B1118),
    scrim: Color(0x99000000),
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
    required this.onAccent,
    required this.accentContainer,
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
    required this.verified,
    required this.verifiedContainer,
    required this.onError,
    required this.onSuccess,
    required this.onPhoto,
    required this.photoOverlay,
    required this.scrim,
  });

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color accent;
  final Color onAccent;
  final Color accentContainer;
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

  /// Trust signal — verified-agency badge foreground (green across palettes).
  final Color verified;

  /// Trust signal — verified-agency badge container/background.
  final Color verifiedContainer;

  /// Foreground on the [error] fill (alerts, destructive buttons).
  final Color onError;

  /// Foreground on the [success] fill (confirmation buttons, success toasts).
  final Color onSuccess;

  /// Foreground (text/icons) placed directly over photography. Theme-
  /// independent — imagery reads the same in light and dark.
  final Color onPhoto;

  /// Translucent dark base for over-photo chips and the bottom image scrim
  /// gradient. Theme-independent.
  final Color photoOverlay;

  /// Modal/backdrop scrim overlay (dialogs, bottom sheets).
  final Color scrim;
}
