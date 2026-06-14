// lib/features/assistant/domain/query_parser.dart
//
// Phase 28 (WS-6) — smart search assistant: the deterministic, pure-Dart
// natural-language → FilterState parser. NO network, NO LLM — a fixed
// pipeline over the keyword tables in `keyword_tables.dart`:
//
//   1. normalize   — Arabic-Indic digits → ASCII, strip tatweel/diacritics,
//                    fold أ/إ/آ→ا, ة→ه, ى→ي, lowercase Latin, collapse spaces.
//   2. rooms/baths — "<n> غرف", "غرفتين", "3 rooms"… (consumed so the numbers
//                    can't be re-read as prices).
//   3. purpose / property type — earliest keyword match wins; "يومي"/"daily"
//                    upgrades rent → dailyRent.
//   4. governorate — runtime list injected by the brain; normalized ar+en
//                    display names matched on word boundaries, longest wins.
//   5. price       — "بين X و Y" ranges, otherwise comparator window before
//                    the number (تحت/under → max, فوق/over → min; default max
//                    because people state budgets as ceilings), magnitudes
//                    (الف/مليون/مليار/k/m/bn) and currency markers ($, دولار,
//                    ليرة…). Bare مليون+ with no currency → SYP (Syrian
//                    market convention).
//   6. stats intent — متوسط/اسعار/كم/average/cost… flags the question for the
//                    market-stats RPC path in the brain.
//
// Every recognized span is echoed back as a MatchedFragment chip so the user
// can SEE what was understood (and what wasn't).

import 'package:injectable/injectable.dart';

import '../../listing_form/domain/entities/listing.dart';
import '../../locations/domain/entities/area.dart';
import '../../locations/domain/entities/city.dart';
import '../../locations/domain/entities/governorate.dart';
import '../../search/domain/entities/count_filter_mode.dart';
import '../../search/domain/entities/filter_state.dart';
import 'entities/parsed_query.dart';
import 'keyword_tables.dart';

/// Word characters for boundary checks: ASCII digits/letters + the Arabic
/// block. Dart's `\b` only understands ASCII `\w`, so we roll our own
/// lookarounds.
const String _wordChars = r'0-9a-z؀-ۿ';

/// Optional Arabic proclitics (definite article + connectives) tolerated in
/// front of a keyword: matches بالشام، والمكتب، للبيع، بدمشق… Longest first.
const String _arabicPrefixes = 'وبال|وال|بال|فال|كال|لل|ال|وب|ب|و|ل|ف';

/// Normalizes free-form user input for table matching. See pipeline doc above.
String normalizeQueryText(String input) {
  final buf = StringBuffer();
  for (final rune in input.runes) {
    // Arabic-Indic ٠-٩ and Eastern Arabic-Indic ۰-۹ → ASCII digits.
    if (rune >= 0x0660 && rune <= 0x0669) {
      buf.writeCharCode(0x30 + (rune - 0x0660));
      continue;
    }
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      buf.writeCharCode(0x30 + (rune - 0x06F0));
      continue;
    }
    // Arabic decimal separator ٫ → '.', thousands separator ٬ dropped.
    if (rune == 0x066B) {
      buf.write('.');
      continue;
    }
    if (rune == 0x066C) continue;
    // Tatweel + harakat/diacritics dropped.
    if (rune == 0x0640) continue;
    if ((rune >= 0x064B && rune <= 0x065F) || rune == 0x0670) continue;
    // Letter folds: أ/إ/آ/ٱ → ا, ة → ه, ى → ي.
    switch (rune) {
      case 0x0622:
      case 0x0623:
      case 0x0625:
      case 0x0671:
        buf.write('ا');
        continue;
      case 0x0629:
        buf.write('ه');
        continue;
      case 0x0649:
        buf.write('ي');
        continue;
    }
    buf.writeCharCode(rune);
  }
  var s = buf.toString().toLowerCase();
  // Thousands separators inside numbers: 1,500,000 / ١،٥٠٠ → digits only.
  s = s.replaceAll(RegExp('(?<=[0-9])[,،](?=[0-9])'), '');
  // Dots that are NOT decimal points → space (so "ل.س" → "ل س").
  s = s.replaceAll(RegExp(r'\.(?![0-9])'), ' ');
  // Punctuation → space ('$' deliberately preserved as a currency marker).
  s = s.replaceAll(RegExp(r'[،؛؟!,;:()\[\]{}"«»<>|+*=~^&%#@_/\\-]'), ' ');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

