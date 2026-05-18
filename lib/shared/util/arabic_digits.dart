/// Post-processes a number string formatted by `intl.NumberFormat` for the
/// `ar` locale. The intl package's bundled `ar` data uses Western digits
/// (`ZERO_DIGIT: '0'`) because CLDR defaults `ar` to Latin numerals for
/// pragmatic reasons. AlNujom's Syrian audience reads Arabic-Indic digits in
/// monetary and rate contexts, so we substitute after intl has placed the
/// separators.
///
/// Conversions:
///   ASCII 0..9 → ٠..٩ (U+0660..U+0669)
///   ',' → ٬ (U+066C, Arabic thousands separator)
///   '.' → ٫ (U+066B, Arabic decimal separator)
/// Other characters (including the U+200E LRM that intl emits before minus
/// signs) pass through unchanged so RTL bidi behavior is preserved.
library;

const _arabicIndicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
const _arabicGroupSeparator = '٬';
const _arabicDecimalSeparator = '٫';

String toArabicIndicNumerals(String input) {
  final buf = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x30 && rune <= 0x39) {
      buf.write(_arabicIndicDigits[rune - 0x30]);
    } else if (rune == 0x2C) {
      buf.write(_arabicGroupSeparator);
    } else if (rune == 0x2E) {
      buf.write(_arabicDecimalSeparator);
    } else {
      buf.writeCharCode(rune);
    }
  }
  return buf.toString();
}
