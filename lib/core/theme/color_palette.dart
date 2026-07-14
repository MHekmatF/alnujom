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
      secondaryContainer: tokens.secondaryContainer,
      onSecondaryContainer: tokens.onSecondaryContainer,
      tertiary: tokens.tertiary,
      onTertiary: onTertiary,
      tertiaryContainer: tokens.accentContainer,
      onTertiaryContainer: onTertiary,
      error: tokens.error,
      onError: tokens.onError,
      errorContainer: tokens.errorContainer,
      onErrorContainer: tokens.onErrorContainer,
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

  // Phase 033 — "Steel & Star" light language, matched to the orbit logo. Cool
  // off-white surfaces (#F5F7FA) + crisp white cards; a confident royal BLUE
  // (#1F4FE6) is the PRIMARY UI accent (links, icons, active states, price —
  // AA-legible as text on the cool surface), GOLD (#C2A14D) stays the
  // premium/featured signature (tertiary — featured badges only), coral marks
  // favorites, and the green/WhatsApp trust signals are preserved. Slate ink
  // ramp (#0F172A → #475569 → #64748B). Gold is never used as link/label text
  // (fails contrast) — only as a fill behind dark ink or a badge tint. WCAG AA.
  @override
  AppPaletteTokens get _lightTokens => const AppPaletteTokens(
    // DC "Blue Crown" (AlNujom.dc.html, founder-approved) — royal blue #1F4FE6
    // on a cool blue-grey app bg; white cards + hairlines; a deep-blue crown
    // header. Exact values transcribed in specs/035-.../DESIGN-DC.md.
    primary: Color(0xFF1F4FE6),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE2E9FF), // --tonal
    onPrimaryContainer: Color(0xFF123287), // --onTonal
    accent: Color(0xFFFF5B6E), // saved-heart pink
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFFFFE1E6),
    secondary: Color(0xFF0F172A),
    onSecondary: Color(0xFFFFFFFF),
    tertiary: Color(0xFF8A6912), // --gold (featured text/icon)
    success: Color(0xFF0E7A3C), // --green == verified
    warning: Color(0xFFC98318),
    error: Color(0xFFD93B3B), // --red (badges + errors)
    surface: Color(0xFFEAEDF2), // --bg (scaffold)
    surfaceVariant: Color(0xFFF2F4F9), // --surface2
    card: Color(0xFFFFFFFF), // --surface
    outline: Color(0xFFE7EAF1), // --divider (card borders, hairlines)
    outlineStrong: Color(0xFFC6CAD6), // --outline (chip/segment/button borders)
    onSurface: Color(0xFF1A1C22), // --on
    onSurfaceVariant: Color(0xFF5B6070), // --onVar
    textMuted: Color(0xFF5B6070),
    verified: Color(0xFF0E7A3C),
    verifiedContainer: Color(0xFFE4F3E9), // --greenC
    onError: Color(0xFFFFFFFF),
    onSuccess: Color(0xFF0A5A2C), // --onGreenC
    onPhoto: Color(0xFFFFFFFF),
    photoOverlay: Color(0x6B0F121E), // --scrim rgba(15,18,30,.42)
    scrim: Color(0x6B0F121E),
    whatsapp: Color(0xFF1FA855), // --wa
    onWhatsapp: Color(0xFFFFFFFF),
    brandHeader: Color(0xFF1A3FC4), // --header / --statusbg
    onBrandHeader: Color(0xFFFFFFFF),
    brandHeaderField: Color(0xFFFFFFFF), // --headerField
    secondaryContainer: Color(0xFFDAE1F6), // --sec
    onSecondaryContainer: Color(0xFF182C58), // --onSec
    verifiedBorder: Color(0xFFC3E4CF), // --greenBorder
    goldContainer: Color(0xFFFBEDC7), // --goldC
    errorContainer: Color(0xFFFBE6E6), // --redC
    onErrorContainer: Color(0xFFB42318), // --onRedC
  );

  // Phase 033 — dark midnight-navy surfaces (#0B1020 + elevated #161C2D cards)
  // carrying the Steel & Star BLUE accent for consistency with light + the orbit
  // logo: a bright azure (#5896FF) primary that glows on key CTAs / the active
  // nav (glow added at the widget layer) and takes DARK ink (#06122B) on fills,
  // a warm gold featured accent, coral favorites, green/WhatsApp trust. WCAG AA.
  @override
  AppPaletteTokens get _darkTokens => const AppPaletteTokens(
    // DC "Blue Crown" dark — near-black surfaces (#0C0C10), a bright azure
    // primary (#AEC2FF) that takes dark ink on fills, a deep-navy crown.
    primary: Color(0xFFAEC2FF),
    onPrimary: Color(0xFF0A2063),
    primaryContainer: Color(0xFF26356E), // --tonal dark
    onPrimaryContainer: Color(0xFFDCE4FF), // --onTonal dark
    accent: Color(0xFFFF5B6E), // saved-heart pink (both themes)
    onAccent: Color(0xFFFFFFFF),
    accentContainer: Color(0xFF4A1420),
    secondary: Color(0xFFE7E8ED),
    onSecondary: Color(0xFF0B1220),
    tertiary: Color(0xFFE6C56A), // --gold dark
    success: Color(0xFF74D99A), // --green dark
    warning: Color(0xFFE2B25A),
    error: Color(0xFFFF6B6B), // --red dark
    surface: Color(0xFF0C0C10), // --bg dark
    surfaceVariant: Color(0xFF1C1D25), // --surface2 dark
    card: Color(0xFF131318), // --surface dark
    outline: Color(0xFF26272F), // --divider dark
    outlineStrong: Color(0xFF3B3D48), // --outline dark
    onSurface: Color(0xFFE7E8ED), // --on dark
    onSurfaceVariant: Color(0xFFA7ABB8), // --onVar dark
    textMuted: Color(0xFFA7ABB8),
    verified: Color(0xFF74D99A),
    verifiedContainer: Color(0xFF12331F), // --greenC dark
    onError: Color(0xFF3A0A0A), // --onRed dark
    onSuccess: Color(0xFFA9E9C0), // --onGreenC dark
    onPhoto: Color(0xFFFFFFFF),
    photoOverlay: Color(0x80000000), // --scrim dark rgba(0,0,0,.5)
    scrim: Color(0x80000000),
    whatsapp: Color(0xFF2AAE60), // --wa dark
    onWhatsapp: Color(0xFFFFFFFF),
    brandHeader: Color(0xFF12235E), // --header dark
    onBrandHeader: Color(0xFFFFFFFF),
    brandHeaderField: Color(0xFF20232C), // --headerField dark
    secondaryContainer: Color(0xFF2A3352), // --sec dark
    onSecondaryContainer: Color(0xFFDEE4FA), // --onSec dark
    verifiedBorder: Color(0xFF1E4A30), // --greenBorder dark
    goldContainer: Color(0xFF39300B), // --goldC dark
    errorContainer: Color(0xFF3A1414), // --redC dark
    onErrorContainer: Color(0xFFFF9B9B), // --onRedC dark
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
    // DC design (Blue Crown) brand roles — optional with const defaults so the
    // dev-only TrustPalette and older callers keep compiling. ModernPalette
    // passes the exact values from DESIGN-DC.md.
    this.brandHeader = const Color(0xFF1A3FC4),
    this.onBrandHeader = const Color(0xFFFFFFFF),
    this.brandHeaderField = const Color(0xFFFFFFFF),
    this.secondaryContainer = const Color(0xFFDAE1F6),
    this.onSecondaryContainer = const Color(0xFF182C58),
    this.verifiedBorder = const Color(0xFFC3E4CF),
    this.goldContainer = const Color(0xFFFBEDC7),
    this.errorContainer = const Color(0xFFFBE6E6),
    this.onErrorContainer = const Color(0xFFB42318),
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

  /// DC "Blue Crown" — the deep-blue brand header zone (crown) + tinted status
  /// bar. The signature of the design.
  final Color brandHeader;

  /// Foreground (logo/icons/text) on the [brandHeader] (white in both themes).
  final Color onBrandHeader;

  /// The search field that sits inside the [brandHeader] crown.
  final Color brandHeaderField;

  /// Selected-state container: segmented control, bottom-nav pill, toggle-on
  /// chip, detail "للبيع" tag. Maps to Material `secondaryContainer`.
  final Color secondaryContainer;

  /// Foreground on [secondaryContainer].
  final Color onSecondaryContainer;

  /// Border of the field-verification card on the detail page (green tint).
  final Color verifiedBorder;

  /// Container behind the gold "مميّز" featured badge (foreground = [tertiary]).
  final Color goldContainer;

  /// Container behind a soft "rejected / declined / error" status chip
  /// (DC `--redC`). Foreground = [onErrorContainer].
  final Color errorContainer;

  /// Foreground (text/icon) on [errorContainer] (DC `--onRedC`).
  final Color onErrorContainer;
}
