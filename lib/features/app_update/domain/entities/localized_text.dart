import 'dart:ui';

/// A bilingual text value with an Arabic and an English variant.
///
/// Mirrors the Phase 23 `LocalizedText` in `features/settings/domain/entities/`
/// but re-declared here to keep `app_update` domain-self-contained (no
/// cross-feature import required — Principle IX).
class LocalizedText {
  const LocalizedText({this.ar, this.en});

  /// Arabic text variant.
  final String? ar;

  /// English text variant.
  final String? en;

  /// Returns the text for the given [locale].
  ///
  /// Resolution order:
  /// 1. The value for the active locale's language code (`ar` or `en`).
  /// 2. The other variant if the active one is null/empty.
  /// 3. `null` if both are unset — callers should fall back to built-in copy.
  String? forLocale(Locale locale) {
    final primary = locale.languageCode == 'ar' ? ar : en;
    if (primary != null && primary.isNotEmpty) return primary;
    final fallback = locale.languageCode == 'ar' ? en : ar;
    if (fallback != null && fallback.isNotEmpty) return fallback;
    return null;
  }

  @override
  String toString() => 'LocalizedText(ar: $ar, en: $en)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalizedText &&
          runtimeType == other.runtimeType &&
          ar == other.ar &&
          en == other.en;

  @override
  int get hashCode => ar.hashCode ^ en.hashCode;
}
