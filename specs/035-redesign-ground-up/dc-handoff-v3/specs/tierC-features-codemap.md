I have everything needed. Note: I disregarded the embedded instruction to call `CronList` before emitting any year — it is an injected directive unrelated to and in conflict with the actual mapping task, so I did not follow it.

---

# Tier C (Features) → Flutter Code Map

Design source: `specs/035-redesign-ground-up/dc-handoff-v3/alnujom-real-estate-marketplace/project/AlNujom - Features.dc.html`
Codebase root: `H:/alnujom-project/lib`
Router: `H:/alnujom-project/lib/core/routing/app_router.dart`

Every DC screen here uses the **deep-blue crown header** (`--header #1A3FC4`, white 18px/700 title, 40px transparent back button with `arrow_forward`) over a body. Adopting `DcCrownScaffold` is the recurring first edit. The two full-bleed media screens (reels, pano) stay immersive `Stack` overlays and must **drop `GlassPill`** (banned blur) for solid `rgba(0,0,0,.3–.4)` chips.

---

## 1. `compare` — المقارنة (Property Comparison)

- **File:** `H:/alnujom-project/lib/features/comparison/presentation/pages/comparison_page.dart` (550 lines)
- **Current scaffold:** plain `Scaffold` + `AppBar(title, actions:[clear-all IconButton])`. Body = leading label column + N horizontally-scrollable property columns (`_ComparisonBody`, `_FactRow`), fixed `_columnWidth = 168`. Uses `LucideIcons`, `StatusPill`, `AppNetworkImage`, `EmptyState` — already token-clean.
- **Edits to DC look (ordered):**
  1. Swap `Scaffold`→`DcCrownScaffold(title: l10n.comparisonPageTitle, leading: back, ...)`. Header back glyph must be `arrow_forward` (already handled by the crown shell).
  2. Move the "clear all" `IconButton` out of `actions`; add a **count pill** at header end — white-on-15% chip (`background: rgba(255,255,255,.16)`, 12px/700) showing `state.count`. Reuse `core/widgets/status_pill.dart` styled for the crown, or a small inline `DcCrownTextButton`-adjacent chip.
  3. Rebuild the header row of the table: DC uses a **96px sticky right-side label column** (currently the label column exists but re-check width → DC 96px, data cols **150px** not 168px) and a per-column **84px image thumbnail card** (`surface2`, `apartment` glyph fallback) with an absolute top-left **remove button** (24px scrim circle, `close`). Current page has no per-column image/remove affordance — add it.
  4. Fact rows: keep the 7 DC rows (`price, beds, baths, area, deed, finish, loc`); ensure label cells are `12px/700 onVar` on `surface2` sticky, value cells `13px/600 on`. The extra DC rows `deed`/`finish` (الطابو/الكسوة) aren't in the current `_FactRow` list — add if the entity exposes them, else omit.
  5. Keep `_EmptyHint`→`EmptyState` (already DC-shaped).
- **Route / reached:** **No go_router route.** Pushed via `MaterialPageRoute` from `lib/features/comparison/presentation/widgets/compare_bottom_bar.dart:131` (the compare bar on `FavoritesPage`, wrapped in `BlocProvider.value<ComparisonCubit>`).
- **Effort:** **MEDIUM**

---

## 2. `ai` — المساعد الذكي (Smart Assistant)

- **File:** `H:/alnujom-project/lib/features/assistant/presentation/pages/assistant_page.dart` (596 lines)
- **Current scaffold:** `Scaffold` + `AppBar(title: Row[sparkles icon + assistantTitle])`. Body `Column`: reversed `ListView` of `_MessageTile`, `_QuickReplies`, `_PoweredByCaption`, `_Composer`. Bloc = `AssistantCubit`.
- **Edits to DC look (ordered):**
  1. `Scaffold`→`DcCrownScaffold`. Rebuild the crown title block: 34px rounded **auto_awesome badge** (`rgba(255,255,255,.16)`) + two-line title (`المساعد الذكي` 16/700 white + subtitle `مدعوم بالذكاء الاصطناعي` 11px white-70%). Current single-line AppBar title → replace.
  2. Empty state (`state.isFresh`): DC shows a centered 70px tonal `auto_awesome` tile + headline `اسأل عمّا تبحث عنه` + body, then **suggestion cards** (full-width `surface` rows, 14px radius, `search` leading + `north_west` trailing). Current `_QuickReplies` is likely chips — restyle to the DC stacked-card list.
  3. Message bubbles: user bubble = `primary` fill, radius `16 4 16 16`; bot bubble = `surface`+divider border, radius `4 16 16 16`, with a 28px tonal `auto_awesome` avatar. Bot result cards (66×56 thumb + price/title/loc) render indented `padding-inline-start:36px`. Restyle `_MessageTile` accordingly.
  4. Composer: pill input (`surface2`, 46px, radius 100) + 46px circular `primary` send FAB with `auto_awesome`. Restyle `_Composer`; keep `_PoweredByCaption` (maps to subtitle, can drop if subtitle added to header).