/// Boundary-safe keyword regex (tolerates Arabic proclitic prefixes).
RegExp _keywordRe(String normalizedKeyword) {
  final escaped = RegExp.escape(normalizedKeyword);
  return RegExp(
    '(?<![$_wordChars])(?:$_arabicPrefixes)?$escaped(?![$_wordChars])',
  );
}

class _NumToken {
  _NumToken(this.value, this.magnitude, this.start, this.end);

  final double value; // already multiplied by magnitude
  final double magnitude; // 1 when no magnitude word
  final int start;
  final int end;
}

/// Deterministic natural-language query parser. Stateless and synchronous —
/// the brain supplies the runtime governorate list. Registered in DI so the
/// brain gets it constructor-injected like every other collaborator.
@injectable
class QueryParser {
  const QueryParser();

  static final RegExp _numberRe = RegExp(
    r'(\d+(?:\.\d+)?)\s*'
    r'(مليارات|مليار|ملايين|مليون|الاف|الف|thousands|thousand|millions|million|billions|billion|mn|bn|k|m|b)?'
    '(?![$_wordChars])',
  );

  ParsedQuery parse(
    String rawInput, {
    List<Governorate> governorates = const [],
    List<City> cities = const [],
    List<Area> areas = const [],
  }) {
    final normalized = normalizeQueryText(rawInput);
    if (normalized.isEmpty) return ParsedQuery.empty;

    // `working` gets matched spans blanked out so a number consumed by the
    // rooms matcher can never be re-read as a price.
    var working = normalized;

    // ── area size (m²) ──
    // MUST run before rooms/baths and price so its number is consumed and can
    // never be re-read as a room count or a budget. Distinguished from price
    // purely by an adjacent area-size unit (متر / م2 / sqm / مساحه …).
    double? areaSizeMin;
    double? areaSizeMax;
    String? areaSizeText;
    (areaSizeMin, areaSizeMax, areaSizeText, working) = _matchAreaSize(working);

    // ── "at least" intent (global, one-shot) ──
    // A single at-least phrase (على الأقل / ما لا يقل عن / at least / …) OR a
    // trailing "+" on a digit in the RAW input flips the matched rooms/baths
    // counts to atLeast. We read the raw input for "+": the normalizer turns
    // "3+" into "3 ", so the marker is gone from `working`.
    final atLeast =
        _hasAtLeastPhrase(normalized) || RegExp(r'\d\s*\+').hasMatch(rawInput);
    final countMode = atLeast
        ? CountFilterMode.atLeast
        : CountFilterMode.exactly;

    // ── rooms / bathrooms ──
    String? roomsText;
    int? rooms;
    (rooms, roomsText, working) = _matchCount(
      working,
      units: kRoomUnits,
      wordCounts: kRoomWordCounts,
    );

    String? bathText;
    int? bathrooms;
    (bathrooms, bathText, working) = _matchCount(
      working,
      units: kBathUnits,
      wordCounts: kBathWordCounts,
    );

    // ── purpose (daily upgrades rent) ──
    ListingPurpose? purpose;
    String? purposeText;
    var purposePos = 1 << 30;
    var dailyMatched = false;
    String? dailyText;
    for (final entry in kPurposeKeywords.entries) {
      final m = _keywordRe(entry.key).firstMatch(working);
      if (m == null) continue;
      if (entry.value == ListingPurpose.dailyRent) {
        dailyMatched = true;
        dailyText ??= m.group(0);
      } else if (m.start < purposePos) {
        purposePos = m.start;
        purpose = entry.value;
        purposeText = m.group(0);
      }
    }
    if (dailyMatched) {
      // "اجار يومي" / "daily rent" — the more specific intent wins.
      purpose = ListingPurpose.dailyRent;
      purposeText = (purposeText != null && dailyText != null)
          ? '$purposeText $dailyText'
          : (dailyText ?? purposeText);
    }

    // ── property type (earliest match wins) ──
    PropertyType? propertyType;
    String? typeText;
    var typePos = 1 << 30;
    for (final entry in kPropertyTypeKeywords.entries) {
      final m = _keywordRe(entry.key).firstMatch(working);
      if (m != null && m.start < typePos) {
        typePos = m.start;
        propertyType = entry.value;
        typeText = m.group(0);
      }
    }
    // Guarded typo-tolerance fallback. ONLY runs when exact matching found no
    // property type — it can never override an exact match. We scan LATIN
    // tokens (Arabic typos are covered by normalization folding; Arabic fuzzy
    // matching is too risky given short, dense roots) of length >= 4 and adopt
    // a type only when there is an UNAMBIGUOUS nearest keyword at edit distance
    // <= 1. See [_fuzzyPropertyType] for the exact guard.
    if (propertyType == null) {
      final (fuzzyType, fuzzyText) = _fuzzyPropertyType(working);
      if (fuzzyType != null) {
        propertyType = fuzzyType;
        typeText = fuzzyText;
      }
    }

    // ── governorate (longest display-name match wins) ──
    Governorate? governorate;
    String? governorateText;
    var bestNameLen = 0;
    for (final gov in governorates) {
      for (final name in gov.displayName.values) {
        final normalizedName = normalizeQueryText(name);
        if (normalizedName.isEmpty || normalizedName.length <= bestNameLen) {
          continue;
        }
        final m = _keywordRe(normalizedName).firstMatch(working);
        if (m != null) {
          bestNameLen = normalizedName.length;
          governorate = gov;
          governorateText = m.group(0);
        }
      }
    }

    // ── city (within the matched governorate when one matched, else anywhere) ──
    // A matched city also PINS its governorate, so naming only a city
    // ("شقة بجرمانا") still resolves the governorate filter. Longest display-name
    // match wins, mirroring the governorate logic + the same normalize/boundary
    // rules. When a governorate matched, we only consider its own cities so a
    // namesake city in another governorate can't override the explicit one.
    City? city;
    String? cityText;
    var bestCityLen = 0;
    for (final c in cities) {
      if (governorate != null && c.governorateId != governorate.id) continue;
      for (final name in c.displayName.values) {
        final normalizedName = normalizeQueryText(name);
        if (normalizedName.isEmpty || normalizedName.length <= bestCityLen) {
          continue;
        }
        final m = _keywordRe(normalizedName).firstMatch(working);
        if (m != null) {
          bestCityLen = normalizedName.length;
          city = c;
          cityText = m.group(0);
        }
      }
    }
    // A city named without its governorate resolves the governorate too.
    if (city != null && governorate == null) {
      for (final gov in governorates) {
        if (gov.id == city.governorateId) {
          governorate = gov;
          break;
        }
      }
    }

    // ── area / neighborhood (within the matched city when one matched) ──
    // Same scope-narrowing as cities: once a city is known, only its areas are
    // candidates. A matched area also pins its city (and thus governorate).
    Area? area;
    String? areaText;
    var bestAreaLen = 0;
    for (final a in areas) {
      if (city != null && a.cityId != city.id) continue;
      for (final name in a.displayName.values) {
        final normalizedName = normalizeQueryText(name);
        if (normalizedName.isEmpty || normalizedName.length <= bestAreaLen) {
          continue;
        }
        final m = _keywordRe(normalizedName).firstMatch(working);
        if (m != null) {
          bestAreaLen = normalizedName.length;
          area = a;
          areaText = m.group(0);
        }
      }
    }
    // An area named without its city resolves the city (and governorate) too.
    if (area != null && city == null) {
      for (final c in cities) {
        if (c.id == area.cityId) {
          city = c;
          for (final gov in governorates) {
            if (gov.id == c.governorateId) {
              governorate = gov;
              break;
            }
          }
          break;
        }
      }
    }

    // ── amenities / feature flags ──
    bool? furnished;
    bool? parking;
    final amenitySet = <String>{};
    final amenityFragments = <String>[];
    for (final entry in kAmenityKeywords.entries) {
      final m = _keywordRe(entry.key).firstMatch(working);
      if (m == null) continue;
      final value = entry.value;
      if (value == kAmenityFurnishedSentinel) {
        furnished = true;
      } else if (value == kAmenityParkingSentinel) {
        parking = true;
      } else {
        if (!amenitySet.contains(value)) {
          amenityFragments.add(m.group(0)!);
        }
        amenitySet.add(value);
      }
      // Surface furnished/parking words as chips too (the user's own word).
      if (value == kAmenityFurnishedSentinel ||
          value == kAmenityParkingSentinel) {
        amenityFragments.add(m.group(0)!);
      }
    }

    // ── currency markers ──
    String? currencyCode;
    String? currencyText;
    if (working.contains(r'$')) {
      currencyCode = 'USD';
      currencyText = r'$';
    } else {
      for (final entry in kCurrencyKeywords.entries) {
        final m = _keywordRe(entry.key).firstMatch(working);
        if (m != null) {
          currencyCode = entry.value;
          currencyText = m.group(0);
          break;
        }
      }
    }

    // ── price ──
    double? priceMin;
    double? priceMax;
    String? priceText;
    var priceMagnitude = 1.0;

    final nums = _numberRe
        .allMatches(working)
        .map(
          (m) => _NumToken(
            (double.tryParse(m.group(1)!) ?? 0) *
                (kMagnitudeKeywords[m.group(2)] ?? 1),
            kMagnitudeKeywords[m.group(2)] ?? 1,
            m.start,
            m.end,
          ),
        )
        .toList(growable: false);

    if (nums.length >= 2 && _isRange(working, nums[0], nums[1])) {
      var lo = nums[0].value;
      var hi = nums[1].value;
      // "بين 100 و 200 الف" — the first number inherits the second's
      // magnitude when it has none of its own.
      if (nums[0].magnitude == 1 && nums[1].magnitude > 1) {
        lo = lo * nums[1].magnitude;
      }
      if (lo > hi) {
        final tmp = lo;
        lo = hi;
        hi = tmp;
      }
      // Plausibility: a bare tiny range ("بين 2 و 3") is not a price.
      if (hi >= 1000 ||
          nums[1].magnitude > 1 ||
          nums[0].magnitude > 1 ||
          currencyCode != null) {
        priceMin = lo;
        priceMax = hi;
        priceMagnitude = nums[1].magnitude > 1
            ? nums[1].magnitude
            : nums[0].magnitude;
        final fragStart = _rangeOpenerStart(working, nums[0].start);
        priceText = _tidy(working.substring(fragStart, nums[1].end));
      }
    }

    if (priceMin == null && priceMax == null) {
      for (final n in nums) {
        final isCandidate =
            n.magnitude > 1 || n.value >= 1000 || currencyCode != null;
        if (!isCandidate) continue;
        final (isMin, compStart) = _comparatorBefore(working, n.start);
        if (isMin) {
          priceMin = n.value;
        } else {
          // Default: a stated budget is a ceiling.
          priceMax = n.value;
        }
        priceMagnitude = n.magnitude;
        priceText = _tidy(working.substring(compStart, n.end));
        break;
      }
    }

    final hasPrice = priceMin != null || priceMax != null;
    // Heuristic (Syrian market convention): a مليون/مليار-scale figure with
    // no explicit currency is in Syrian pounds.
    if (hasPrice && currencyCode == null && priceMagnitude >= 1e6) {
      currencyCode = 'SYP';
    }

    // ── stats intent ──
    var statsIntent = false;
    for (final kw in kStatsKeywords) {
      if (_keywordRe(kw).firstMatch(normalized) != null) {
        statsIntent = true;
        break;
      }
    }

    final hasAreaSize = areaSizeMin != null || areaSizeMax != null;

    // ── assemble ──
    final fragments = <MatchedFragment>[
      if (typeText != null)
        MatchedFragment(AssistantFragmentKind.propertyType, typeText),
      if (purposeText != null)
        MatchedFragment(AssistantFragmentKind.purpose, purposeText),
      if (governorateText != null)
        MatchedFragment(AssistantFragmentKind.location, governorateText),
      if (cityText != null)
        MatchedFragment(AssistantFragmentKind.city, cityText),
      if (areaText != null)
        MatchedFragment(AssistantFragmentKind.area, areaText),
      if (rooms != null && roomsText != null)
        MatchedFragment(AssistantFragmentKind.rooms, roomsText),
      if (bathrooms != null && bathText != null)
        MatchedFragment(AssistantFragmentKind.bathrooms, bathText),
      if (areaSizeText != null)
        MatchedFragment(AssistantFragmentKind.areaSize, areaSizeText),
      if (priceText != null)
        MatchedFragment(AssistantFragmentKind.price, priceText),
      if (hasPrice && currencyText != null)
        MatchedFragment(AssistantFragmentKind.currency, currencyText),
      for (final word in amenityFragments)
        MatchedFragment(AssistantFragmentKind.amenity, word),
    ];

    final filters = FilterState(
      purpose: purpose,
      propertyType: propertyType,
      governorateId: governorate?.id,
      cityId: city?.id,
      areaId: area?.id,
      priceMin: priceMin,
      priceMax: priceMax,
      priceCurrency: hasPrice ? currencyCode : null,
      rooms: rooms,
      roomsMode: rooms != null ? countMode : CountFilterMode.exactly,
      bathrooms: bathrooms,
      bathroomsMode: bathrooms != null ? countMode : CountFilterMode.exactly,
      areaSizeMin: areaSizeMin,
      areaSizeMax: areaSizeMax,
      furnished: furnished,
      parking: parking,
      amenities: amenitySet,
    );

    final dimensions = [
      propertyType,
      purpose,
      governorate,
      city,
      area,
      rooms,
      bathrooms,
      if (hasPrice) true,
      if (hasAreaSize) true,
      furnished,
      parking,
      if (amenitySet.isNotEmpty) true,
    ].whereType<Object>().length;

    return ParsedQuery(
      filters: filters,
      fragments: fragments,
      // Heuristic, not a probability: 1 dim ≈ 0.5, 3+ dims ≈ certain.
      confidence: dimensions == 0
          ? 0
          : (0.2 + dimensions * 0.27).clamp(0.0, 1.0).toDouble(),
      statsIntent: statsIntent,
      governorate: governorate,
    );
  }

