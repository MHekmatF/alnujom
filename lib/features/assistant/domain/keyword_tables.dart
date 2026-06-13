// lib/features/assistant/domain/keyword_tables.dart
//
// Phase 28 (WS-6) — smart search assistant: the deterministic keyword tables
// the rule-based parser matches against. ZERO network / LLM cost by design.
//
// IMPORTANT — every Arabic key below is stored in its NORMALIZED form, i.e.
// after [normalizeQueryText] has run (ة→ه, أ/إ/آ→ا, ى→ي, diacritics/tatweel
// stripped, Latin lowercased). E.g. the dictionary word "شقة" is stored as
// "شقه" and "أرض" as "ارض". Keep new entries normalized the same way or they
// will never match.
//
// Property-type / purpose values map to the REAL enums in
// `lib/features/listing_form/domain/entities/listing.dart`
// (PropertyType: apartment|villa|land|shop|office|farm|warehouse|other;
// ListingPurpose: sale|rent|dailyRent|investment).

import '../../listing_form/domain/entities/listing.dart';

/// Property-type keywords (ar singular/plural + en singular/plural +
/// transliterations + common misspellings).
///
/// Deliberately UNMAPPED: the enum's `other` value — there is no generic-home
/// catch-all keyword that should resolve to it. NOTE: unlike earlier phases,
/// the generic-home words بيت/منزل/سكن/house/home/flat now map to `apartment`,
/// the overwhelmingly dominant residential type on this market; without a
/// "house" enum value, leaving them unmapped meant the single most common way
/// people say "a place to live" constrained nothing. `flat` is British-English
/// for apartment; `appt`/`apt`-style abbreviations are included.
///
/// REMINDER — keys are stored NORMALIZED (post-[normalizeQueryText]): ة→ه,
/// أ/إ/آ/ٱ→ا, ى→ي, diacritics/tatweel stripped, Latin lowercased. So "شقة" is
/// written "شقه", "فلة" as "فله", "قطعة" as "قطعه". A key written in raw
/// (un-folded) form would never match the normalized working text.
const Map<String, PropertyType> kPropertyTypeKeywords = {
  // ── apartment ── شقة/شقق + generic-home words + transliterations/misspellings.
  'شقه': PropertyType.apartment, // شقة (folded ة→ه)
  'شقق': PropertyType.apartment,
  'بيت': PropertyType.apartment, // generic "home/house" → dominant residential type
  'منزل': PropertyType.apartment,
  'سكن': PropertyType.apartment,
  'apartment': PropertyType.apartment,
  'apartments': PropertyType.apartment,
  'appartment': PropertyType.apartment, // common misspelling (double-p)
  'apartement': PropertyType.apartment, // French-influenced misspelling
  'aparment': PropertyType.apartment, // common misspelling (missing t)
  'appt': PropertyType.apartment, // abbreviation
  'apt': PropertyType.apartment, // abbreviation
  'flat': PropertyType.apartment, // British English
  'flats': PropertyType.apartment,
  'house': PropertyType.apartment,
  'houses': PropertyType.apartment,
  'home': PropertyType.apartment,
  'homes': PropertyType.apartment,
  // ── villa ── فيلا/فلل + transliterations/misspellings.
  'فيلا': PropertyType.villa,
  'فيللا': PropertyType.villa, // doubled-ل spelling
  'فله': PropertyType.villa, // فلة (folded ة→ه)
  'فلل': PropertyType.villa,
  'فيلات': PropertyType.villa,
  'قصر': PropertyType.villa, // "palace" — treated as a large standalone villa
  'villa': PropertyType.villa,
  'villas': PropertyType.villa,
  'vila': PropertyType.villa, // common misspelling (single l)
  'fila': PropertyType.villa, // transliteration of فلة
  'filla': PropertyType.villa, // transliteration variant
  // ── land ── أرض/أراضي + transliterations/misspellings.
  'ارض': PropertyType.land, // أرض (folded أ→ا)
  'اراضي': PropertyType.land, // أراضي (folded أ→ا)
  'مقسم': PropertyType.land, // subdivided plot
  'مقسوم': PropertyType.land,
  'قطعه': PropertyType.land, // قطعة (folded ة→ه) — "plot/parcel"
  'land': PropertyType.land,
  'lands': PropertyType.land,
  'plot': PropertyType.land,
  'parcel': PropertyType.land,
  // ── shop ── محل/محلات + transliterations.
  'محل': PropertyType.shop,
  'محلات': PropertyType.shop,
  'دكان': PropertyType.shop,
  'متجر': PropertyType.shop, // "store"
  'shop': PropertyType.shop,
  'shops': PropertyType.shop,
  'store': PropertyType.shop,
  'stores': PropertyType.shop,
  // ── office ── مكتب/مكاتب.
  'مكتب': PropertyType.office,
  'مكاتب': PropertyType.office,
  'office': PropertyType.office,
  'offices': PropertyType.office,
  // ── farm ── مزرعة/مزارع + orchard.
  'مزرعه': PropertyType.farm, // مزرعة (folded ة→ه)
  'مزارع': PropertyType.farm,
  'بستان': PropertyType.farm, // "orchard"
  'farm': PropertyType.farm,
  'farms': PropertyType.farm,
  // ── warehouse ── مستودع/مستودعات/مخزن + transliterations.
  'مستودع': PropertyType.warehouse,
  'مستودعات': PropertyType.warehouse,
  'مخزن': PropertyType.warehouse,
  'مخازن': PropertyType.warehouse,
  'warehouse': PropertyType.warehouse,
  'warehouses': PropertyType.warehouse,
  'depot': PropertyType.warehouse,
  'storage': PropertyType.warehouse,
};

