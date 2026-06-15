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
    // Gold/tertiary always carries a dark foreground (it fails contrast under
    // white); the deep ink reads cleanly on both the warm and the brighter gold.
    const onTertiary = Color(0xFF1A1714);
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
      secondaryContainer: tokens.surfaceVariant,
      onSecondaryContainer: tokens.onSurface,
      tertiary: tokens.tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tokens.accentContainer,
      onTertiaryContainer: onTertiary,
      error: tokens.error,
      onError: tokens.onError,
      scrim: tokens.scrim,
      surface: tokens.surface,
      onSurface: tokens.onSurface,
      onSurfaceVariant: tokens.onSurfaceVariant,
      outline: tokens.outline,
      outlineVariant: tokens.outline,
      // Drive Material 3's own surface ramp from our tokens (menus, sheets,
      // dropdowns, filled fields) so nothing reads the seed-derived defaults —
      // and kill the M3 elevation tint app-wide (cards/app bars stay flat).
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: tokens.surface,
      surfaceContainerLow: tokens.surface,
      surfaceContainer: tokens.surfaceVariant,
      surfaceContainerHigh: tokens.card,
      surfaceContainerHighest: tokens.surfaceVariant,
      inverseSurface: tokens.onSurface,
      onInverseSurface: tokens.surface,
    );
  }
}

final class ModernPalette extends ColorPalette {
  const ModernPalette();

  @override
  String get name => 'modern';

  // Phase 32 redesign — "Airy" light language (from the Al Nujom Design System).
  // Cool off-white surfaces (#F5F7FA) + crisp white cards and an airy 4px
  // rhythm; a fresh TEAL (#0F766E) is the PRIMARY UI accent (links, icons,
  // active states, price — AA-legible as text on the cool surface), GOLD
  // (#C2A14D) stays the premium/featured signature (tertiary — featured badges
  // only), coral marks favorites, and the green/WhatsApp trust signals are
  // preserved. Slate ink ramp (#0F172A → #475569 → #64748B). Gold is never used
  // as link/label text (fails contrast) — only as a fill behind dark ink or a
  // badge tint. WCAG AA on the cool surface.
  @override
  AppPaletteTokens get _lightTokens => const AppPaletteTokens(
    primary: Color(0xFF0F766E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCCFBF1),
    onPrimaryContainer: Color(0xFF0A4A45),
    accent: Color(0xFFF4795B),
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFBE5DC),
    secondary: Color(0xFF0F172A),
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFFC2A14D),
    success: Color(0xFF2E9E6B),
    warning: Color(0xFFC98318),
    error: Color(0xFFD23F3F),
    surface: Color(0xFFF5F7FA),
    surfaceVariant: Color(0xFFEAEFF5),
    card: Color(0xFFFFFFFF),
    outline: Color(0xFFE2E8F0),
    outlineStrong: Color(0xFFCBD5E1),
    onSurface: Color(0xFF0F172A),
    onSurfaceVariant: Color(0xFF475569),
    // Slate muted (#64748B ≈ 4.6:1 on #F5F7FA), clearly lighter than
    // onSurfaceVariant (#475569 ≈ 7:1) so the timestamp/location/placeholder
    // hierarchy holds.
    textMuted: Color(0xFF64748B),
    verified: Color(0xFF1F7A4D),
    verifiedContainer: Color(0xFFDCF0E5),
    onError: Color(0xFFFFFFFF),
    onSuccess: Color(0xFFFFFFFF),
    onPhoto: Color(0xFFFFFFFF),
    // Cool slate-tinted dark scrim for over-photo chips + the image gradient.
    photoOverlay: Color(0x8C0F172A),
    scrim: Color(0x66000000),
    whatsapp: Color(0xFF1DAB61),
    onWhatsapp: Color(0xFFFFFFFF),
  );

  // Phase 32 redesign — DS dark surfaces (midnight-navy #0B1020 + elevated
  // #161C2D cards) carrying the Airy TEAL accent for brand consistency with
  // light: a bright teal (#2DD4BF) primary that glows on key CTAs / the active
  // nav (glow added at the widget layer) and takes DARK ink (#04231F) on fills,
  // a warm gold featured accent, coral favorites, green/WhatsApp trust. WCAG AA.
  @override
  AppPaletteTokens get _darkTokens => const AppPaletteTokens(
    primary: Color(0xFF2DD4BF),
    onPrimary: Color(0xFF04231F),
    primaryContainer: Color(0xFF134E4A),
    onPrimaryContainer: Color(0xFF99F6E4),
    accent: Color(0xFFFF8E72),
    onAccent: Color(0xFF3A1207),
    accentContainer: Color(0xFF4A2114),
    secondary: Color(0xFFE7ECF5),
    onSecondary: Color(0xFF0B1220),
    tertiary: Color(0xFFD9B86A),
    success: Color(0xFF4CB587),
    warning: Color(0xFFE2B25A),
    error: Color(0xFFF0706E),
    surface: Color(0xFF0B1020),
    surfaceVariant: Color(0xFF161C2D),
    card: Color(0xFF161C2D),
    outline: Color(0xFF252E44),
    outlineStrong: Color(0xFF38446A),
    onSurface: Color(0xFFEAF0FB),
    onSurfaceVariant: Color(0xFF9FABC4),
    textMuted: Color(0xFF8694AC),
    verified: Color(0xFF57C48C),
    verifiedContainer: Color(0xFF163A2A),
    onError: Color(0xFF420A0A),
    onSuccess: Color(0xFF04231A),
    onPhoto: Color(0xFFFFFFFF),
    photoOverlay: Color(0x8C05080F),
    scrim: Color(0x99000000),
    whatsapp: Color(0xFF25D366),
    onWhatsapp: Color(0xFF05301B),
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
    whatsapp: Color(0xFF1DAB61),
    onWhatsapp: Color(0xFFFFFFFF),
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
    whatsapp: Color(0xFF25D366),
    onWhatsapp: Color(0xFF05301B),
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
    required this.whatsapp,
    required this.onWhatsapp,
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

  /// WhatsApp contact CTA fill — the brand-recognizable green (Syria's primary
  /// contact channel). Light uses WhatsApp's UI green; dark brightens the fill
  /// and flips to a dark foreground, mirroring the success/onSuccess pattern.
  final Color whatsapp;

  /// Foreground on the [whatsapp] fill.
  final Color onWhatsapp;
}
