# AlNujom — Tier B (Agency) Design Spec

Source: `AlNujom - Agency.dc.html` (Claude-Design "Blue Crown" prototype). This is a single multi-screen file switched by `state.screen` (`profile` | `manage`), a per-screen tab (`profileTab` / `manageTab`), and `dataState` (`ok` | `empty` | `loading` | `error`). The demo control bar (lines 26–57) and the 400×842 phone frame (line 60) are prototype chrome only — ignore for Flutter.

Fonts: **Noto Sans Arabic** for all Arabic copy; **Roboto** for numerals / Latin (prices, phone, counts, ratings, deltas, chart values). Western digits everywhere. All animations: `scr` (fade+translateY 8px, .2s) on OK screens, `fade` (.2s) on non-OK.

## Token legend (hex → DC token, light / dark)

| CSS var | Hex light / dark | DC token name (use in Flutter) |
|---|---|---|
| `--bg` | #EAEDF2 / #0C0C10 | `bg` |
| `--surface` | #FFFFFF / #131318 | `surface` (card) |
| `--surface2` | #F2F4F9 / #1C1D25 | `surface2` |
| `--tonal` / `--onTonal` | #E2E9FF / #26356E · #123287 / #DCE4FF | `tonal` / `onTonal` |
| `--sec` / `--onSec` | #DAE1F6 / #2A3352 · #182C58 / #DEE4FA | `selected`/`pill` / `onSelected` |
| `--on` | #1A1C22 / #E7E8ED | `text` |
| `--onVar` | #5B6070 / #A7ABB8 | `textMuted` |
| `--outline` | #C6CAD6 / #3B3D48 | `border` |
| `--divider` | #E7EAF1 / #26272F | `divider` |
| `--primary` / `--onPrimary` | #1F4FE6 / #AEC2FF · #FFFFFF / #0A2063 | `primary` / `onPrimary` |
| `--header` | #1A3FC4 / #12235E | `crownHeader` (white text on it) |
| `--green`/`--greenC`/`--onGreenC` | #0E7A3C·#E4F3E9·#0A5A2C (dark #74D99A·#12331F·#A9E9C0) | `verified` / `verifiedBg` / `onVerifiedBg` |
| `--wa` | #1FA855 / #2AAE60 | `whatsapp` |
| `--gold`/`--goldC` | #8A6912·#FBEDC7 (dark #E6C56A·#39300B) | `gold` / `goldBg` (Featured/rating only) |
| `--red`/`--redC`/`--onRedC` | #D93B3B·#FBE6E6·#B42318 | `red` / `redBg` / `onRedBg` |
| `#FF5B6E` (raw) | heart fill | `heart` |
| `--scrim` | rgba(15,18,30,.42) / rgba(0,0,0,.5) | `scrim` (image overlays) |

Accent is themeable (`props.accent` overrides `--primary`/`--header`); default keeps #1F4FE6 / #1A3FC4.

---

# SCREEN A — Agency Profile (`screen:'profile'`)

Crown title in header identity block, not a text title. Four tabs: **العقارات** (`listings`) · **نبذة** (`about`) · **الأعضاء** (`members`) · **التقييمات** (`reviews`).

**Structural note (shell):** the ENTIRE screen is one vertical scroller (`flex:1; overflow-y:auto`) and the rich crown header is `position:sticky; top:0; z-index:20`. This is a **collapsing/sticky rich header**, NOT the fixed-crown `DcCrownScaffold`. The white sheet is `radius 20 20 0 0`, `margin-top:-14`, `z-index:2`, `min-height:100%`, `padding 16 14 26`, and slides up under the sticky crown. Implement as a `CustomScrollView` (SliverPersistentHeader / pinned rich header) or a scroll body with a sticky header widget — see **New component: `DcAgencyProfileHeader`**.

## A0 · Crown header (shared across all 4 profile tabs)
Background `crownHeader`. Top-to-bottom:

1. **Top action row** — `padding 34px 12px 0`, space-between.
   - Leading: **back** button, 40×40, transparent bg, circle, icon `arrow_forward` 24px white; active bg `rgba(255,255,255,.14)`.
   - Trailing group (gap 2px): **share** button (icon `share` 22px white, 40×40) + **flag** button (icon `flag` 22px white, 40×40), same transparent-circle style.
   - ⚠️ These are transparent white-icon buttons, NOT the white-filled 42px `DcCrownIconButton`. Use a transparent variant.
2. **Identity block** — `padding 6px 16px 16px`, flex gap 13px, center.
   - Avatar tile: 66×66, `radius 18`, bg #FFFFFF, centered icon `storefront` 36px in `crownHeader` color.
   - Right column (flex 1):
     - Name row (gap 6): name `{{ ag.name }}` = "مكتب الشام العقاري", 19px/700 white Noto; icon `verified` (FILL 1) 19px white.
     - Meta row (`margin-top 5`, gap 12, color `rgba(255,255,255,.9)`, 12px): rating cluster [icon `star` FILL 15px `gold` · **bold** rating `4.8` Roboto · " (126)"] then "48 إعلاناً".
     - Since line (`margin-top 3`, 11px, `rgba(255,255,255,.7)`): "عضو منذ 2019".
3. **CTA row** — `padding 0 16px 14px`, gap 8.
   - **اتصال**: flex 1, h40, `radius 100`, bg #FFFFFF, text `crownHeader` 13/700, icon `call` 18; active scale .97.
   - **واتساب**: flex 1, h40, `radius 100`, bg `whatsapp`, text white 13/700, icon `chat` 18.
   - **Follow toggle** (44×40, `radius 100`): unfollowed → transparent bg, 1px `rgba(255,255,255,.5)` border, icon `bookmark_add` 20 white; followed → bg `rgba(255,255,255,.2)`, icon `bookmark_added` (FILL) 20 white.
4. **Underline tabs** — `padding 0 16`, gap 20, `overflow-x:auto`. Selected: 14/700 white, `border-bottom 3px #fff`, pb 11. Unselected: 14/600 `rgba(255,255,255,.6)`, transparent 3px border; active color `.85`. → **`CrownUnderlineTabs`** (labels العقارات/نبذة/الأعضاء/التقييمات, fontSize 14).