  /// Matches `<n> <unit>` and Arabic counted-word forms; returns the count,
  /// the matched text and the input with the span blanked out.
  (int?, String?, String) _matchCount(
    String working, {
    required List<String> units,
    required Map<String, int> wordCounts,
  }) {
    final unitAlt = units.map(RegExp.escape).join('|');
    final re = RegExp(
      '(?<![0-9.])([0-9]+)\\s*(?:$unitAlt)(?![$_wordChars])',
    );
    final m = re.firstMatch(working);
    if (m != null) {
      return (
        int.tryParse(m.group(1)!),
        _tidy(m.group(0)!),
        _blank(working, m.start, m.end),
      );
    }
    for (final entry in wordCounts.entries) {
      final wm = _keywordRe(entry.key).firstMatch(working);
      if (wm != null) {
        return (
          entry.value,
          _tidy(wm.group(0)!),
          _blank(working, wm.start, wm.end),
        );
      }
    }
    return (null, null, working);
  }

  /// Pre-compiled alternation of area-size unit markers (longest first so
  /// multi-token forms like "sq m" win over "m").
  static final String _areaUnitAlt = (kAreaSizeUnits.toList()
        ..sort((a, b) => b.length.compareTo(a.length)))
      .map(RegExp.escape)
      .join('|');

