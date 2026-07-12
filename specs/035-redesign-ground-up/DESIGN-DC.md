# DESIGN-DC.md — the approved design (build bible)

Source of truth: `dc-handoff/alnujom-real-estate-marketplace/project/AlNujom.dc.html`
(Claude Design handoff, founder-approved). **Implement Flutter to match these
values exactly.** This resolves Gate M — the "Blue Crown" direction won.

Fonts: **Noto Sans Arabic** (all Arabic text) · **Roboto** (digits, prices) ·
**Material Symbols Outlined** (icons). **Western digits everywhere** ($195,000,
"210 م²", "منذ 3 أيام") — this REVERTS the Stage-2 Arabic-Indic pass.

## Design tokens (exact)

| role | light | dark | notes |
|---|---|---|---|
| bg (scaffold) | `#EAEDF2` | `#0C0C10` | `--bg` → `surface` |
| surface (cards/sheets) | `#FFFFFF` | `#131318` | `--surface` → `card` |
| surface2 (placeholders/fact strip/thumbs) | `#F2F4F9` | `#1C1D25` | `--surface2` → `surfaceVariant` |
| tonal (tonal btn bg) | `#E2E9FF` | `#26356E` | `--tonal` → `primaryContainer` |
| onTonal | `#123287` | `#DCE4FF` | → `onPrimaryContainer` |
| sec (segment sel / nav pill / toggle-on) | `#DAE1F6` | `#2A3352` | `--sec` → NEW `secondaryContainer` |
| onSec | `#182C58` | `#DEE4FA` | → NEW `onSecondaryContainer` |
| on (text) | `#1A1C22` | `#E7E8ED` | → `onSurface` |
| onVar (secondary text) | `#5B6070` | `#A7ABB8` | → `onSurfaceVariant` + `textMuted` |
| outline (chip/segment/btn border) | `#C6CAD6` | `#3B3D48` | → `outlineStrong` |
| divider (card border, row hairline) | `#E7EAF1` | `#26272F` | → `outline` + `divider` |
| primary | `#1F4FE6` | `#AEC2FF` | → `primary` |
| onPrimary | `#FFFFFF` | `#0A2063` | |
| header (crown / status bar) | `#1A3FC4` | `#12235E` | NEW `brandHeader` (+onBrandHeader=#FFF) |
| headerField (search in crown) | `#FFFFFF` | `#20232C` | NEW `brandHeaderField` |
| green | `#0E7A3C` | `#74D99A` | → `success` = `verified` |
| greenC | `#E4F3E9` | `#12331F` | → `verifiedContainer` |
| onGreenC | `#0A5A2C` | `#A9E9C0` | → `onSuccess` / verified text |
| greenBorder | `#C3E4CF` | `#1E4A30` | NEW `verifiedBorder` (verify card only) |
| wa (WhatsApp detail CTA) | `#1FA855` | `#2AAE60` | → `whatsapp` |
| gold | `#8A6912` | `#E6C56A` | → `tertiary` (featured text/icon) |
| goldC | `#FBEDC7` | `#39300B` | → `accentContainer`/gold container |
| red (badges) | `#D93B3B` | `#FF6B6B` | → `error` / badge |
| onRed | `#FFFFFF` | `#3A0A0A` | |
| scrim (photo overlays) | `rgba(15,18,30,.42)` | `rgba(0,0,0,.5)` | → `scrim`/`photoOverlay` |
| heart (saved) | `#FF5B6E` | `#FF5B6E` | both themes |

Phone frame reference: 400×842, content inset 11px, radius 35 (device chrome
only — not in-app). App bg = `bg`.

## Global overlays
- **Status bar** height 30, bg = `brandHeader`, white, LTR: `9:41` start,
  signal_cellular_alt + wifi + battery_full end. (On device this is the real
  Android status bar — we just tint it `brandHeader` via SystemUiOverlayStyle.)
- **Gesture pill**: 120×5, radius 3, `onSurface` @ .26 (device draws its own —
  no need to render).

## SCREEN 1 — HOME
Column: scrollable body + fixed bottom nav. FAB floats above nav.

### Crown header (`brandHeader` bg, padding 36/16/30)
1. Row (space-between, mb 13):
   - start: white rounded square 33px r9, `star` filled icon 22 `brandHeader`-colored + "النجوم" 21/700 white.
   - end: two 42px circular buttons — `chat_bubble` 24 white w/ red badge "2"; `notifications` 24 white w/ red badge "5". Badge: min16 h16 r100, red, white 10/700 Roboto, 1.5px `brandHeader` border, top5 end5.
2. Location button (mb 13): `location_on` filled 18 white + "دمشق وريفها" 14/500 white + `expand_more` 20 white/.9.
3. Search field button: `brandHeaderField` bg, h48 r12, shadow `0 2px 6px rgba(0,0,0,.14)`, padding 0/14, gap10: `search` 22 `onVar` + "ابحث عن شقة، فيلا، أرض…" 14 `onVar` (flex) + 1px×22 `divider` + `tune` 23 `primary`.

### Content sheet (`surface`/white, r 20/20/0/0, margin-top -18, padding 16/0/26, min-h 420)
4. **Category grid**: 4-col grid, gap 4/0, padding 2/10/6. 8 items. Each button col, gap7, padding 9/2, r12 (active bg surface2): tonal square 54px r15 `tonal` bg + icon 27 `onTonal`; label 12/500 `on`.
   Cats (icon/label): apartment/شقق · villa/فلل · landscape/أراضٍ · storefront/محلات · business_center/مكاتب · agriculture/مزارع · domain/بناء كامل · grid_view/المزيد.
5. **Segmented** (padding 10/16/2): row, border 1px `outline`, r100 pill, h42. 3 segs. Selected: `sec` bg, `check` 18 + label 14/700 `onSec`. Unselected: transparent, 14/600 `on`. Segs: للبيع · للإيجار · إيجار يومي.
6. **Featured section** header (padding 18/16/9): gold filled `star` 20 + "عقارات مميّزة" 16/700 `on`; "عرض الكل" 13/600 `primary` (→ search). Then horizontal rail (gap12, padding 2/16/6) of **featured cards** (see card spec, 250px wide).
7. **Latest section** header (padding 16/16/9): "وصلت حديثاً" 16/700; "عرض الكل". Then vertical **feed** (gap12, padding 0/16) of listing cards.

### FAB (`onAdd`)
Absolute, end-side (`left:16` under RTL = physical start? NOTE: source uses
`left:16px` = physical LEFT = **end** in RTL), bottom 88, z25. `primary` bg,
`onPrimary`, h48 r16, padding 0/18, gap8, shadow `0 8px 18px rgba(31,79,230,.4)`:
`add` 22 + "أضف إعلانك" 14/600. → publisher create flow.

### Bottom nav (`surface`, border-top `divider`, padding 8/4/16, space-around)
5 items. Selected: pill 62×32 r100 `sec` bg, filled icon 23 `onSec` + label 11/700 `on`.
Unselected: no pill, icon 23 `onVar` + label 11/500 `onVar`. Red badge on forum ("2").
Items: home/الرئيسية · search/البحث · bookmark/المحفوظة · forum/الرسائل(badge 2) · person/حسابي.

## LISTING CARD (shared by featured rail, home feed, search results)
Container: `surface` bg, 1px `divider` border, r12, clip. active: scale(.995).
- **Image** aspect 16/10, `surface2` bg (real photo fills it; placeholder = `image`/`apartment` icon 44/`outline`).
  - verified: green badge top-**right** (`greenC`/`onGreenC`, filled `verified` 14 + "موثّق", 11/700, r7, padding 3/8).
  - heart button top-**left**: 33px circle `scrim` bg; saved = filled `favorite` 19 `#FF5B6E`, else outline white.
  - photo count bottom-left: `scrim`/white, `photo_library` 14 + N, 11/600 Roboto, r7.
  - (featured variant adds gold "مميّز" badge left of the verified badge, top-right cluster; and has NO heart.)
- **Body** padding 10/12/12 (featured 9/11/11):
  - price row: price 18/700 Roboto `on` + syp 12 `onVar` (hidden if showSyp=false).
  - specs row (mt7, `onVar` 13, gap10, 3px dot separators): king_bed {beds} · bathtub {baths} · square_foot {area}. LAND variant: landscape "أرض" · square_foot {area} · {front}.
  - title mt8, 14 `on`, 1-line ellipsis (featured 13).
  - location row mt4: `location_on` 15 + loc (ellipsis flex) + "·" + ago. (featured: loc only, no ago/divider/publisher.)
  - divider 1px `divider` (my11/10).
  - publisher row: pub 12 `onVar` ellipsis + filled `verified` 15 `primary` (if pubVerified) + [flex] + "اتصال" tonal btn (h33 r100 `tonal`/`onTonal`, `call` 16, 13/600) + "واتساب" green btn (`greenC`/`onGreenC`, `chat` 16).

## SCREEN 2 — SEARCH (pushed; no bottom nav, back returns)
### Sticky crown header (`brandHeader`, sticky top0, padding 36/12/12)
Row gap6: back btn 40 (`arrow_forward` 24 white) + search field (`brandHeaderField`, h42 r11: `search` 20 `onVar` + "شقق للبيع في المزة" 14 `on` ellipsis + `close` 19 `onVar`) + `bookmark_border` btn 40 white.
**Chips row** (h-scroll, padding 12/2/2, gap8):
- action "الفلاتر": `tonal`/`onTonal`, `tune` 17 + "الفلاتر" + count badge "3" (`onTonal` bg pill, `tonal` text).
- removable ("شقق","المزة"): `surface`, 1px `outline`, r9, label 13/600 + `close` 16 btn.
- trailing ("السعر","الغرف"): `surface`/`outline`, label + `expand_more` 18.
- toggle ("الموثّقة فقط"): off = `surface`/`outline`; on = `sec` bg, `primary` border, `check` 17 + label `onSec`.
### Results sheet (`surface`, r 20/20/0/0, padding 14/16/8): "24 نتيجة" 14/700 + sort btn (`swap_vert` + sortLabel, cycles الأحدث/الأقل سعراً/الأعلى سعراً/الأقرب) + "الخريطة" btn (`map`). Both: h34 r100 `surface`/`outline`.
### Results list (`surface`, padding 6/16/40, gap12): listing cards.

## SCREEN 3 — DETAIL (pushed; sticky bottom CTA — this REVERSES the old no-sticky-CTA rule, design is authoritative)
- **Gallery** 300px `surface2` (real photos; placeholder `apartment` 60). Overlays (top 38, over status bar):
  back btn 38 `scrim` (`arrow_forward` 22 white) start; share + heart 38 `scrim` end.
  Bottom-left: `scrim`/white LTR "photo_library {i} / {n}" 12/600.
- **Thumb strip** (padding 10/16, LTR, gap8): thumbs 58×44 r8 `surface2`; selected = 2px `primary` border, else transparent.
- **Body** padding 6/16/22:
  - price 25/700 Roboto + syp 13 `onVar`.
  - badge chips (wrap, gap6, mt12): "موثّق ميدانياً" (`greenC`/`onGreenC`, filled `verified` 15) if verified + "للبيع" (`tonal`/`onTonal`) + "طابو أخضر" (`greenC`/`onGreenC`, `eco` 15). All 12/700 r8 padding 5/10.
  - title mt14 18/600 lh1.5.
  - location mt8: `location_on` 16 + loc + "·" + "نُشر {ago}".
  - **facts strip** mt16 `surface2` r14 padding 14/6: 4 cols, icon 23 `primary` + value 13/600. apt: king_bed "4 غرف", bathtub "3 حمامات", square_foot "220 م²", stairs "الطابق 7". land: square_foot/straighten "واجهة"/terrain "سكني"/description "طابو أخضر".
  - **verify card** (if verified) mt16: `greenC` bg, 1px `greenBorder`, r14, padding 13/14: filled `verified_user` 24 `onGreenC` + title "موثّق ميدانياً من فريق النجوم" 13/700 + body 12/.88 "زار فريق النجوم هذا العقار وتأكّد من توفّره ومطابقته للمواصفات قبل 3 أيام."
  - **"تفاصيل العقار"** 15/700 mt20. Table (1px `divider` r12): 6 rows, each padding 11/14, key 13 `onVar` + value 13/600 `on`, divider between. Rows: نوع العقار/شقة دوبلكس · نوع الطابو/أخضر سكني · الكسوة/سوبر ديلوكس · عمر البناء/5 سنوات · التدفئة/مركزية · سعر المتر/$955.
  - **"الوصف"** 15/700 mt20. Body 14 lh1.9, collapsed 3-line clamp, toggle "عرض المزيد"/"عرض أقل" (`primary`).
  - **agency card** mt20 (1px `divider` r14, padding 14): storefront avatar 48 `tonal`/`onTonal` + name 15/700 + filled `verified` 17 `primary` (if verified) + meta "وكيل معتمد · عضو منذ 2019 · 48 إعلاناً" 12 `onVar` + `chevron_left` 22.
- **Sticky CTA bar** (`surface`, border-top `divider`, padding 10/14/20, gap8): "اتصال" (`tonal`/`onTonal`, flex1, `call` 19) + "دردشة" (`surface`/`outline`, flex1, `forum` 19) + "واتساب" (`wa`/white, flex1.25, `chat` 20). All h46 r100 14/700.

## Props / config
- `accent`: [primary, header] pair. Default [#1F4FE6, #1A3FC4]. (Keep default; we're blue.)
- `showSyp` (default true): show "≈ … ل.س" secondary price line.

## Interactions
home/search/detail nav · theme toggle · segment select · heart toggle · chip
remove/toggle · sort cycle · thumb select · desc expand · category→search ·
card→detail.

## Screens NOT in this handoff (need a Claude Design follow-up — see prompt)
Saved · Messages+Chat · Account · Add-listing flow · Filters sheet · Auth
(login/register/OTP) · Notifications center · Map view · Search entry/recent.