## A1 · Tab العقارات (`tabListings`)
White-sheet body. Column, gap 12. Maps to **`DsListingCard`** repeated for `LISTINGS` (4 items). Each card:
- Container: bg `surface`, 1px `divider` border, `radius 12`, overflow hidden.
- **Media**: `aspect-ratio 16/10`, bg `surface2`, centered placeholder icon `image` 44px `border` color.
  - Verified badge (if `c.verified`): top 8 / right 8; bg `verifiedBg`, text `onVerifiedBg`; `padding 3px 8px`, `radius 7`, 11/700; icon `verified` FILL 14 + "موثّق".
  - Heart button: top 7 / left 7; 33×33 circle, bg `scrim`; saved → icon `favorite` FILL 19 `heart` (#FF5B6E); not saved → `favorite` 19 white; active scale .9.
  - Photo count: bottom 8 / left 8; bg `scrim`, white, `padding 3 8`, `radius 7`, 11/600 Roboto; icon `photo_library` 14 + count.
- **Body** `padding 10 12 12`:
  - Price 18/700 `text` Roboto (e.g. `$210,000`).
  - Specs row (`margin-top 7`, gap 10, `textMuted` 13 Roboto): `king_bed` 17 + beds · dot (3×3 circle currentColor opacity .45) · `bathtub` 17 + baths · dot · `square_foot` 17 + area.
  - Title (`margin-top 8`, 14 `text` Noto, ellipsis).
  - Location row (`margin-top 4`, gap 5, `textMuted` 12): `location_on` 15 + loc (ellipsis) · "·" opacity .5 · ago.

Listings data: 4 rows (`a1`–`a4`), prices $210,000 / $265,000 / $135,000 / $310,000; `a3` unverified.

## A2 · Tab نبذة (`tabAbout`)
Column, gap 14.
- **نبذة عن الوكالة** block: heading 14/700 `text` (mb 7); body `{{ ag.bio }}` 14 `text`, line-height 1.9.
- **مناطق التغطية**: heading 14/700 (mb 8); chip wrap gap 7 — each area chip bg `selected`(`--sec`), text `onSelected`, `padding 6 12`, `radius 100`, 12/600. Areas: أبو رمانة، المزة، كفر سوسة، المالكي، المهاجرين.
- **التخصصات**: heading 14/700 (mb 8); chip wrap gap 7 — each bg `surface2`, text `text`, `padding 6 12`, `radius 100`, 12/600. Values: شقق سكنية / فلل وقصور / عقارات فاخرة / استثمار عقاري.
- **Contact card** (`DcContactInfoCard`): 1px `divider` border, `radius 14`, overflow hidden. Three rows `padding 12 13`, gap 11, each leading icon 20px `primary`; between rows a 1px `divider` line:
  - `call` + phone `+963 11 331 2200`, 13 `text` Roboto, `direction:ltr; text-align:right`.
  - `schedule` + hours "السبت – الخميس · 9 ص إلى 7 م", 13 Noto.
  - `location_on` + address "أبو رمانة، شارع المهدي بن بركة، دمشق", 13 Noto.
- **Map placeholder** (`DcMapPlaceholder`): height 130, `radius 14`, bg `surface2` with grid lines (`linear-gradient(divider 1px…)`, size 26×26), centered icon `location_on` FILL 34px `primary`.

## A3 · Tab الأعضاء (`tabMembers`)
Column, gap 10. Repeats `MEMBERS` (4). Each row (**`DcMemberRow`**, chat variant): bg `surface`, 1px `divider`, `radius 14`, `padding 12`, gap 11, center.
- Avatar 46×46 circle, bg `tonal`, initial 17/700 `onTonal` Noto.
- Info: name 14/700 `text`; sub (`margin-top 3`, 12 `textMuted`): "{role} · {listings} إعلاناً".
- Trailing chat button 34×34 circle, 1px `outline`, bg `surface`, icon `chat` 18 `textMuted`; active bg `surface2`.

Members: زياد الشام (مدير المكتب,18) · ريم حمود (مسؤولة مبيعات,12) · أنس خليل (وكيل عقاري,9) · ملك دياب (وكيلة عقارية,9).

## A4 · Tab التقييمات (`tabReviews`)
1. **Rating summary card** (`DcRatingSummaryCard`): flex gap 16, center, bg `surface2`, `radius 14`, `padding 14`.
   - Left (center): big rating `4.8` 38/700 `text` Roboto line-height 1; star row (`mt 5`, gap 2) = **5** filled `star` FILL 15px `gold` (`avgStars` = 5 always-filled); "126 تقييم" `mt 4` 11 `textMuted`.
   - Right (flex 1, gap 5): 5 distribution bars (`DcRatingBar`), one per star level. Each row gap 7: star number 11 `textMuted` Roboto (width 8) · icon `star` 12 `gold` (unfilled) · track flex 1, h6, `radius 3`, bg `divider`, fill height 100% bg `gold` `radius 3` width `d.w`. Widths from counts [98,20,5,2,1]/126 → **78% / 16% / 4% / 2% / 1%** (star 5→1).
2. **Write-review button**: `mt 12`, w100, h44, 1px `outline`, `radius 100`, bg `surface`, text `text` 13/700; icon `rate_review` 19 + "اكتب تقييماً"; active bg `surface2`. → `AppButton` outlined variant.
3. **Reviews list** (`mt 14`, gap 12), repeats `REVIEWS` (3) — each **`DcReviewCard`**: bg `surface`, 1px `divider`, `radius 14`, `padding 13`.
   - Header row gap 10, center: avatar 38×38 circle bg `tonal`, initial 15/700 `onTonal`; info flex 1 → name 13/700 `text`, star row (`mt 2`, gap 1) = 5 stars, on → `star` FILL 13 `gold`, off → `star` 13 `outline`; time 11 `textMuted`.
   - Body (`mt 9`, 13 `text`, line-height 1.75).
   Reviews: محمود الأحمد (5,منذ أسبوع) · رنا العلي (5,منذ 3 أسابيع) · سامر خوري (4,منذ شهر).

---

# SCREEN B — Agency Management (`screen:'manage'`)

Crown title: **"إدارة الوكالة"**. Four tabs: **تعديل الملف** (`edit`) · **الأعضاء والأدوار** (`members`) · **التحليلات** (`analytics`) · **التوثيق** (`verify`).

**Structural note (shell):** header is `flex-shrink:0` (fixed) over a `flex:1; overflow-y:auto` body; whole screen bg is `surface`. Unlike Profile there is **no rounded white sheet and no −14 overlap** — the white body is flush under the crown. Maps to **`DcCrownScaffold`** with a **flat (non-rounded, no-overlap) body** variant: `leading` = back, `title` = "إدارة الوكالة", `crownBottom` = `CrownUnderlineTabs`. Body `padding 16 14 24`.

## B0 · Crown header (shared across manage tabs)
Bg `crownHeader`, `padding 34px 8px 0`.
- Title row (gap 6, pb 12): back button 40×40 transparent circle icon `arrow_forward` 24 white; title "إدارة الوكالة" 18/700 white Noto.
- Underline tabs: gap 18, `padding 0 10`, `overflow-x:auto`; selected 14/700 white + 3px white underline (pb 11); unselected 14/600 `rgba(255,255,255,.6)`. → `CrownUnderlineTabs` (تعديل الملف / الأعضاء والأدوار / التحليلات / التوثيق, fontSize 14).

## B1 · Tab تعديل الملف (`mTabEdit`)
1. **Logo uploader** (`DcLogoUploader`, centered column gap 9): 82×82, `radius 20`, bg `surface2`, **1px dashed** `outline`, centered icon `storefront` 32 `textMuted`; camera badge at bottom −4 / left −4: 30×30 circle bg `primary`, 2px `surface` border, icon `photo_camera` 16 `onPrimary`. Label "تغيير الشعار" 12/700 `primary`.
2. **Form** (`mt 16`, column gap 14). Each field = label (12/700 `textMuted`, mb 6) + control (**`DcFormField`**):
   - **اسم الوكالة**: input w100, h46, 1px `outline`, `radius 12`, bg `surface2`, `padding 0 14`, 14 `text` Noto. Value "مكتب الشام العقاري".
   - **النبذة التعريفية**: textarea w100, h96, `radius 12`, bg `surface2`, `padding 11 14`, 14, line-height 1.7, `resize:none`. (**`DcFormTextArea`**)
   - **رقم الهاتف**: input h46 same, `direction:ltr; text-align:right`, Roboto. Value "+963 11 331 2200".
   - **مناطق التغطية**: chip wrap gap 7. Removable chip (**`DcRemovableChip`**): bg `selected`, text `onSelected`, `padding 6 8 6 12`, `radius 100`, 12/600 + close button 16×16 icon `close` 15 `onSelected`. Trailing **add** chip (**`DcAddChip`**): 1px dashed `outline`, transparent bg, `primary` text, `padding 6 12`, `radius 100`, 12/700, icon `add` 15 + "إضافة". Areas seed = 5 (same as A2).
3. **Save button** `حفظ التغييرات`: `mt 20`, w100, h48, `radius 100`, bg `primary`, `onPrimary` 14/700; active scale .98. → `AppButton` filled.

## B2 · Tab الأعضاء والأدوار (`mTabMembers`)
1. **Invite button** `دعوة عضو`: w100, h46, `radius 100`, bg `primary`, `onPrimary` 14/700, icon `group_add` 20, `mb 14`. → `AppButton` filled with icon.
2. **Members list** (gap 10), repeats `MEMBERS` — each **`DcMemberRow`** (role variant): bg `surface`, 1px `divider`, `radius 14`, `padding 12`, gap 11.
   - Avatar 44×44 circle bg `tonal`, initial 16/700 `onTonal`.
   - Info: name 14/700; role badge (`mt 4`): primary role → bg `tonal`, text `onTonal`; other → bg `surface2`, text `textMuted`; badge `padding 2 9`, `radius 100`, 10/700. (`m.primary` = "مدير المكتب").
   - Trailing `more_vert` button 34×34 transparent circle, icon 20 `textMuted`; active bg `surface2`.

## B3 · Tab التحليلات (`mTabAnalytics`)
1. **KPI grid**: 2 cols, gap 10. 4 cards (`agencyKpis`), each **`DcKpiCard`**: bg `surface`, 1px `divider`, `radius 14`, `padding 12 12 11`.
   - Top row space-between: icon chip 32×32 `radius 9` bg `tonal`, icon 19 `onTonal`; delta pill — up → `arrow_upward` 14 + delta, color `verified`(green) 11/700 Roboto; down → `arrow_downward` 14 + delta, color `red`.
   - Value (`mt 9`) 21/700 `text` Roboto, line-height 1.1.
   - Label (`mt 3`) 12/600 `text` Noto.
   - Data: `campaign` **48** إجمالي الإعلانات +4 ↑ · `visibility` **24,500** مشاهدات الشهر +9% ↑ · `groups` **512** عملاء محتملون +6% ↑ · `bolt` **88%** معدّل الاستجابة −2% ↓.
2. **Bar chart card** (`mt 12`): bg `surface`, 1px `divider`, `radius 14`, `padding 14`.
   - Title "مشاهدات إعلانات الوكالة" 14/700 `text`.
   - Chart (`DcSimpleBarChart`): `mt 16`, flex align-end, gap 8, height 120. **Type: vertical bar, single-hue.** 6 bars; each column flex 1, align-center, gap 7, justify-end; bar w100, `max-width 24`, `radius 6 6 0 0`, bg **`primary`** (single hue — no rainbow), height = value/max. Label below 10 `textMuted` Noto.
   - Data `mo`: vals [3200,3800,3500,4100,4290,4820]; labels [شبا, آذا, نيس, أيا, حزي, تمو] (Feb–Jul). Heights (v/4820): **66% / 79% / 73% / 85% / 89% / 100%**. No Y axis, no gridlines; X labels only.
3. **أعلى الأعضاء أداءً** heading (`mt 18`, 14/700 `text`, `padding 0 2`).
4. **Top-members list** (`mt 9`): bg `surface`, 1px `divider`, `radius 14`, overflow hidden; rows separated by 1px `divider` (all but first). Each **`DcMemberProgressRow`** `padding 11 13`, gap 11:
   - Avatar 36×36 circle bg `tonal`, initial 14/700 `onTonal`.
   - Info: name 13/600; progress (`mt 4`, h5, `radius 3`, bg `divider`) fill height 100% bg **`primary`** `radius 3` width = listings/max.
   - Trailing listings count 13/700 `text` Roboto.
   - Sorted desc: زياد الشام 18 (**100%**) · ريم حمود 12 (**67%**) · أنس خليل 9 (**50%**) · ملك دياب 9 (**50%**).

## B4 · Tab التوثيق (`mTabVerify`)
1. **Info banner** (`DcInfoBanner`): flex gap 11, bg `tonal`, `radius 14`, `padding 13 14`. Icon `verified_user` 24 `onTonal`; title "التوثيق قيد الاستكمال" 13/700 `onTonal`; body (`mt 3`, 12 `onTonal` opacity .9, line-height 1.65) "أكمل رفع المستندات المطلوبة ليحصل حساب وكالتك على شارة التوثيق الرسمية.".
2. **Document rows** (`mt 16`, gap 10), repeats `DOCS` (4) — each **`DcDocRow`**: bg `surface`, 1px `divider`, `radius 14`, `padding 13`, gap 11, center.
   - Leading icon tile 40×40 `radius 11` bg `surface2`, icon `description` 21 `textMuted`.
   - Info flex 1: label 13/700 `text`; **status badge** (`mt 5`, `DcStatusBadge`, `padding 2 8`, `radius 7`, 10/700):
     - `accepted` → bg `verifiedBg`, text `onVerifiedBg`, icon `check_circle` FILL 12 + "مقبول".
     - `review` → bg `surface2`, text `textMuted`, icon `hourglass_top` 12 + "قيد المراجعة".
     - `required` → transparent bg, 1px `outline` border, text `textMuted`, `padding 1 8`, "مطلوب" (no icon).
   - Trailing: `required` → **رفع** button h34, `padding 0 13`, `radius 100`, bg `tonal`, text `onTonal` 12/700, icon `upload` 16; `done` (any non-required) → `visibility` button 34×34 transparent circle, icon 19 `textMuted`.
   - Docs: السجل التجاري = accepted · الهوية الشخصية للمالك = accepted · إثبات عنوان المكتب = review · رخصة مزاولة المهنة = required.
3. **Submit button** `إرسال للمراجعة`: `mt 18`, w100, h48, `radius 100`, bg `primary`, `onPrimary` 14/700. → `AppButton` filled.

---

# SHARED — Non-OK states (`dataState ≠ ok`, both screens)

Simple fixed crown: bg `crownHeader`, `padding 34 12 16`, gap 6 — back button (40×40, `arrow_forward` 24 white) + title `{{ currentTitle }}` 19/700 white Noto, `padding-inline-start 4`. `currentTitle` = "صفحة الوكالة" (profile) / "إدارة الوكالة" (manage). White sheet `radius 20 20 0 0`, `mt −14`, `z 2`, `min-height 100%`.

**Shimmer** (all skeletons): `linear-gradient(90deg, surface2 25%, divider 37%, surface2 63%)`, `background-size 400% 100%`, `animation shim 1.4s`.

- **Loading** (`isLoading`):
  - `skDash` (only manage + analytics) → **`DcSkeletonDashboard`**: `padding 16 14`; 2-col grid gap 10 of four 92px `radius 14` shimmer tiles; then `mt 12` a 180px `radius 14` shimmer block.
  - `skList` (everything else) → **`DcSkeletonListRow`** ×4: `padding 14`, gap 12; each 1px `divider`, `radius 14`, overflow hidden — image `aspect 16/10` shimmer + body `padding 11` gap 8 with a 40%×15px and a 75%×12px shimmer bar (`radius 6`).
- **Empty** (`isEmpty`): `padding 60 32`, centered. Circle 88×88 bg `tonal`, icon `{{ emptyIcon }}` 44 `onTonal` (mb 20); title 18/700 `text`; body (`mt 8`, 14 `textMuted`, line-height 1.7). Per-screen/tab `emptyMap`:
  - profile/listings `apartment` — "لا إعلانات" / "لا توجد إعلانات منشورة لهذه الوكالة حالياً."
  - profile/about `info` — "لا نبذة" / "لم تُضِف الوكالة نبذة تعريفية بعد."
  - profile/members `groups` — "لا أعضاء" / "لم تُضِف الوكالة أعضاء الفريق بعد."
  - profile/reviews `star` — "لا تقييمات بعد" / "كن أول من يقيّم هذه الوكالة بعد التعامل معها."
  - manage/edit `edit` — "لا بيانات" / "تعذّر تحميل بيانات ملف الوكالة."
  - manage/members `group_add` — "لا أعضاء" / "ادعُ أعضاء فريقك للانضمام إلى حساب الوكالة."
  - manage/analytics `bar_chart` — "لا تحليلات" / "ستظهر تحليلات الوكالة بعد نشر أول إعلان."
  - manage/verify `verified_user` — "لا مستندات" / "ابدأ برفع مستندات التوثيق المطلوبة."
- **Error** (`isError`): same layout; circle 88×88 bg `redBg`, icon `cloud_off` 44 `onRedBg`; title "تعذّر تحميل البيانات" 18/700; body "حدث خطأ في الاتصال بالخادم. تحقّق من الإنترنت وحاول مرة أخرى." (`mt 8`, 14 `textMuted`). Retry button (`mt 22`, h46, `padding 0 24`, `radius 100`, bg `primary`, `onPrimary` 14/700, icon `refresh` 20 + "إعادة المحاولة").

---

# Shell mapping summary

| Screen | Shell | leading | actions | crownBottom |
|---|---|---|---|---|
| A Profile (all tabs) | **NEW `DcAgencyProfileHeader`** over a `CustomScrollView` (sticky rich header + rounded −14 sheet). NOT plain `DcCrownScaffold`. | back (`arrow_forward`, transparent) | `share`, `flag` (transparent white-icon) | `CrownUnderlineTabs` (4) — sits below identity+CTA block, all inside the sticky header |
| B Manage (all tabs) | `DcCrownScaffold` **flat body** variant (no rounded sheet, no −14 overlap, body bg = surface) | back | — | `CrownUnderlineTabs` (4) |
| Non-OK (shared) | `DcCrownScaffold` (rounded sheet) with title only | back | — | — |

Reuse existing: `DsListingCard` (A1), `AppButton` (call/whatsapp/save/invite/submit/write-review/retry → filled/outlined/whatsapp variants), `CrownUnderlineTabs`, `DcCrownIconButton` (needs a **transparent** variant for the crown back/share/flag here), `AppColors.of`/`AppTextStyles.of`/`AppSpacing`/`AppRadii`, `MoneyFormatter` for prices.

# New reusable components to build once

1. **`DcAgencyProfileHeader`** — sticky rich crown: avatar tile + name+`verified` + rating/listings meta + since line + Call/WhatsApp/Follow CTA row + `CrownUnderlineTabs`. Collapses as the page scrolls.
2. **`DcMemberRow`** — avatar + name + subtitle/role-badge + trailing slot. Variants: `chat` (A3, 46px avatar, chat button), `role` (B2, 44px avatar, role badge, `more_vert`).
3. **`DcMemberProgressRow`** — compact 36px avatar + name + single-hue `primary` progress bar + trailing count (B3 top members).
4. **`DcRatingSummaryCard`** + **`DcRatingBar`** — big score + 5 gold stars + count, and the gold 5→1 distribution bars.
5. **`DcReviewCard`** — avatar + name + on/off star row + time + body.
6. **`DcKpiCard`** — icon chip + up/down delta pill + value + label (2-col tile).
7. **`DcSimpleBarChart`** — single-hue (`primary`) vertical bars, X labels only, height-normalized to max, `radius 6 6 0 0`, max bar width 24. Reuse for any agency/analytics bars.
8. **`DcStatusBadge`** — pill with variants `accepted`/`review`/`required` (green/neutral/outlined) + optional leading icon.
9. **`DcDocRow`** — icon tile + label + `DcStatusBadge` + trailing upload/view action.
10. **`DcInfoBanner`** — tonal banner: leading icon + title + body.
11. **`DcLogoUploader`** — dashed square + camera badge + label.
12. **`DcRemovableChip`** + **`DcAddChip`** — pill with close button; dashed "add" pill.
13. **`DcContactInfoCard`** — bordered grouped rows (icon + value + dividers).
14. **`DcMapPlaceholder`** — grid-lined `surface2` box with centered `location_on` pin.
15. **`DcFormField`** / **`DcFormTextArea`** — label + `surface2` input (h46) / textarea (h96, line-height 1.7); phone variant forces LTR + right-align + Roboto.
16. **`DcSkeletonListRow`** / **`DcSkeletonDashboard`** — the two shimmer skeleton layouts.