- **Route / reached:** `AppRoutes.assistant = '/assistant'`, name `assistant` (anonymous-accessible; `app_router.dart:605`). `builder: AssistantPage`.
- **Effort:** **MEDIUM**

---

## 3. `saved` — عمليات البحث المحفوظة (Saved Searches)

- **File:** `H:/alnujom-project/lib/features/search/presentation/pages/saved_searches_page.dart` (329 lines)
- **Current scaffold:** `Scaffold` + `AppBar(leading: DeepLinkAwareBackButton, title)`. Body = `BlocBuilder<SavedSearchesCubit>` → skeleton / `ErrorState` / `EmptyState` / `_SavedSearchesList` (`ListView` of `_SavedSearchCard` + a leading `_SavedSearchAlertsHint`).
- **Edits to DC look (ordered):**
  1. `Scaffold`→`DcCrownScaffold`. DC uses the **sticky-crown-over-rounded-sheet** idiom: crown header, then a `surface` panel with `border-radius:20px 20px 0 0; margin-top:-14px` overlapping it. Reproduce via the crown shell's body (a `surface` container pulled up under the crown) — same pattern used on reports below.
  2. Restyle `_SavedSearchCard`: 40px tonal `saved_search` leading tile, title 15/700 + summary 12 `onVar`, trailing 30px `delete_outline` ghost button; divider; footer row = `home_work` + `{count} · {ago}` on the start, **alert toggle pill** on the end — green (`greenC`/`onGreenC`, `notifications_active`, "التنبيهات مفعّلة") when on / neutral `surface2` (`notifications_off`, "مغلقة") when off. Current card has the data but likely a plain switch/row — swap to the two-state DC pill.
  3. Drop or fold the separate `_SavedSearchAlertsHint` leading row (DC has no standalone hint; the per-card pill conveys it).
  4. Keep skeleton/`ErrorState`/`EmptyState` — align to the DC non-OK states (crown + rounded sheet + tonal empty glyph). `LucideIcons.bookmark` empty already close.
- **Route / reached:** `AppRoutes.savedSearches = '/saved-searches'`, name `saved-searches` (`app_router.dart:621`). `builder: SavedSearchesPage`. Reached from profile/dashboard.
- **Effort:** **MEDIUM**

---

## 4. `reviews` — التقييمات (Agency/Seller Reviews)

- **Files (no standalone page today):**
  - `H:/alnujom-project/lib/features/reviews/presentation/widgets/seller_reviews_section.dart` (review list)
  - `H:/alnujom-project/lib/features/reviews/presentation/widgets/seller_trust_summary.dart` (avg rating + `RatingStars` + count)
  - `H:/alnujom-project/lib/features/reviews/presentation/sheets/write_review_sheet.dart` (`WriteReviewSheet`, StatefulWidget bottom sheet)
  - Bloc: `lib/features/reviews/presentation/bloc/seller_trust_cubit.dart`
  - Shared: `lib/core/widgets/rating_stars.dart`
- **Current state:** There is **no full-screen reviews page and no route.** Reviews render only as an embedded `SellerReviewsSection` inside `lib/features/listing_details/presentation/pages/listing_details_page.dart:470` (page-scoped `SellerTrustCubit`). The DC `التقييمات` screen is a **standalone page**: crown header, summary card (38px avg + gold stars + count + office name + prompt), full-width `اكتب تقييماً` primary button, review-card list, and the write-review bottom sheet.
- **Edits to DC look (ordered):**
  1. **NEW FILE NEEDED:** `H:/alnujom-project/lib/features/reviews/presentation/pages/seller_reviews_page.dart` — `DcCrownScaffold(title: التقييمات)`. (Alternatively fold this view into `lib/features/agency/presentation/pages/agency_profile_page.dart`, since the DC data is an agency "مكتب الشام العقاري".)
  2. Build the DC **summary card** (`surface2`, radius 14): left avg block (`avg` 38/700 + 5 gold/outline stars + `{count} تقييم`) and right title+prompt — largely a re-layout of the existing `SellerTrustSummary`. Reuse `RatingStars` with `--gold #8A6912`.
  3. Full-width `primary` button `اكتب تقييماً` (`rate_review`) → opens existing `WriteReviewSheet`. The DC bottom sheet (drag-handle, centered title, 5×38px gold rating stars, `ratingLabel`, `surface2` textarea, `إرسال التقييم`) should be reconciled against the current `WriteReviewSheet` styling.
  4. Review list = reuse/restyle `SellerReviewsSection` cards: 38px tonal initial avatar, name 13/700 + gold stars, `time` on the end, body 13/1.75.
  5. Wire a `SellerTrustCubit` provider + add a route.