  /// A number directly followed by an area-size unit: "150 متر", "200م2",
  /// "180 sqm". The unit must be on a word boundary so "m" in "metro" can't
  /// match. Capture group 1 is the integer/decimal.
  static final RegExp _areaNumberRe = RegExp(
    '([0-9]+(?:\\.[0-9]+)?)\\s*(?:$_areaUnitAlt)(?![$_wordChars])',
  );

  /// A leading area-size noun ("مساحه" / "size") that introduces a number a
  /// little later in the sentence ("مساحه 150", "مساحه حوالي 150").
  static final RegExp _areaLeadInRe = RegExp(
    '(?<![$_wordChars])(?:مساحه|size)(?![$_wordChars])',
  );

  /// Detects an area-size figure or range and returns (min, max, chipText,
  /// working-with-the-number(s)-blanked). Runs BEFORE rooms/price so the m²
  /// number is consumed once and only once. Distinguished from price purely by
  /// an adjacent area-size unit; a bare "مساحه" with no number yields nothing.
  (double?, double?, String?, String) _matchAreaSize(String working) {
    // ── range with a single trailing unit: "بين 100 و 200 متر" ──
    // Find two consecutive numbers where the SECOND carries an area unit and
    // an opener ("بين"/"من"/"from"/"between") precedes the first.
    final unitHit = _areaNumberRe.firstMatch(working);
    if (unitHit == null) return (null, null, null, working);

    final secondStart = unitHit.start;
    // Look back for "<n> <connector> " immediately before the unit number.
    final before = working.substring(0, secondStart);
    // Try to detect "X <connector> Y unit".
    for (final connector in kRangeConnectors) {
      final connRe = RegExp(
        '([0-9]+(?:\\.[0-9]+)?)\\s+${RegExp.escape(connector)}\\s+\$',
      );
      final cm = connRe.firstMatch(before);
      if (cm != null) {
        final loStr = cm.group(1)!;
        final lo = double.tryParse(loStr);
        final hi = double.tryParse(unitHit.group(1)!);
        if (lo != null && hi != null) {
          final fragStart = _rangeOpenerStart(working, cm.start);
          final text = _tidy(working.substring(fragStart, unitHit.end));
          final blanked = _blank(working, cm.start, unitHit.end);
          final min = lo <= hi ? lo : hi;
          final max = lo <= hi ? hi : lo;
          return (min, max, text, blanked);
        }
      }
    }

    // ── single value with comparator: "اقل من 150 متر" / "اكثر من 200 متر" ──
    final value = double.tryParse(unitHit.group(1)!);
    if (value == null) return (null, null, null, working);
    final (isMin, compStart) = _comparatorBefore(working, unitHit.start);

    // A leading "مساحه"/"size" noun without a comparator → treat as the chip
    // start so the fragment reads "مساحه 150 متر".
    var fragStart = compStart;
    if (compStart == unitHit.start) {
      final leadIns = _areaLeadInRe.allMatches(working.substring(0, unitHit.start));
      Match? lead;
      for (final m in leadIns) {
        lead = m;
      }
      if (lead != null) fragStart = lead.start;
    }

    final text = _tidy(working.substring(fragStart, unitHit.end));
    final blanked = _blank(working, unitHit.start, unitHit.end);
    if (isMin) {
      return (value, null, text, blanked);
    }
    // Bare "150 متر" (no comparator) means EXACTLY-ish: treat as an upper bound
    // window is wrong; the project's RPC area-size is a min/max range, so a bare
    // size is most usefully read as a maximum ("up to 150 m²"), matching the
    // budget convention. But a leading "مساحه"/"size" with no comparator more
    // naturally means "around this size" — we still map to max to avoid
    // over-narrowing, consistent with the price ceiling default.
    return (null, value, text, blanked);
  }