/// Purpose keywords. When BOTH a rent keyword and a daily keyword match
/// ("اجار يومي", "daily rent") the parser resolves to [ListingPurpose.dailyRent]
/// — the more specific intent wins.
const Map<String, ListingPurpose> kPurposeKeywords = {
  // ── sale ── buying intent maps to sale (the listing's side of a purchase).
  'للبيع': ListingPurpose.sale,
  'بيع': ListingPurpose.sale,
  'للشراء': ListingPurpose.sale, // "for purchase" (buyer phrasing)
  'شراء': ListingPurpose.sale,
  'sale': ListingPurpose.sale,
  'forsale': ListingPurpose.sale, // no-space spelling
  'for sale': ListingPurpose.sale, // spaced spelling (normalizer keeps one space)
  'sell': ListingPurpose.sale,
  'buy': ListingPurpose.sale,
  // ── rent ── إيجار normalizes to ايجار (إ→ا); كراء is the Levantine/Maghrebi synonym.
  'للايجار': ListingPurpose.rent, // للإيجار (folded إ→ا)
  'ايجار': ListingPurpose.rent, // إيجار (folded إ→ا)
  'اجار': ListingPurpose.rent,
  'للاجار': ListingPurpose.rent,
  'كراء': ListingPurpose.rent, // colloquial "rent"
  'استئجار': ListingPurpose.rent,
  'rent': ListingPurpose.rent,
  'forrent': ListingPurpose.rent, // no-space spelling
  'for rent': ListingPurpose.rent, // spaced spelling (normalizer keeps one space)
  'rental': ListingPurpose.rent,
  'lease': ListingPurpose.rent,
  // ── dailyRent ── upgrades rent when paired (handled in the parser).
  'يومي': ListingPurpose.dailyRent,
  'يوميه': ListingPurpose.dailyRent, // يومية (folded ة→ه)
  'daily': ListingPurpose.dailyRent,
  // ── investment ──
  'استثمار': ListingPurpose.investment,
  'للاستثمار': ListingPurpose.investment,
  'investment': ListingPurpose.investment,
  'invest': ListingPurpose.investment,
};

/// Magnitude words/suffixes → multiplication factor. Single-letter Latin
/// suffixes (k/m/b) are only matched when directly attached or adjacent to a
/// number by the parser's number regex ("500m", "750 k").
const Map<String, double> kMagnitudeKeywords = {
  'الف': 1e3,
  'الاف': 1e3,
  'thousand': 1e3,
  'thousands': 1e3,
  'k': 1e3,
  'مليون': 1e6,
  'ملايين': 1e6,
  'million': 1e6,
  'millions': 1e6,
  'm': 1e6,
  'mn': 1e6,
  'مليار': 1e9,
  'مليارات': 1e9,
  'billion': 1e9,
  'billions': 1e9,
  'b': 1e9,
  'bn': 1e9,
};

/// Comparator phrases that turn the following number into an UPPER price
/// bound. NOTE: "حتى" normalizes to "حتي" (ى→ي).
const List<String> kMaxComparators = [
  'اقل من',
  'تحت',
  'حتي',
  'بحدود',
  'لغايه',
  'اقصي',
  'under',
  'below',
  'less than',
  'up to',
  'at most',
  'max',
  'within',
];

/// Comparator phrases that turn the following number into a LOWER price bound.
const List<String> kMinComparators = [
  'اكثر من',
  'فوق',
  'ابتداء من',
  'over',
  'above',
  'more than',
  'at least',
  'min',
  'starting from',
];

/// Range openers ("بين X و Y", "من X الى Y", "between X and Y").
/// NOTE: "الى" normalizes to "الي".
const List<String> kRangeOpeners = ['بين', 'من', 'between', 'from'];

/// Range connectors between the two numbers.
const List<String> kRangeConnectors = ['و', 'الي', 'and', 'to'];

/// Currency keywords → ISO-ish currency codes used by `FilterState.priceCurrency`
/// and `listing_prices.currency_code`. The bare `$` sign is handled separately
/// by the parser. Heuristic (documented in the parser): a price with a
/// مليون/مليار-scale magnitude and NO explicit currency defaults to SYP.
const Map<String, String> kCurrencyKeywords = {
  'دولار': 'USD',
  'دولارات': 'USD',
  'dollar': 'USD',
  'dollars': 'USD',
  'usd': 'USD',
  'ليره': 'SYP',
  'ليرات': 'SYP',
  'ل س': 'SYP',
  'syp': 'SYP',
  'سوري': 'SYP',
  'سوريه': 'SYP',
};

/// Rooms unit words; a preceding integer becomes `FilterState.rooms`.
const List<String> kRoomUnits = ['غرف', 'غرفه', 'rooms', 'room', 'bedrooms', 'bedroom', 'br'];

/// Arabic counted-word forms for rooms (no digit present).
const Map<String, int> kRoomWordCounts = {
  'غرفتين': 2,
  'ثلاث غرف': 3,
  'اربع غرف': 4,
  'خمس غرف': 5,
  'ست غرف': 6,
};

/// Bathrooms unit words; a preceding integer becomes `FilterState.bathrooms`.
const List<String> kBathUnits = ['حمامات', 'حمام', 'bathrooms', 'bathroom', 'baths', 'bath'];

/// Arabic counted-word forms for bathrooms.
const Map<String, int> kBathWordCounts = {'حمامين': 2};

/// Market-stats intent markers. Bare "سعر"/"price" is deliberately EXCLUDED:
/// it appears in ordinary budget phrasings ("بسعر 500 مليون") that should run
/// the normal search path, not the stats RPC.
const List<String> kStatsKeywords = [
  'متوسط',
  'اسعار',
  'بكم',
  'كم',
  'يكلف',
  'تكلفه',
  'average',
  'avg',
  'prices',
  'cost',
  'how much',
];
