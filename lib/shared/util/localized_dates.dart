// Plan A33 — dates in the reader's own calendar words.
//
// `intl`'s Arabic locale data says يونيو; Syria says حزيران. Every screen
// already formats through `DateFormat(..., locale)`, so the fix is one
// in-place patch of the Arabic symbol table rather than twenty call sites:
// after Flutter's localizations delegate loads `ar` (which rewrites the
// table), swap the month names for the Levantine set. Idempotent, cheap, and
// called from the app shell on every build so a locale switch back to Arabic
// re-applies it.
//
// Digits stay Western on purpose (see localized_numbers.dart).
import 'dart:ui' show Locale;

import 'package:intl/date_symbol_data_local.dart' show dateTimeSymbolMap;
import 'package:intl/intl.dart' as intl;

/// The Levantine month names, January first.
const List<String> kLevantineMonths = [
  'كانون الثاني',
  'شباط',
  'آذار',
  'نيسان',
  'أيار',
  'حزيران',
  'تموز',
  'آب',
  'أيلول',
  'تشرين الأول',
  'تشرين الثاني',
  'كانون الأول',
];

/// Makes every Arabic `DateFormat` in the process say حزيران, not يونيو.
/// Safe to call on every frame; does nothing once the table is patched.
void ensureLevantineArabicDateSymbols() {
  final symbols = dateTimeSymbolMap()['ar'];
  if (symbols == null || symbols.MONTHS[5] == kLevantineMonths[5]) return;
  symbols
    ..MONTHS = kLevantineMonths
    ..STANDALONEMONTHS = kLevantineMonths
    ..SHORTMONTHS = kLevantineMonths
    ..STANDALONESHORTMONTHS = kLevantineMonths;
}

/// A calendar date the way the current locale writes it ("5 أيلول 2026",
/// "Sep 5, 2026"). For the places that used to print a bare ISO string.
String formatLocalizedDate(DateTime when, Locale locale) {
  ensureLevantineArabicDateSymbols();
  return intl.DateFormat.yMMMd(locale.toString()).format(when.toLocal());
}
