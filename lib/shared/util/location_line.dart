/// Phase 035 craft wave — ONE listing location line for every card/row.
///
/// The live app rendered `دمشق • دمشق` on most cards because it joined
/// *governorate • city* and both are named دمشق (same for حلب). The approved
/// design shows `city · area` (e.g. `دمشق · المزة`). This helper:
///  - prefers city (falls back to governorate when city is missing),
///  - appends the area when present and distinct,
///  - drops empties and the `—` placeholder,
///  - never repeats the same name twice.
String listingLocationLine({
  String? governorate,
  String? city,
  String? area,
  String separator = ' · ',
}) {
  String clean(String? s) {
    final t = s?.trim() ?? '';
    return t == '—' ? '' : t;
  }

  final g = clean(governorate);
  final c = clean(city);
  final a = clean(area);

  final first = c.isNotEmpty ? c : g;
  final parts = <String>[
    if (first.isNotEmpty) first,
    if (a.isNotEmpty && a != first) a,
  ];
  return parts.join(separator);
}