  /// True when any "at least" phrase appears in the (normalized) sentence.
  bool _hasAtLeastPhrase(String normalized) {
    for (final phrase in kAtLeastPhrases) {
      if (_keywordRe(phrase).firstMatch(normalized) != null) return true;
    }
    return false;
  }

  /// True when [first]..[second] reads as "بين X و Y" / "من X الى Y" /
  /// "between X and Y".
  bool _isRange(String working, _NumToken first, _NumToken second) {
    final between = working.substring(first.end, second.start).trim();
    final connectorOk = kRangeConnectors.contains(between);
    if (!connectorOk) return false;
    return _rangeOpenerStart(working, first.start) != first.start;
  }

  /// Start index of a range opener directly before [numStart], or [numStart]
  /// itself when none is present.
  int _rangeOpenerStart(String working, int numStart) {
    final window = working.substring(0, numStart);
    for (final opener in kRangeOpeners) {
      final m = _lastKeywordMatch(window, opener);
      if (m != null && window.substring(m.end).trim().isEmpty) {
        return m.start;
      }
    }
    return numStart;
  }

  /// Looks back ~20 chars before a number for a min/max comparator.
  /// Returns (isMin, fragmentStart) — fragmentStart includes the comparator
  /// so the chip reads "تحت 500 مليون", not just "500 مليون".
  (bool, int) _comparatorBefore(String working, int numStart) {
    final windowStart = numStart - 20 < 0 ? 0 : numStart - 20;
    final window = working.substring(windowStart, numStart);

    var isMin = false;
    var bestPos = -1;
    for (final kw in kMaxComparators) {
      final m = _lastKeywordMatch(window, kw);
      if (m != null && m.start > bestPos) {
        bestPos = m.start;
        isMin = false;
      }
    }
    for (final kw in kMinComparators) {
      final m = _lastKeywordMatch(window, kw);
      if (m != null && m.start > bestPos) {
        bestPos = m.start;
        isMin = true;
      }
    }
    return (isMin, bestPos >= 0 ? windowStart + bestPos : numStart);
  }