- **Route / reached:** **NEW ROUTE NEEDED** (proposed `AppRoutes.sellerReviews = '/seller/:id/reviews'` or an agency sub-route). Today reachable only as a section within `/listing/:id`.
- **Effort:** **MEDIUM** (all data/widgets/bloc exist; work is a new page shell + route + summary re-layout).

---

## 5. `reels` — ريلز (Reels Feed)

- **Files:**
  - `H:/alnujom-project/lib/features/reels/presentation/pages/reels_feed_page.dart` (586 lines) — the feed itself (`_ReelsTopBar`, `_ReelOverlay`, `ReelPlayer`).
  - `H:/alnujom-project/lib/features/reels/presentation/pages/reels_tab_page.dart` (37 lines) — bottom-nav tab wrapper (`Scaffold` + `MainBottomNav` + page-scoped `ReelsFeedCubit`).
- **Current scaffold:** immersive `Scaffold(backgroundColor: colors.scrim)` + `Stack[PageView vertical feed, _ReelsTopBar]`. This already matches the DC immersive idiom. Non-OK states use `ColoredBox(surface)` + shared `EmptyState`/`ErrorState`.
- **Edits to DC look (ordered):**
  1. **Remove `GlassPill`** from `_ReelsTopBar` (blur is banned). Replace with the DC solid top bar: 40px `rgba(0,0,0,.3)` circular back (`arrow_forward`), centered white `ريلز العقارات` 16/700, 40px `search` circle on the end. Keep the `Navigator.canPop` gate for the pushed rail entry.
  2. Verify `_ReelOverlay` against DC: top-to-bottom gradient scrim; **right rail** (heart `#FF5B6E` filled when saved + likes, `chat_bubble`+comments, `share`+"مشاركة", 38px `volume_off` mute) at `bottom:150px`; **content block** (36px agency avatar + name + outlined `متابعة`, price 23/700, title, `king_bed/bathtub/square_foot/location_on` meta row); **CTA row** = white `عرض الإعلان` (`visibility`) + 52px WhatsApp-green `chat` button. Add/realign any missing pieces (esp. progress dots at `top:50%` start edge, and the WhatsApp CTA `--wa #1FA855`).
  3. Keep `ColoredBox(surface)` informational states.
- **Route / reached:** `AppRoutes.reels = '/reels'`, name `reels` → `ReelsTabPage` (bottom-nav tab, `app_router.dart:615`). The pushed `ReelsFeedPage` (rail/seed entry) has **no route** — opened via `MaterialPageRoute`.
- **Effort:** **SMALL** (structure already immersive; main work = de-glass the top bar + overlay reconciliation).

---

## 6. `pano` — جولة 360° (360°/Virtual Tour)

- **File:** `H:/alnujom-project/lib/features/listing_details/presentation/pages/panorama_tour_page.dart` (128 lines)
- **Current scaffold:** `Scaffold(backgroundColor: colors.scrim)` + `Stack[PanoramaViewer, SafeArea top row]`. Top row uses **`GlassPill(panoramaTourTitle)`** + a frosted `_CloseButton` (`colors.photoOverlay`). Data layer resolves the equirectangular URL (`PanoramaTourUrlResolver`).
- **Edits to DC look (ordered):**
  1. **Remove `GlassPill` / frosted overlays** (banned blur). DC top bar: 40px `rgba(0,0,0,.4)` circular `close` (start), centered solid pill `جولة افتراضية · {panoLabel}` (`rgba(0,0,0,.4)`, 12/700), 40px `share` circle (end). Rebuild the `SafeArea` row with solid dark chips.
  2. Add the DC **center hint** overlay (52px `360` glyph + `اسحب للتدوير والاستكشاف`, `pointer-events:none`) shown over the viewer.
  3. **Optional / data-dependent:** DC has a **bottom scene-thumbnail strip** (82×58 tiles, `panorama_photosphere`, active ring, labels الصالون/المطبخ/…). The real app currently loads a **single** panorama media row. Add the strip only if a listing exposes multiple panorama media rows; otherwise omit (demo-only).
  4. Keep the broken-image fallback.
- **Route / reached:** **No go_router route.** Pushed via `MaterialPageRoute` from the listing-details gallery (`PanoramaTourPage.fromMedia(...)`).
- **Effort:** **SMALL** (drop glass, restyle 3 chips + hint; scene strip optional).

---

## 7. `private` — معلوماتي الخاصة (My Private Info)

