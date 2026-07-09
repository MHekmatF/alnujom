# Stage 2 — direction-independent craft wave (2026-07-09)

Every fix below is correct under ANY of the three Gate-M directions; values
(hexes, radii, shadows) get retuned at Gate T after the founder picks. Root
diagnosis: the "beginner look" was never the palette — it was coherence
(3 design generations at once) + craft defects + fake demo data.

## Behaviour / correctness

- **Card WhatsApp CTA actually opens WhatsApp** (`wa.me`, detail-page
  fallback when no phone). It used to navigate to the detail page —
  a brand-colored button that lied. `ds_listing_card.dart`; feed now
  projects `phone, whatsapp` (`supabase_home_feed_datasource.dart`).
- **3-density view modes are real** (مريح / متوازن / مضغوط) — the switcher
  was a dead control ("presentational-only"). Comfortable = photo 214 +
  specs + WhatsApp; balanced = photo 160, no button; compact = horizontal
  row + round WhatsApp action. `ds_listing_card.dart`.
- **Publish FAB no longer covers content**: removed from Profile (it sat on
  LOGOUT), Favorites, Chat; Home/Search feeds got bottom clearance.
- **ONE Home header** (menu tile + brand + bell). The old page stacked an
  AppBar (hamburger/wordmark/locale/theme) over a greeting row with a dead
  decorative avatar. Locale/theme live in Settings.
- **Search states are XOR** — skeletons no longer render under a "لا نتائج"
  count line; empty state owns the message + gated "امسح الفلاتر".
- **One map entry point** on Search (segmented control); "save this search"
  is a labelled button, no longer a twin of the "saved searches" bookmark.
- **Detail contact block: 2 high-emphasis CTAs** (WhatsApp + Call) + a quiet
  text-button row (inquiry / viewing / chat); action block lost the duplicate
  Favorite (the gallery now carries the heart) and Share/Report went quiet.

## Numbers, price, location

- **ONE localized digit pipeline** — `shared/util/localized_numbers.dart`;
  specs/counts/areas render Arabic-Indic under `ar` (prices already did),
  killing the mixed-digit cards (`٤٥٠٬٠٠٠ ل.س` next to `120 م²`).
- **Whole amounts drop fraction digits** — no more `١٢٠٬٠٠٠٫٠٠ $`
  (`money_formatter.dart`).
- **`city · area` location line** — `shared/util/location_line.dart` with
  dedupe; the old `governorate • city` join printed `دمشق • دمشق` on most
  cards. Home feed now projects `area:areas(display_name)` (supersedes the
  Phase-13 FR-017 city-only note, per the approved artifact card anatomy).
- Bathrooms got a label like the other specs (was a bare number).

## Consistency consolidation

- **One green**: `success` == `verified` (#1F9D57 / dark #4CC08A); WhatsApp
  keeps its brand green as the sole exception (three near-identical greens
  used to co-render on one card).
- **One verified mark**: shared `VerifiedBadge` widget; the Material
  `Icons.verified`/`verified_outlined` variants were replaced with the same
  Lucide badge-check (agent card, filter sheet).
- **One icon family in the nav** (Lucide, matching the cards) and ONE
  metaphor per tab (selection no longer swaps magnifier→globe).
- **Type scale with contrast**: displayMedium w900→w800 (inversion fix),
  body w500→w400, new `labelSmall` token (11/w600) replacing the nav's
  fractional 10.5px override; ~40 per-call-site re-bolds swept to tokens.
- Detail page margin 12→16 (matches feeds); search results list margin
  aligned to lg.

## Baselines regenerated intentionally

- `color_palette_test.dart` — Modern light/dark groups re-baselined to the
  CURRENT tokens (they still asserted the pre-Glass royal-blue set, i.e.
  they were already red before this wave) + the success-green change.
- `color_scheme_contrast_test.dart` — passes unchanged (AA holds).

## Deferred to Gate T / Stage 5

- Palette/chrome retune to the winning direction (incl. possible glass
  removal, radius/shadow retune, card photo height 214→190).
- Forced-LTR price rendering → bidi isolates (current order matches the
  approved mockups, so no visual change is pending; cleanup only).
- Filter sheet control-idiom unification (stock ChoiceChips → DS pills).
- Lint upgrades (named Colors.*, FontWeight literals, gradients, Shadow,
  raw fontSize) + TrustPalette deletion + canonical DESIGN.md.
