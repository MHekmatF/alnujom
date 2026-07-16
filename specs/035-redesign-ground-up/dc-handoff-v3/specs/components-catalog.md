# DC v3 (A–D) — Cross-Cutting Reusable Component Catalog

Read in full: `AlNujom - Publisher.dc.html` (1059 lines), `AlNujom - Agency.dc.html` (527), `AlNujom - Features.dc.html` (607), `AlNujom - Chrome.dc.html` (309). Token vars identical across all four (the `--bg…--scrim` block on the phone root + `THEMES.light/dark` in each script — they match the CLAUDE.md DC tokens exactly).

Below, every component is checked against the **already-built** inventory in `lib/core/widgets/` and `lib/core/widgets/ds/` so nothing is reinvented.

---

## 0. What ALREADY exists (reuse or extend — do NOT rebuild)

| Existing file | Covers | Verdict for DC v3 |
|---|---|---|
| `charts/token_bar_chart.dart` → `TokenBarChart` | vertical bars, no chart pkg | **Reuse** for dashboard "المشاهدات" & agency views bars. Needs a card-chrome wrapper (title/total/x-labels). |
| `charts/token_hbar_list.dart` → `TokenHbarList` | labeled horizontal bars | **Reuse** for "أعلى الأعضاء أداءً" (Agency) and the analytics "حسب المصدر" magnitudes. |
| `stat_card.dart` → `StatCard` | icon + value + label KPI | **Extend** — DC adds a trailing trend delta + a `sub` caption, and DC is *flat* (surface + hairline border, no gradient/shadow) while `StatCard` washes `featuredTint` + `level1`. Add a `flat`/`trend`/`sub` path. |
| `status_pill.dart` → `StatusPill` | **solid-fill** pill (label+color+icon) | DC status chips are **tonal/soft** (container bg + on-container text), 4 tones. Different enough → new `DcStatusChip` (below); keep `StatusPill` for sale/rent. |
| `rating_stars.dart` → `RatingStars` + `.input` | display + tappable 1–5 | **Reuse as-is** for review cards, rating summary, write-review sheet. Star tone already amber/outline. |
| `empty_state.dart` / `error_state.dart` / `loading_state.dart` | empty / error+retry / loading | **Reuse**; verify they render the DC spec (88px tinted circle, icon 44, title 18/700, body 14/1.7, pill CTA). Add the 3 DC skeleton *shapes* (below). |
| `stepper_indicator.dart` | horizontal *progress* bar | NOT the moderation timeline (that's a vertical connected node list) → new `DcModerationTimeline`. |
| `segmented_control.dart` → `AppSegmentedControl<T>` | icon+label segments | **Extend** — DC's theme-mode / state-preview tabs are **label-only** pill segments; make `icon` optional. |
| `app_toggle.dart` → `AppToggle` | M3 `Switch` | **Reuse** inside the settings row (DC's hand-rolled 46×28 track is visually equivalent). |
| `ds/verified_badge.dart` | verified badge | **Reuse** for "موثّق" pills. |
| `chat_bubble.dart` | message bubbles | **Reuse** for inquiry thread + AI assistant bubbles. |
| `dashboard_tile.dart` | dashboard quick-link tile | **Extend** with an optional red count badge. |
| `main_bottom_nav.dart` / `app_bottom_nav.dart` | bottom nav | **Extend** with per-tab red count badge. |
| `crown_underline_tabs.dart` → `CrownUnderlineTabs` | white underline tabs on crown | **Reuse**; add a `scrollable` option (listings/CRM/viewings filter rows scroll-x). |

**Not present anywhere in the DC files:** no **donut**, no **line/area** chart, no radial/gauge. Only vertical bars, one **stacked** bar (4 opacity tiers + legend), and horizontal bars/distribution. Plan chart work around that reality (see §5).

---

## 1. KPI / Stat card (with trend) — extend `StatCard`

**DC tokens** (Publisher L87–100; Agency L247–253; simplified pair L228–229):
- card `--surface` bg, `1px --divider` border, radius **14**, padding `12 12 11`.
- icon box **32×32**, radius **9**, `--tonal` bg, glyph **19** `--onTonal`.
- trend: `arrow_upward/downward` **14** + delta, **11px/700 Roboto**, up→`--green` / down→`--red`.
- value **22px/700 Roboto** (Agency 21), lh 1.1, `mt 9`; label **12/600** `--on`, `mt 3`; sub **11** `--onVar`, `mt 2` (Publisher only).
- Flat: **no gradient, no shadow** (contrast with current StatCard).

**Widget:** extend `lib/core/widgets/stat_card.dart` (or `ds/dc_stat_card.dart`).
**Params to add:** `String? delta`, `bool trendUp`, `String? sub`, `bool flat = false`.
**Used by:** Publisher dashboard (4-up), Agency › إدارة › التحليلات (4-up), Publisher analytics top-2 (icon-less variant).

### 1b. Trend delta chip — `DcTrendDelta`
Standalone because it also appears inside the analytics table's "التغيّر" column (L264–265).
**Path:** `lib/core/widgets/ds/dc_trend_delta.dart` · **Params:** `String value, bool up`.

---

## 2. Status chip system — `DcStatusChip` (+ tone registry) — NEW

This is the single most cross-cutting component. **Four tones**, appearing as a **7px soft chip** and a **pill dot-chip** shape. Enumerated exact tokens:

| Status (ar) | key | Tone | bg | text | icon |
|---|---|---|---|---|---|
| منشور | live | green | `--greenC` #E4F3E9 | `--onGreenC` #0A5A2C | `check_circle` (filled) |
| قيد المراجعة | review | neutral | `--surface2` #F2F4F9 | `--onVar` #5B6070 | `hourglass_top` |
| مرفوض | rejected | red | `--redC` #FBE6E6 | `--onRedC` #B42318 | `cancel` |
| منتهٍ | expired/past | neutral | `--surface2` | `--onVar` | `schedule` / `history` |
| مسودّة | draft | **outline** | transparent + `1px --outline` | `--onVar` | `edit_note` |
| معلّق (viewing) | pending | neutral | `--surface2` | `--onVar` | `hourglass_top` |
| مؤكّد (viewing) | confirmed | green | `--greenC` | `--onGreenC` | `event_available` |
| مرفوض (viewing) | declined | red | `--redC` | `--onRedC` | `event_busy` |
| تمّت المعالجة (report) | resolved | green | `--greenC` | `--onGreenC` | `check_circle` |
| قيد المراجعة / مرفوض (report) | review/rejected | neutral/red | as above | | `hourglass_top` / `cancel` |
| مقبول (doc) | accepted | green | `--greenC` | `--onGreenC` | `check_circle` |
| مطلوب (doc) | required | outline | transparent+`--outline` | `--onVar` | — (no icon) |

**Chip shape** (listing cards L178–181, viewings L484–486, reports L322–324, docs L288–290): radius **7**, padding `3 8` (outline `2 8`), font **10/700**, icon **13** (green/red filled).

**CRM stage "dot pill"** (Publisher L335–337) — same tones but **pill** shape (radius 100), padding `3 9`, a leading **6px dot** (`--green`/`--red`/`--onVar`) instead of an icon, label 10/700. Tone rule: `مغلق-ناجح`→green, `مغلق-خسارة`→red, else (`جديد/تواصل/معاينة/تفاوض/مغلق`)→neutral.

**Widget:** `lib/core/widgets/ds/dc_status_chip.dart`
```
enum DcStatusTone { green, red, neutral, outline }
DcStatusChip({ required String label, required DcStatusTone tone,
               IconData? icon, bool dot = false })  // dot=true → pill+leading dot
```
Ship a `dc_status_tokens.dart` map (status-key → {tone, ar-label, icon}) so Publisher/Agency/Features all resolve identically.
**Used by:** Publisher (listings, viewings, moderation header, dashboard activity), Features (reports, saved-search alert toggle uses the pill form), Agency (doc verification, listing "موثّق").

---

## 3. Charts

### 3a. Bar-chart card wrapper — `DcBarChartCard` (wraps existing `TokenBarChart`)
**DC** (Publisher L104–119; Agency L255–261): card surface/divider/14 padding 14; header = title **14/700** + range **11** `--onVar`, right = total **19/700** + "إجمالي" 11; plot **height 128** (Agency 120), bar `max-width 22` (Agency 24), radius **6 6 0 0**, `--primary`, per-bar x-label **10** `--onVar`.
**Path:** `lib/core/widgets/charts/dc_bar_chart_card.dart` · **Params:** `String title, String? rangeLabel, String? totalValue, String? totalLabel, List<TokenBarChartBar> bars, List<String> labels`.
**Used by:** Publisher dashboard "المشاهدات", Agency analytics "مشاهدات إعلانات الوكالة".

### 3b. Stacked bar chart + legend — `DcStackedBarChart` — NEW
**DC** (Publisher analytics L233–254): plot **height 172**, bar `max-width 26`, radius `6 6 0 0`, overflow hidden; each bar stacks 4 `--primary` segments bottom→up at **opacity .26 / .46 / .72 / 1** (معاينات / استفسارات / واتساب / مكالمات); legend = wrap, `11px` square (radius 3) at matching opacity + label 11 `--onVar`, top-bordered.
**Path:** `lib/core/widgets/charts/dc_stacked_bar_chart.dart`
**Params:** `List<List<num>> stacks` (4 series/bar), `List<String> labels`, `List<DcStackLegend> legend` (label+opacity).
**Used by:** Publisher › تحليلات العملاء.

### 3c. Rating distribution bars — `DcRatingDistribution` — NEW (or `TokenHbarList` w/ gold)
**DC** (Agency reviews L172–176): rows 5→1; star label **11** + star glyph 12 `--gold` + **6px** track (radius 3, `--divider`) + fill `--gold` width%.
**Path:** `lib/core/widgets/charts/dc_rating_distribution.dart` · **Params:** `List<({int star, int count})> dist`.
**Used by:** Agency reviews tab, (Features reviews could adopt it).

### 3d. Data table — `DcDataTable` — NEW (light)
**DC** (Publisher analytics "حسب المصدر" L257–269): card surface/divider/14; header row `--surface2` (label flex + two 64px cols), 11/700 `--onVar`; data rows top-bordered padding `11 13` — leading icon 18 + name 13/600, value 14/700 Roboto, trend `DcTrendDelta`; footer "الإجمالي" row `--surface2`.
**Path:** `lib/core/widgets/ds/dc_data_table.dart` · **Params:** `List<String> headers, List<DcTableRow> rows, DcTableRow? footer`.

---

## 4. Moderation / verification / list primitives

### 4a. Vertical timeline — `DcModerationTimeline` + `DcTimelineNode` — NEW
**DC** (Publisher L289–305, data `MOD` L767–773): node **32×32** circle — green `--greenC`+`--onGreenC` (filled 18), red `--redC`+`--onRedC` (18), neutral `--surface2`+`1px --divider`+`--onVar` (17); connector `absolute top:32 width:2 bottom:-20 --divider` when `notLast`; content = title **14/700**, time **11** `--onVar` Roboto, optional body card `--surface2` radius 10 padding `9 11`, 12/1.65. Header summary card above it: `--surface2` radius14 padding11, 56×48 thumb + title/price + `DcStatusChip`.
**Path:** `lib/core/widgets/ds/dc_timeline.dart`
**Node kinds seen:** submitted (`upload_file`), revision-requested (`edit_note`), resubmitted (`upload_file`), approved (`check_circle`, green), field-verified (`verified`, green), rejected (red).
**Params:** `List<DcTimelineNode>` where node = `{IconData icon, DcStatusTone tone, String title, String time, String? body}`.

### 4b. Document-verification row — `DcDocRow` — NEW
**DC** (Agency verify L283–296): card surface/divider/14 padding 13; 40×40 radius11 `--surface2` `description` icon; label 13/700; `DcStatusChip` (accepted/review/required); trailing = required→tonal "رفع" button (upload, h34 pill) / done→34px `visibility` circle button. Above the list: a `--tonal` info banner (icon `verified_user` + title/body).
**Path:** `lib/core/widgets/ds/dc_doc_row.dart` · **Params:** `String label, DcDocStatus status, VoidCallback? onUpload, onView`.
**Used by:** Agency › إدارة › التوثيق (reusable for user KYC / listing-deed verification later).

### 4c. Activity row / list — `DcActivityRow` — NEW
**DC** (Publisher dashboard L138–146, data `ACTIVITY` L781–785): row in a card; **36×36** rounded-square (radius 10) — green (`--greenC`/`--onGreenC` filled) or blue (`--tonal`/`--onTonal`) — icon 19 + title 13/600 + body 12 `--onVar` (ellipsized) + time 11; 1px divider between.
**Path:** `lib/core/widgets/ds/dc_activity_row.dart`

### 4d. Source/meta chip — `DcMetaChip` — NEW
**DC** (CRM lead L330; `SOURCES` L717–721): `--surface2`/`--onVar`, radius **6**, padding `2 7`, icon **12** + label **10/600**. Values: محادثة `forum` / استفسار `mail` / معاينة `event`.
**Path:** `lib/core/widgets/ds/dc_meta_chip.dart` · **Params:** `String label, IconData icon`.

---

## 5. Reviews cluster (shared Agency ↔ Features)

### 5a. Review card — `DcReviewCard` — NEW
**DC** (Agency L180–189; Features L235–244): card surface/divider/14 padding13; 38×38 tonal-circle initial (15/700 `--onTonal`) + name 13/700 + `RatingStars(value)` (13px) + time 11; body 13/1.75 `mt9`.
**Path:** `lib/core/widgets/ds/dc_review_card.dart` · **Params:** `String initial, name, time, text; int rating`.

### 5b. Rating summary header — `DcRatingSummary` — NEW
**DC** (Agency L170–177; Features L229–232): `--surface2` radius14 padding14, flex gap16; left = avg **38/700 Roboto** + `RatingStars` (15px) + count 11; right = title + prompt (Features) **or** `DcRatingDistribution` (Agency).
**Path:** `lib/core/widgets/ds/dc_rating_summary.dart`

### 5c. Write-review bottom sheet — `showDcWriteReviewSheet()` — NEW
**DC** (Features L373–391): scrim + `--surface` sheet radius `24 24 0 0`, grabber 36×4; title 17/700; tappable stars 38px (`RatingStars.input`); rating label 12; textarea h104 radius14 `--surface2` border outline 14/1.7; submit primary h48 pill. Reuses `app_bottom_sheet.dart` chrome.
**Path:** `lib/core/widgets/ds/dc_write_review_sheet.dart`

---

## 6. Chrome (Tier D)

### 6a. Onboarding slide + page dots — `DcOnboardingSlide` + `DcPageDots` — NEW
**DC** (Chrome L83–93, `SLIDES` L224–228): icon box **150×150** radius **44** `--tonal`, glyph **76** `--onTonal` filled; title **24/700**; body **15/1.85** `--onVar`; dots h7 radius4 `--primary`, active **width 24 / opacity 1**, inactive **width 7 / opacity .28**; next button h52 pill primary 15/700 (label flips به "ابدأ الآن" على آخر شريحة).
**Paths:** `ds/dc_onboarding_slide.dart`, `ds/dc_page_dots.dart` (dots also drive the Reels vertical progress rail, Features L108–110 — vertical variant).

### 6b. Skeleton shapes — `DcSkeletons` — NEW (feeds `loading_state.dart`)
**DC** shimmer: `linear-gradient(90deg, --surface2 25%, --divider 37%, --surface2 63%)`, size `400% 100%`, `shim 1.4s`. Shapes seen: **card-w-image** (aspect 16/10 + 3 bars — Chrome L201, Agency L324), **list-w-thumb** (88×66 or 44 thumb + 3 bars — Publisher L542–554, Features L347–349), **dash-grid** (4× 92–96px tiles + chart block — Publisher L530–540, Agency L316–318), **detail** (120px block + bars — Publisher L556–562).
**Path:** `lib/core/widgets/dc_skeletons.dart` (or add named constructors to `loading_state.dart`).

### 6c. Settings/grouped list — `DcListSection` + `DcListRow` — NEW (broadly reused)
**DC** (Chrome settings L118–157; Private profile L289–303; About L148–156; Agency about contact L144–150): section caption **12/700** `--onVar` ls .3; card surface/divider/14 overflow-hidden; row padding `13 14` gap12 — leading icon **22** `--onVar` + label **14/600** + trailing (value 13 `--onVar` + `chevron_left` 20 / **`AppToggle`** / `DcStatusChip` verified / tonal action button); rows split by 1px divider.
**Path:** `lib/core/widgets/ds/dc_list_section.dart`
**Params:** `DcListRow.value({icon,label,value,onTap})`, `.toggle({icon,label,sub,value,onChanged})`, `.trailing({icon,label,child})`.
**Used by:** Settings (appearance/general/notifications/about), Private profile (معلوماتي الخاصة), Agency about-contact card.

### 6d. Label-only segmented pill — extend `AppSegmentedControl`
**DC** (theme-mode L110–115, state-preview L174–179): `--surface2` pill container radius100 padding4 gap3; segment flex h38 radius100 — on→`--surface` bg + 13/700 + shadow, off→transparent + `--onVar` 13/600. Make `AppSegmentedSegment.icon` nullable.

### 6e. Bottom nav badge — extend `main_bottom_nav.dart`
**DC** (Publisher L594–605): selected pill **60×30** `--sec`/`--onSec` (icon 22 filled); red count badge min16 h16 radius-pill 9/700 with 1.5px `--surface` border. Badges: الاستفسارات=2, المعاينات=1.

### 6f. Notification bell + dot & unread-count header chip
**DC** (dashboard bell L81: 40px btn + `notifications` 23 + **8px** red dot with 1.5px `--header` border; inquiries header chip L411 "2 غير مقروء" `rgba(255,255,255,.16)` pill + 7px red dot). Small — fold into a `DcCrownIconButton(badge:)` extension + a `DcHeaderCountChip`.

### 6g. Quick-link grid tile — extend `dashboard_tile.dart`
**DC** (Publisher L122–130): 3-col grid gap9; tile surface/divider/14 padding `14 6`; **44×44** radius12 `--tonal` icon 23 + optional red count badge (top/end −5, 2px `--surface` border); label 11/600 center.

### 6h. Chat helpers (reuse `chat_bubble.dart`) — add `DcDayDivider` + `DcQuickReplies`
**DC** (Publisher inquiry L444–460; AI Features L193–216): day-divider chip `--surface2`/`--onVar` 11/600 pill (L445); quick-reply row = scroll-x outline pills h32 padding `0 13` 12/600 (L452–455); AI suggestion rows + bot result mini-cards reuse the same bubble + mini listing card.

---

## 7. Chart-stack recommendation (founder wants to compare native / fl_chart / syncfusion / graphic)

**Reality of the DC v3 charts:** all are trivial — vertical bars, one 4-tier **stacked** bar + legend, thin horizontal/distribution bars. **No axes, gridlines, tooltips, curves, donuts, or line/area.** The repo already renders these hand-built and **token-linter-clean** (`TokenBarChart`, `TokenHbarList`) with **zero deps**.

**Recommendation for Tiers A–D:** **stay native (CustomPaint/Flex)** — extend the existing token charts (§3). Rationale:
1. **Token linter** (`tool/lint_design_tokens.dart`) forbids raw `Color()/EdgeInsets/BorderRadius.circular(n)` — every third-party chart package hard-codes these internally *and* at every call-site (colors/paddings), forcing widespread lint suppressions and breaking the "flows through the token system" principle.
2. App-size / cold-start budget (already tracking a cold-start baseline) — no reason to add a charting dep for four bar shapes.
3. The DC bar visuals are pixel-specified (opacity tiers, 6px top radius, 22–26px caps) — trivial in Flex, fiddly to force onto a generic library.

**Where to actually run the experiment:** the **Admin (Tier E)** dashboard — that's where richer, DC-unspecified charts (revenue/GMV **line/area**, category **donut**, cohort **heatmap**) will land. Prototype there, and prototype **`fl_chart` only**:
- `fl_chart` — lightest, pure-Dart, most Flutter-idiomatic; wrap it in a `DcChart` adapter that injects `AppColors`/`AppSpacing` so call-sites stay token-clean and the linter sees only the adapter.
- **Advise against** `syncfusion_flutter_charts` (community-license constraints + heavy binary) and `graphic` (grammar-of-graphics is overkill for these shapes and has its own literal-color API).

**pubspec deps (only if the Tier-E line/area/donut prototype proceeds):**
```yaml
dependencies:
  fl_chart: ^0.69.0   # evaluate for Admin revenue trend + category donut ONLY
```
Keep it out of pubspec for Tiers A–D; those ship on the native token charts. If `fl_chart` is rejected after the Admin spike, the fallback is a native `DcLineChart`/`DcDonut` CustomPainter (both are ~100 lines and stay token-clean).

---

## 8. Tier-specific (NOT core-shared, but flag if reused)
- **Compare matrix** (Features L74–92): sticky first-column data grid — unique; build as `DcCompareTable` under the feature, promote to shared only if a second matrix appears.
- **Reels overlay + right action rail** (Features L98–142) and **Panorama 360 scene switcher** (L146–169): media-screen chrome; `panorama_viewer`/`video_player` already in pubspec. The reel action-rail (heart/comment/share stacked buttons) and the scene thumbnail strip are screen-local.
- **Lead detail contact card / stage changer / reminder banner / note composer** (Publisher L358–401): compose from `DcListSection` + `DcMetaChip` + `AppButton(whatsapp)` + a `--tonal` reminder banner (reuse the doc-verify banner idiom).

---

### File-placement summary
`lib/core/widgets/ds/`: `dc_status_chip.dart` (+`dc_status_tokens.dart`), `dc_trend_delta.dart`, `dc_meta_chip.dart`, `dc_timeline.dart`, `dc_doc_row.dart`, `dc_activity_row.dart`, `dc_review_card.dart`, `dc_rating_summary.dart`, `dc_write_review_sheet.dart`, `dc_onboarding_slide.dart`, `dc_page_dots.dart`, `dc_list_section.dart`, `dc_data_table.dart`, `dc_stat_card.dart` (or extend `stat_card.dart`).
`lib/core/widgets/charts/`: `dc_bar_chart_card.dart`, `dc_stacked_bar_chart.dart`, `dc_rating_distribution.dart` (reuse `token_bar_chart.dart`, `token_hbar_list.dart`).
`lib/core/widgets/`: `dc_skeletons.dart`; **extend** `segmented_control.dart`, `main_bottom_nav.dart`, `dashboard_tile.dart`, `crown_underline_tabs.dart`, `loading_state.dart`, `empty_state.dart`, `error_state.dart`.
