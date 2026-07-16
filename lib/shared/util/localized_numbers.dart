import 'dart:ui' show Locale;

import 'package:intl/intl.dart' as intl;

/// DC "Blue Crown" design — ONE number pipeline for every on-screen
/// count/measure (rooms, bathrooms, areas, result counts, floors…).
///
/// The approved design (`AlNujom.dc.html`) uses **Western digits everywhere**
/// ("210 م²", "$195,000", "منذ 3 أيام") — matching what real Arabic
/// marketplace apps (Bayut, dubizzle, OpenSooq) ship. This supersedes the
/// Stage-2 Arabic-Indic pass. We format with Western grouping (comma
/// thousands) regardless of UI locale so the digits read identically to the
/// design in both `ar` and `en`.
String formatLocalizedNumber(num value, Locale locale) {
  return intl.NumberFormat.decimalPattern('en').format(value);
}