  Match? _lastKeywordMatch(String text, String keyword) {
    Match? last;
    for (final m in _keywordRe(keyword).allMatches(text)) {
      last = m;
    }
    return last;
  }

  /// Pure-Dart typo-tolerant property-type fallback over LATIN tokens.
  ///
  /// Guard (all must hold to adopt a type):
  ///   • token is purely `[a-z]` (Arabic tokens are skipped — folding in
  ///     [normalizeQueryText] already absorbs Arabic orthographic variation,
  ///     and fuzzy-matching short Arabic roots flips meaning too easily);
  ///   • token length >= 4 (short tokens like "lot"/"land" are too close to
  ///     unrelated words at distance 1 to trust);
  ///   • the token is itself NOT an exact keyword (those are handled upstream);
  ///   • across the Latin property-type keywords, the MINIMUM edit distance is
  ///     <= 1 AND every keyword achieving that minimum maps to the SAME
  ///     [PropertyType] — i.e. the nearest keyword is unambiguous about type.
  ///     A tie between two types (e.g. distance 1 to both a `shop` and an
  ///     `office` keyword) is rejected rather than guessed.
  ///
  /// The earliest qualifying token in the text wins, mirroring the
  /// exact-match "earliest wins" rule. Returns (type, matchedTokenText).
  (PropertyType?, String?) _fuzzyPropertyType(String working) {
    // Only the purely-Latin keywords are fuzzy-comparison candidates; an
    // Arabic keyword can never sit within distance 1 of a Latin token, so this
    // is both a correctness guard and a perf trim.
    final latinKeywords = <String, PropertyType>{
      for (final e in kPropertyTypeKeywords.entries)
        if (_isLatinToken(e.key)) e.key: e.value,
    };

    for (final tokenMatch in RegExp('[a-z]+').allMatches(working)) {
      final token = tokenMatch.group(0)!;
      if (token.length < 4) continue;
      // An exact keyword would already have been caught upstream; skip so the
      // fallback never second-guesses a clean hit (and never "corrects" a real
      // word to a different type).
      if (latinKeywords.containsKey(token)) continue;

      var bestDistance = 1 << 30;
      final typesAtBest = <PropertyType>{};
      for (final entry in latinKeywords.entries) {
        final d = _levenshtein(token, entry.key);
        if (d < bestDistance) {
          bestDistance = d;
          typesAtBest
            ..clear()
            ..add(entry.value);
        } else if (d == bestDistance) {
          typesAtBest.add(entry.value);
        }
      }
      if (bestDistance <= 1 && typesAtBest.length == 1) {
        return (typesAtBest.first, token);
      }
    }
    return (null, null);
  }

  /// True when [s] is a non-empty purely ASCII-lowercase-letter string.
  static bool _isLatinToken(String s) =>
      s.isNotEmpty && RegExp(r'^[a-z]+$').hasMatch(s);

  /// Classic two-row Levenshtein edit distance (insert/delete/substitute = 1).
  /// Bounded inputs (single tokens vs short keywords) so the O(m·n) cost is
  /// negligible.
  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        final del = prev[j + 1] + 1;
        final ins = curr[j] + 1;
        final sub = prev[j] + cost;
        var min = del < ins ? del : ins;
        if (sub < min) min = sub;
        curr[j + 1] = min;
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }

  static String _blank(String s, int start, int end) =>
      s.replaceRange(start, end, ' ' * (end - start));

  static String _tidy(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
}