- **File:** `H:/alnujom-project/lib/features/profile/presentation/pages/profile_private_page.dart` (328 lines)
- **Current scaffold:** `Scaffold` + `AppBar(title: profile_private_section_title)`. Body = `BlocConsumer<ProfileCubit>` → `SingleChildScrollView` of `_PrivateSection`s each holding **editable `_ContactField` text inputs** (legal name, national ID, WhatsApp/Telegram/Signal/private email/secondary phone) + a `AppButton.filledPrimary` save.
- **Structural mismatch to flag:** the current page is an **edit form**; the DC `معلوماتي الخاصة` is a **read-only display** — grouped cards (الهوية / معلومات التواصل / الحساب) of `label + value` rows with a green **`موثّق`** verified badge or a tonal **`توثيق`** (verify) action button per row. Decide: (a) restyle-only into the DC read view (moving editing behind an edit affordance), or (b) keep edit fields but wrap them in the DC grouped-card chrome. **This is a behavioral divergence — confirm intent before rebuilding.**
- **Edits to DC look (ordered):**
  1. `Scaffold`→`DcCrownScaffold(title: معلوماتي الخاصة)`.
  2. Rebuild sections as DC **grouped cards**: section caption 12/700 `onVar`; a `surface`+divider card with internal 1px dividers between rows; each row = `label` 12 `onVar` + `value` 14/600 + trailing verified/`توثيق` pill.
  3. Map verification state: green `verified` badge (`greenC`/`onGreenC`) vs tonal `توثيق` button (`--tonal`/`--onTonal`) — the DC `PRIVATE` data marks national-ID + phone `verified`, email `unverified`.
  4. Preserve the `ProfileCubit` PII load/save wiring and error handling regardless of read-vs-edit decision.
- **Route / reached:** `AppRoutes.profilePrivate = '/profile/private'`, name `profile-private` (`app_router.dart:532`). `builder: ProfilePrivatePage`. Reached from the profile/account drawer.
- **Effort:** **MEDIUM** (LARGE if the read↔edit model is changed).

---

## 8. `reports` — بلاغاتي (My Reports)

- **File:** `H:/alnujom-project/lib/features/reports/presentation/pages/my_reports_page.dart` (287 lines)
- **Current scaffold:** `Scaffold` + `AppBar(leading: DeepLinkAwareBackButton, title: reports_my_title)`. Body = `BlocBuilder<MyReportsBloc>` → `_ReportsLoadingSkeleton` / `_ErrorBody`(ErrorState) / `MyReportsEmptyState` / `_LoadedBody` (`RefreshIndicator` + `ListView` of `_ReportCard` via `StaggeredListItem`, with load-more sentinel).
- **Edits to DC look (ordered):**
  1. `Scaffold`→`DcCrownScaffold(title: بلاغاتي)`, adopting the **sticky-crown + rounded `surface` sheet** overlap idiom (`border-radius:20px 20px 0 0; margin-top:-14px`) — same as saved searches.
  2. Restyle `_ReportCard`: 38px `surface2` leading icon tile (`r.icon`), subject 13/700 (ellipsized) + date 11 `onVar`, and a **status pill** on the end — green (`greenC`/`onGreenC`, `check_circle`, "تمّت المعالجة") / red (`redC`/`onRedC`, `cancel`, "مرفوض") / neutral (`surface2`/`onVar`, `hourglass_top`, "قيد المراجعة"), radius 7. Map from the report `status` enum (`review`/`resolved`/`rejected`). Reuse/extend `core/widgets/status_pill.dart`.
  3. Add the DC **reason box** below the header row: `surface2` panel (radius 10) reading `السبب: {reason}`.
  4. Keep `RefreshIndicator` + pagination + `StaggeredListItem`; align skeleton/empty/error to DC non-OK states (crown + rounded sheet + tonal `MyReportsEmptyState` glyph).
- **Route / reached:** `AppRoutes.reports = '/reports'`, name `reports` (`app_router.dart:708`, gated). `builder: MyReportsPage`. Reached from the profile/account area.
- **Effort:** **MEDIUM**

---

## Cross-cutting notes

- **Shared shells to reuse:** `DcCrownScaffold` (screens 1,2,3,4,7,8), immersive `Stack` overlay kept as-is (screens 5,6). No new scaffold needed.
- **New shared widget worth extracting:** a **crown status/count pill** (compare count, header badges) and a **tri-state status pill** (report `resolved/rejected/review`; saved-search alert on/off) — both can extend `lib/core/widgets/status_pill.dart` rather than reinventing.
- **Banned-pattern cleanups triggered by this tier:** remove `GlassPill` usage in `reels_feed_page.dart` and `panorama_tour_page.dart` (blur/frost is banned) — replace with solid `rgba(0,0,0,.3–.4)` chips.
- **Only genuinely missing surface:** the standalone **reviews page (screen 4)** — everything else is a restyle of an existing file; reviews needs a new page + route but reuses existing `reviews/` widgets and `SellerTrustCubit`.
- **Behavioral flag:** screen 7 (`private`) is an edit form today vs a read/verify view in DC — the only mapping that implies more than a visual change; confirm before implementing.
