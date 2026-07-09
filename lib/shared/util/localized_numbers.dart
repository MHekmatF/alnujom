import 'dart:ui' show Locale;

import 'package:intl/intl.dart' as intl;

import 'arabic_digits.dart';

/// Phase 035 craft wave — ONE localized number pipeline for every on-screen
/// count/measure (rooms, bathrooms, areas, result counts, floors…).
///
/// Prices already go through `MoneyFormatter` (which post-processes to
/// Arabic-Indic under `ar`); every other number previously used bare
/// `NumberFormat.decimalPattern`, which keeps Western digits under `ar`
/// because intl's bundled `ar` data does. The result was mixed digit systems
/// on a single card (`٤٥٠٬٠٠٠ ل.س` price next to `120 م²` specs) — a top
/// "beginner tell" from the 035 UI audit. Route ALL of them through here.
String formatLocalizedNumber(num value, Locale locale) {
  final formatted = intl.NumberFormat.decimalPattern(
    locale.toLanguageTag(),
  ).format(value);
  if (locale.languageCode == 'ar') return toArabicIndicNumerals(formatted);
  return formatted;
}
