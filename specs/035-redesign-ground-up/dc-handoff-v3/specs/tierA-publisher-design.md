# AlNujom — Tier A (Publisher) — DC v3 Design Spec

Source: `AlNujom - Publisher.dc.html` (1058 lines). 9 primary screens + 3 shared data-states (loading / empty / error) + bottom nav. Single-file DC prototype; screens switched by `state.screen`. Screen enumeration (from `TITLES` map, line 722 + render `sc-if` flags):

| `screen` | Crown title (exact) | Tab? | Enters via |
|---|---|---|---|
| `dashboard` | لوحة التحكم | tab 0 | tab |
| `listings` | إعلاناتي | tab 1 | tab |
| `crm` | العملاء المحتملون | tab 2 (tab label العملاء) | tab |
| `inquiries` | الاستفسارات | tab 3 (badge 2) | tab |
| `viewings` | طلبات المعاينة | tab 4 (tab label المعاينات, badge 1) | tab |
| `analytics` | تحليلات العملاء | no | push (back) |
| `moderation` | سجل المراجعة | no | push (back) |
| `leadDetail` | تفاصيل العميل | no | push (back) |
| `inquiryDetail` | الاستفسار | no | push (back) |

`navParent` groups pushed screens under a tab for nav highlighting: dashboard/analytics→0, listings/moderation→1, crm/leadDetail→2, inquiries/inquiryDetail→3, viewings→4. **Bottom nav shows only on the 5 tab screens** (`TAB_SET`); pushed screens hide nav and show a back button (`arrow_forward` icon, RTL).

DC editor props (map to Flutter config/defaults): `accent` (crown/primary color set — default `#1F4FE6`/`#1A3FC4`), `showTrends` (bool, default true — toggles KPI delta arrows), `chartRange` (`آخر أسبوع` default | `آخر 6 أشهر` — swaps dashboard chart dataset + subtitle).

---

## Token legend (CSS var → project token)

| DC var | light / dark hex | Project token |
|---|---|---|
| `--bg` | #EAEDF2 / #0C0C10 | scaffold bg |
| `--surface` | #FFFFFF / #131318 | `colors.surface` (card) |
| `--surface2` | #F2F4F9 / #1C1D25 | `colors.surface2` |
| `--tonal` / `--onTonal` | #E2E9FF·#123287 / #26356E·#DCE4FF | tonal button bg/on |
| `--sec` / `--onSec` | #DAE1F6·#182C58 / #2A3352·#DEE4FA | selected/pill (nav indicator) |
| `--on` | #1A1C22 / #E7E8ED | `colors.text` |
| `--onVar` | #5B6070 / #A7ABB8 | `colors.textMuted` (secondary) |
| `--outline` | #C6CAD6 / #3B3D48 | `colors.outline` (border) |
| `--divider` | #E7EAF1 / #26272F | divider |
| `--primary` / `--onPrimary` | #1F4FE6·#FFFFFF / #AEC2FF·#0A2063 | `colors.primary` |
| `--header` | #1A3FC4 / #12235E | crown header |
| `--green`/`--greenC`/`--onGreenC`/`--greenBorder` | #0E7A3C·#E4F3E9·#0A5A2C·#C3E4CF / #74D99A·#12331F·#A9E9C0·#1E4A30 | verified/success |
| `--wa` | #1FA855 / #2AAE60 | WhatsApp |
| `--gold`/`--goldC` | #8A6912·#FBEDC7 / #E6C56A·#39300B | featured only |
| `--red`/`--redC`/`--onRedC` | #D93B3B·#FBE6E6·#B42318 / #FF6B6B·#3A1414·#FF9B9B | unread/destructive |

Fonts: Arabic text = **Noto Sans Arabic**; numerals/prices/deltas = **Roboto** (western digits). Crown text is always `#fff` (both themes). Icons = Material Symbols Outlined; `FILL 1` where noted.

---

## Screen: `dashboard` — «لوحة التحكم»

**Shell:** `DcCrownScaffold` (bespoke crown), `bottomNavigationBar` = publisher tab bar. Scroll body; crown does NOT collapse — it's a static header above a rounded sheet that overlaps by `-14px`.

### Crown header (bespoke — NOT a plain title)
`padding:36px 16px 22px`, bg `--header`. Row space-between:
- **Leading identity block** (gap 10): avatar chip `42×42`, radius `12`, bg `rgba(255,255,255,.16)`, icon `storefront` 24px `#fff`. Then two lines: name row = «مكتب الشام العقاري» 16px/700 `#fff` + `verified` icon 16px `#fff` FILL (gap 5); subtitle «لوحة التحكم · وكيل معتمد» 12px `rgba(255,255,255,.72)`, `margin-top:1px`.
- **Action:** notification bell button `40×40` circle (active bg `rgba(255,255,255,.14)`), icon `notifications` 23px `#fff`; red **unread dot** `8×8` at `top:5px, inset-inline-end:6px`, bg `--red`, `1.5px solid --header` border.

### Sheet (`--surface`, radius `20 20 0 0`, `margin-top:-14px`, `padding:16px 14px 24px`, min-height 520)

**1. KPI grid** — 2 cols, gap 10. Each card = **`DcKpiCard`** (NEW): bg `--surface`, `1px --divider`, radius 14, `padding:12px 12px 11px`.
- Top row space-between: icon chip `32×32` radius 9 bg `--tonal`, icon 19px `--onTonal`; delta pill (only if `showTrends`): up = `--green` `arrow_upward` 14px + delta; down = `--red` `arrow_downward` 14px + delta; text 11px/700 Roboto.
- Value: `margin-top:9px`, 22px/700 Roboto `--on`, line-height 1.1. Label: `margin-top:3px`, 12px/600 Noto `--on`. Sub: `margin-top:2px`, 11px Noto `--onVar`.
- Data: `campaign`·**6**·إعلانات نشطة·من 8 إجمالاً·+1▲ · `visibility`·**4,820**·مشاهدات الشهر·مقارنةً بـ 4,290·+12%▲ · `groups`·**128**·عملاء محتملون·هذا الشهر·+8%▲ · `bolt`·**92%**·معدّل الاستجابة·خلال ساعة·+3%▲.

**2. Chart card** «المشاهدات» — `margin-top:12`, card style as above, padding 14. Use **`DcBarChart`** (NEW).
- Header row: title «المشاهدات» 14px/700 + subtitle = `chartRangeLabel` 11px `--onVar`; right block (`text-align:left`): `viewsTotal` 19px/700 Roboto + «إجمالي» 11px `--onVar`.
- Bars: `margin-top:16`, flex align-flex-end, gap 8, **height 128px**. Each column: `flex:1`, bar `max-width:22px`, radius `6 6 0 0`, bg `--primary`, height = `round(v/max*100)%`; x-label 10px `--onVar` below (gap 7).
- Dataset (weekly default): vals `[420,510,380,640,590,720,680]`, labels `[س,ح,ن,ث,ر,خ,ج]`; total = 3940. (6-month variant: vals `[3200,3800,3500,4100,4290,4820]`, labels `[شبا,آذا,نيس,أيا,حزي,تمو]`.) **Single-hue `--primary` only.**

**3. Quick links** «إدارة النشاط» — title `margin-top:18` 14px/700. Grid 3 cols, gap 9, `margin-top:10`. Each = **`DcQuickLinkTile`** (NEW): button col, gap 8, bg `--surface`, `1px --divider`, radius 14, `padding:14px 6px`; icon chip `44×44` radius 12 bg `--tonal` icon 23px `--onTonal`; optional red badge at `top:-5, inset-inline-end:-5`, min-width 18 h18, 10px/700 white, `2px solid --surface`; label 11px/600 `--on` centered line-height 1.3.
- 6 tiles: `apartment` إعلاناتي→listings · `bar_chart` تحليلات العملاء→push analytics · `groups` العملاء→crm · `forum` الاستفسارات **badge 2**→inquiries · `event` طلبات المعاينة **badge 1**→viewings · `fact_check` سجل المراجعة→push moderation.

**4. Recent activity** «آخر النشاط» — header row `margin-top:18` space-between: label 14px/700 + «عرض الكل» text button `--primary` 13px/600 (→inquiries). List card = **`DcActivityList`** (NEW): bg `--surface`, `1px --divider`, radius 14, overflow hidden; rows separated by `1px --divider` (not on first).
- Row `padding:12px 13px`, gap 11: leading icon chip `36×36` radius 10 — tone `green`→bg `--greenC` icon `--onGreenC` FILL; tone `blue`→bg `--tonal` icon `--onTonal`; icon 19px. Middle: title 13px/600 `--on` (ellipsis) + body 12px `--onVar` (ellipsis). Trailing time 11px `--onVar`.
- Data: `event`/blue «طلب معاينة جديد» · محمود الأحمد · شقة أبو رمانة · منذ ساعة · `mail`/blue «استفسار جديد» · رنا العلي · فيلا الحمدانية · منذ 3 ساعات · `verified`/green «تم توثيق إعلانك ميدانياً» · شقة دوبلكس في أبو رمانة · أمس.

---

## Screen: `listings` — «إعلاناتي»

**Shell:** `DcCrownScaffold` + tab bar. Crown is **sticky** (`position:sticky;top:0`), sheet radius `20 20 0 0` scrolls under it. Contains a FAB.

### Crown (`padding:36px 16px 0`, sticky)
- Title row (pb 12): «إعلاناتي» 20px/700 `#fff`; action = search `DcCrownIconButton` (`search` 23px, `40×40`).
- **`CrownUnderlineTabs`** (`listFilters`): `gap:20`, overflow-x. Selected 14px/700 `#fff` + `border-bottom:3px #fff` (pb 10); unselected 14px/600 `rgba(255,255,255,.6)`. Tabs: **الكل · منشور · قيد المراجعة · مرفوض · منتهٍ · مسودّة**.

### Sheet (`--surface`, `padding:14px 14px 90px`, flex col gap 11)

**`DcListingManageCard`** (NEW) — outer bg `--surface`, `1px --divider`, radius 14, overflow hidden. Three regions:
1. **Tap region** (→push moderation) — flex gap 11, padding 11, active bg `--surface2`:
   - Thumbnail `88×66` radius 10 bg `--surface2`, placeholder icon 28px `--outline` (`apartment`/`landscape`/`villa`/`home_work`). **Featured chip** (if featured) top-left: bg `--goldC` text `--gold`, `padding:2px 6px` radius 6, `star` 12px FILL + «مميّز» 10px/700.
   - Body: row (price 16px/700 Roboto `--on` | **status pill**). Title 13px `--on` ellipsis (mt 5). Location row (mt 3): `location_on` 13px + loc 11px `--onVar`. Stats row (mt 7, gap 12, 12px `--onVar` Roboto): `visibility` 15px + views · `groups` 15px + leads.
2. **Rejection reason banner** (status=rejected only): `margin:0 11px 11px`, bg `--redC` radius 9 `padding:8px 10px`, `error` 16px `--onRedC` + «سبب الرفض: …» 11px `--onRedC` line-height 1.55.
3. **Action row** — `border-top:1px --divider`, 3 cells split by `1px --divider`, each height 42:
   - تعديل: `edit` 17px `--onVar` + label 12px/600 `--on`.
   - **تمييز** cell — `canFeature`(live & not featured): `star` 17px `--gold` + «تمييز» 12px/700 `--gold`; `featured`: `star` FILL 17px `--gold` + «مميّز» 12px/700 (static); `featureOff`(non-live & not featured): `star` 17px `--outline` + 12px/600 `--outline` (disabled).
   - أرشفة: `inventory_2` 17px `--onVar` + 12px/600 `--on`.

**Status pill** = **`DcStatusPill`** (NEW, shared), `padding:3px 8px` (outline: `2px 8px`), radius 7, 10px/700, icon 13px:
- live→green: bg `--greenC` on `--onGreenC`, `check_circle` FILL, «منشور»
- review→neutral: bg `--surface2` on `--onVar`, `hourglass_top`, «قيد المراجعة»
- rejected→red: bg `--redC` on `--onRedC`, `cancel` FILL, «مرفوض»
- expired→neutral: bg `--surface2` on `--onVar`, `schedule`, «منتهٍ»
- draft→outline: transparent + `1px --outline` on `--onVar`, `edit_note`, «مسودّة»

**FAB** «أضف إعلان»: absolute `left:16, bottom:16`, height 48, `padding:0 18`, bg `--primary` on `--onPrimary`, radius 16, shadow `0 8px 18px rgba(31,79,230,.4)`, `add` 22px + label 14px/600. (Note: extended FAB, radius 16 = token max.)

Seed listings: p1 apartment/featured/live/1,240/18 · p2 review/0/0 · p3 landscape/rejected(+reason)/210/2 · p4 villa/live/980/12 · p5 expired/1,520/9 · p6 home_work/draft/0/0.

---

## Screen: `analytics` — «تحليلات العملاء» (pushed)

**Shell:** `DcCrownScaffold`, leading = back `DcCrownIconButton` (`arrow_forward` 24px), NO tab bar. Crown sticky, sheet radius `20 20 0 0`.

### Crown (`padding:34px 8px 0`)
Row (pb 10, gap 6): back + «تحليلات العملاء» 18px/700. `CrownUnderlineTabs` (`periods`, `padding:0 10`, gap 20): **7 أيام · 30 يوم · 3 أشهر** (default `30 يوم`; selected 13px/700, unselected 13px/600). *(Period tabs are presentational — no dataset swap in prototype.)*

### Sheet (`padding:16px 14px 24px`)
**1. Two stat cards** (grid 2, gap 10) — variant of `DcKpiCard` (no icon chip): card `padding:12px 13px`; value 22px/700 Roboto; label 12px/600 (mt 3); delta inline `--green` `arrow_upward` 14px + text 11px/700 (mt 4). Data: **143** إجمالي التفاعلات +11%▲ · **14%** معدّل التحويل +2%▲.

**2. Stacked chart card** «التفاعلات حسب الأسبوع» (14px/700) — **`DcStackedBarChart`** (NEW). Bars `margin-top:16`, flex align-flex-end, gap 10, **height 172px**. Each column `flex:1`, `max-width:26px`, radius `6 6 0 0`, overflow hidden, segments stacked bottom→top, all `--primary` at graded opacity:
- `viewH` opacity **.26** (معاينات) · `inqH` opacity **.46** (استفسارات) · `waH` opacity **.72** (واتساب) · `callsH` opacity **1** (مكالمات). Height each = `round(val/emax*150)px` where emax = max weekly total. Label 10px `--onVar` Roboto (1–6).
- EV data (6 wks, {calls,wa,inq,view}): [14,20,6,3][18,16,8,4][12,22,5,2][20,24,9,5][16,19,7,4][22,26,8,6].
- Legend: `margin-top:14`, `border-top:1px --divider`, pt 12, flex-wrap gap `12 16`: swatch `11×11` radius 3 `--primary` at opacity 1/.72/.46/.26 + label 11px `--onVar` = مكالمات · واتساب · استفسارات · معاينات. **Single-hue opacity ramp — no rainbow.**

**3. Source table** «حسب المصدر» (14px/700, mt 18) — **`DcMiniTable`** (NEW): card `1px --divider` radius 14 overflow hidden.
- Header row bg `--surface2` `padding:9px 13px`: المصدر (flex1) 11px/700 `--onVar` · العدد (w64 center) · التغيّر (w64 left).
- Rows `padding:11px 13px`, `border-top:1px --divider`: src cell (flex1) icon 18px `--onVar` + label 13px/600; val (w64 center) 14px/700 Roboto; delta (w64 left) 12px/700 `--green`(up)/`--red`(down). Data: `call` مكالمات 62 +9%▲ · `chat` واتساب 48 +14%▲ · `mail` استفسارات 22 −3%▼ · `event` معاينات 11 +5%▲.
- Total row bg `--surface2`: «الإجمالي» 13px/700 · 143 · (empty).

---

## Screen: `moderation` — «سجل المراجعة» (pushed)

**Shell:** `DcCrownScaffold`, leading = back, NO tab bar. **No rounded overlapping sheet** — body is flat `--surface`. Crown is a simple non-sticky bar.

### Crown (`padding:34px 8px 14px`, flex gap 6): back + «سجل المراجعة» 18px/700.

### Body (`--surface`, `padding:14px 16px 24px`)
**1. Listing summary card** — bg `--surface2` radius 14 padding 11, flex gap 11 align-center: thumb `56×48` radius 9 bg `--surface` icon `apartment` 24px `--outline`; title (`modTitle`) 13px/700 ellipsis + price (`modPrice`) 12px `--onVar` Roboto; trailing `DcStatusPill` green «منشور» `check_circle` FILL (`padding:4px 9px`).

**2. Review timeline** — **`DcModerationTimeline`** (NEW): `margin-top:20`, `padding-inline-start:8`. Each event: flex gap 14, `padding-bottom:20`:
- Node col: circle `32×32` radius 50% — green: bg `--greenC` icon `--onGreenC` FILL 18px; red: bg `--redC` icon `--onRedC` 18px; neutral: bg `--surface2` `1px --divider` icon `--onVar` 17px. **Connector**: absolute `top:32, bottom:-20, width:2`, bg `--divider` (all but last).
- Content (pt 3): title 14px/700 `--on`; time 11px `--onVar` Roboto (mt 2); optional body box (mt 8) bg `--surface2` radius 10 `padding:9px 11px` 12px `--on` line-height 1.65.
- MOD data (5): `upload_file`/neutral «أُرسل الإعلان للمراجعة» 2 تموز·09:12 · `edit_note`/neutral «طُلب تعديل» +body · `upload_file`/neutral «أُعيد الإرسال بعد التعديل» · `check_circle`/green «تمت الموافقة والنشر» · `verified`/green «توثيق ميداني» +body.

---

## Screen: `crm` — «العملاء المحتملون» (tab; tab label العملاء)

**Shell:** `DcCrownScaffold` + tab bar. Crown sticky.

### Crown (`padding:36px 16px 0`): title «العملاء المحتملون» 20px/700 (pb 12); `CrownUnderlineTabs` (`crmFilters`, gap 18): **الكل · جديد · تواصل · معاينة · تفاوض · مغلق**.

### Sheet (`padding:14px 14px 24px`, flex col gap 10)
**`DcLeadRow`** (NEW, →push leadDetail): bg `--surface` `1px --divider` radius 14 padding 12, flex align-center gap 11, active bg `--surface2`.
- Avatar circle `44×44` bg `--tonal`, initial (first char) 16px/700 `--onTonal`.
- Middle: name 14px/700 `--on` ellipsis; sub row (mt 4, gap 7): **`DcSourceChip`** (bg `--surface2` on `--onVar`, `padding:2px 7px` radius 6, 10px/600, icon 12px + label) + listing 11px `--onVar` ellipsis. Sources: `forum` محادثة · `mail` استفسار · `event` معاينة.
- Right col (align flex-end, gap 6): **`DcStagePill`** (NEW) — `padding:3px 9px` radius 100, 10px/700, leading `6×6` dot: green (bg `--greenC` on `--onGreenC` dot `--green`) · red (bg `--redC` on `--onRedC` dot `--red`) · neutral (bg `--surface2` on `--onVar` dot `--onVar`). Then last-contact 10px `--onVar`.
- stageTone: `مغلق-ناجح`→green, `مغلق-خسارة`→red, else neutral. Filter «مغلق» matches any stage starting «مغلق».
- LEADS (6): محمود الأحمد/viewing/معاينة/منذ ساعتين · رنا العلي/conversation/تفاوض/أمس · سامر خوري/inquiry/جديد · ليلى حداد/conversation/تواصل · وسيم درويش/inquiry/مغلق-ناجح(green) · هبة نجّار/viewing/مغلق-خسارة(red).

---

## Screen: `leadDetail` — «تفاصيل العميل» (pushed)

**Shell:** `DcCrownScaffold`, leading = back, custom title, NO tab bar, **sticky bottom composer** (maps to `sheet`/bottom bar slot). Body bg `--bg`.

### Crown (`padding:34px 8px 16px`, flex gap 6): back + avatar `40×40` bg `rgba(255,255,255,.16)` initial 15px/700 `#fff` + two-line title (name 16px/700 ellipsis + `leadSrcLabel` 12px `rgba(255,255,255,.72)`).

### Body (`padding:14px 14px 20px`, scroll)
**1. Contact card** — bg `--surface` `1px --divider` radius 14 padding 13. **`DcLabelValueRow`** (NEW) ×3 with `1px --divider` (margin 11 0) between:
- الهاتف (13px `--onVar`) → value 14px/700 Roboto `direction:ltr` · العقار المهتم به → listing 13px/600 · الميزانية → budget 13px/600 Roboto.
- Buttons (mt 13, gap 8, height 42, radius 100, 13px/700): **اتصال** bg `--tonal` on `--onTonal` `call` 18px · **واتساب** bg `--greenC` on `--onGreenC` `chat` 18px.

**2. Stage changer** «المرحلة» (13px/700, mt 14) — **`DcStageChips`** (NEW): row (mt 9, gap 6, overflow-x). On: bg `--primary` on `--onPrimary` 12px/700; Off: bg `--surface` `1px --outline` on `--on` 12px/600. Height 36, `padding:0 15`, radius 100. STAGES: **جديد · تواصل · معاينة · تفاوض · مغلق** (closed-stages default-select «مغلق»).

**3. Reminder card** — **`DcReminderCard`** (NEW): mt 14, bg `--tonal` radius 12 `padding:11px 13px`, flex gap 11: `notifications_active` 22px `--onTonal`; title «تذكير: اتصال للمتابعة» 13px/700 `--onTonal` + sub «الخميس 10 تموز · 10:00 ص» 11px `--onTonal` opacity .85; «تعديل» text button 12px/700 `--onTonal`.

**4. Notes** «الملاحظات» (13px/700, mt 16) — list (mt 9, gap 9) of **`DcNoteCard`** (NEW): bg `--surface` `1px --divider` radius 12 `padding:11px 12px`; text 13px `--on` line-height 1.7; time 11px `--onVar` (mt 6). BASE_NOTES ×3 (newest added prepended).

### Composer bar (flex-shrink 0) — **`DcComposerBar`** (NEW, shared w/ inquiryDetail): bg `--surface` `border-top:1px --divider` `padding:10px 12px 18px`, flex gap 8: input `flex`, height 44, `1px --outline` radius 100, bg `--surface2`, `padding:0 16`, 14px `--on`, placeholder «أضف ملاحظة…»; send button `44×44` circle bg `--primary`, `add` 21px `--onPrimary`.

---

## Screen: `inquiries` — «الاستفسارات» (tab, badge 2)

**Shell:** `DcCrownScaffold` + tab bar. Crown sticky.

### Crown (`padding:36px 16px 16px`, space-between): «الاستفسارات» 20px/700; **unread pill** (custom action): bg `rgba(255,255,255,.16)` `#fff`, `padding:5px 11px` radius 100, 12px/700, `7×7` red dot + «2 غير مقروء».

### Sheet (`padding:6px 0 24px`)
**`DcInquiryRow`** (NEW, →push inquiryDetail): flex gap 11 `padding:13px 16px`, `border-bottom:1px --divider`, active bg `--surface2`.
- Avatar `44×44` circle bg `--tonal` initial 16px/700 `--onTonal`; unread red dot `11×11` top-right, `2px solid --surface`.
- Middle: row (name 14px/700 ellipsis | time 11px `--onVar`); listing chip (mt 4) bg `--surface2` radius 8 `padding:5px 8px` icon 15px `--onVar` + listing 11px `--onVar` ellipsis; message (mt 5) 13px `--onVar` line-height 1.5 **2-line clamp**.
- Trailing unread count badge (if unread): red pill min-width 20 h20 white 11px/700 `padding:0 5`, align-self center.
- INQUIRIES ×4 (iq1 unread=2, rest 0).

---

## Screen: `inquiryDetail` — «الاستفسار» (pushed)

**Shell:** `DcCrownScaffold`, leading = back, custom title, `call` action, NO tab bar, sticky bottom composer. Body bg `--bg`.

### Crown (`padding:34px 8px 12px`, flex gap 6): back + avatar `38×38` bg `rgba(.16)` initial 14px/700 + name 15px/700 `#fff` ellipsis (flex1) + `call` `DcCrownIconButton` (22px).

### Listing-context bar (below crown, flex-shrink 0) — **`DcListingContextBar`** (NEW): `padding:10px 14px`, bg `--surface`, `border-bottom:1px --divider`, flex gap 11, tappable: thumb `48×40` radius 8 bg `--surface2` icon 22px `--outline`; listing 13px/700 ellipsis + price 13px/700 Roboto (mt 2); trailing `chevron_left` 20px `--onVar`.

### Thread (flex1 scroll, bg `--bg`, `padding:16px 14px`, flex col gap 10)
- Day divider: align-self center bg `--surface2` on `--onVar` 11px/600 `padding:4px 12px` radius 100 «اليوم».
- **`DcChatBubble`** (reuse existing Chat bubble if present): theirs → align-start, max-width 80%, bg `--surface` `1px --divider`, radius `4 16 16 16`, `padding:9px 13px`, text 14px `--on` line-height 1.6 + time 10px `--onVar` left. mine → align-end, bg `--primary`, radius `16 4 16 16`, text 14px `--onPrimary` + time 10px `--onPrimary` opacity .75 left.

### Composer (flex-shrink 0): bg `--surface` `border-top:1px --divider` `padding:9px 12px 4px`:
- **`DcQuickReplyChips`** (NEW): row gap 7 overflow-x, pb 9. Chip height 32 `1px --outline` radius 100 bg `--surface` on `--on` 12px/600 `padding:0 13`. QUICK: «نعم، ما زال متاحاً» · «السعر قابل للتفاوض» · «متى تناسبك المعاينة؟» · «سأرسل لك الصور».
- Input row (pb 14, gap 8): attach button `40×40` (`add` 23px `--onVar`) + input (as `DcComposerBar`, placeholder «اكتب رداً…») + send button `44×44` circle `--primary` `send` 21px `--onPrimary`. **Note:** this composer has a leading attach button vs leadDetail's — treat as `DcComposerBar({leading, placeholder, sendIcon})`.

---

## Screen: `viewings` — «طلبات المعاينة» (tab; tab label المعاينات, badge 1)

**Shell:** `DcCrownScaffold` + tab bar. Crown sticky.

### Crown (`padding:36px 16px 0`): «طلبات المعاينة» 20px/700 (pb 12); `CrownUnderlineTabs` (`viewFilters`, gap 18): **الكل · معلّق · مؤكّد · منتهٍ** (filter منتهٍ matches past + declined).

### Sheet (`padding:14px 14px 24px`, flex col gap 11)
**`DcViewingCard`** (NEW): bg `--surface` `1px --divider` radius 14 padding 13.
- Top row space-between: left = avatar `40×40` circle bg `--tonal` initial 15px/700 + name 14px/700 ellipsis (gap 9); right = `DcStatusPill` `padding:3px 9px` radius 7 10px/700 icon 13 — confirmed→green `event_available` FILL «مؤكّد» · declined→red `event_busy` «مرفوض» · pending/past→neutral (`hourglass_top` «معلّق» / `history` «منتهٍ»).
- Listing row (mt 11): bg `--surface2` radius 10 `padding:9px 11px`, `apartment` 19px `--outline` + listing 12px/600 `--on` ellipsis.
- Datetime row (mt 10, gap 16, 12px `--onVar`): `event` 17px `--primary` + date · `schedule` 17px `--primary` + time.
- **Pending actions** (mt 12, gap 8, height 42, radius 100, 13px/700): تأكيد bg `--primary` on `--onPrimary` `check` 18px · رفض bg `--surface` `1px --outline` on `--on` `close` 18px.
- **Confirmed actions**: تواصل (`forum`) + إعادة جدولة (`edit_calendar`) — both outlined (bg `--surface` `1px --outline`), 18px icons, height 42.
- VIEWINGS ×4: v1 pending · v2 confirmed · v3 declined · v4 past.

---

## Bottom nav (publisher tab bar) — shown on 5 tab screens only

`flex-shrink:0`, bg `--surface`, `border-top:1px --divider`, `padding:7px 4px 11px`. 5 equal buttons (col, gap 4, `padding:3px 0`):
- Selected: indicator pill `60×30` radius 100 bg `--sec`, icon 22px `--onSec` FILL; label 11px/700 `--on`.
- Unselected: `60×30` no bg, icon 22px `--onVar`; label 11px/500 `--onVar`.
- Badge (on indicator): red min-width 16 h16, 9px/700 white, `top:-2, inset-inline-end:8`, `1.5px solid --surface`.
- Tabs: `space_dashboard` التحكم · `apartment` إعلاناتي · `groups` العملاء · `forum` الاستفسارات **badge 2** · `event` المعاينات **badge 1**. Highlight follows `navParent` (pushed screens keep parent tab semantics but nav is hidden).

---

## Shared data-states (loading / empty / error) — apply to ANY screen

Common header for non-ok: bg `--header` `padding:36px 12px 16px` flex gap 6: back button only if `currentHasBack` (= not a tab screen) + `currentTitle` 19px/700 `#fff` (padding-inline-start 4). Rounded sheet `--surface` radius `20 20 0 0` `margin-top:-14px`.

**Loading** — **`DcSkeleton`** (NEW; shimmer = `linear-gradient(90deg, --surface2 25%, --divider 37%, --surface2 63%)`, `background-size:400% 100%`, `animation:shim 1.4s ease infinite`). 3 variants by screen:
- `skDash` (dashboard/analytics): 4× KPI blocks (2-col grid gap 10, each h96 radius 14) + h200 chart + h120 block (mt 12 each).
- `skList` (listings/crm/inquiries/viewings): 5 rows (padding 14, gap 11), each = `88×66` thumb + 3 text bars (w 45%/80%/60%, h 15/12/12, radius 6).
- `skDetail` (leadDetail/inquiryDetail/moderation): h120 block + w40% h15 bar + two h70 blocks (gap 12).

**Empty** — **`DcEmptyState`** (NEW/shared w/ Tier D): `padding:60px 32px` col center: circle `88×88` bg `--tonal` icon 44px `--onTonal`; title 18px/700 `--on`; body 14px `--onVar` line-height 1.7 (mt 8); optional CTA button (mt 22, height 46, `padding:0 24`, radius 100, bg `--primary` on `--onPrimary` 14px/700). Per-screen `emptyMap`: dashboard `insights` «لا بيانات بعد» + CTA «أضف إعلانك» · listings `apartment` «لا إعلانات بعد» + CTA «أضف إعلانك» · analytics `bar_chart` «لا تحليلات بعد» · moderation `fact_check` «لا سجل مراجعة» · crm `groups` «لا عملاء محتملون بعد» · leadDetail `person` «لا تفاصيل» · inquiries `mail` «لا استفسارات» · inquiryDetail `forum` «لا رسائل» · viewings `event` «لا طلبات معاينة». (Only dashboard/listings carry a CTA.)

**Error** — **`DcErrorState`** (NEW/shared w/ Tier D): same layout, circle `88×88` bg `--redC` icon `cloud_off` 44px `--onRedC`; title «تعذّر تحميل البيانات» 18px/700; body «حدث خطأ في الاتصال بالخادم. تحقّق من الإنترنت وحاول مرة أخرى.» 14px `--onVar`; retry button `--primary` `refresh` 20px + «إعادة المحاولة» (height 46, radius 100, 14px/700).

---

## Shared-shell mapping summary

| Screen | Shell | leading | title | actions | crownBottom | bottomNav |
|---|---|---|---|---|---|---|
| dashboard | DcCrownScaffold | storefront chip | agency name+verified+subtitle (custom) | bell w/ dot | — | yes |
| listings | DcCrownScaffold (sticky) | — | «إعلاناتي» | search icon | CrownUnderlineTabs | yes (+FAB) |
| crm | DcCrownScaffold (sticky) | — | «العملاء المحتملون» | — | CrownUnderlineTabs | yes |
| inquiries | DcCrownScaffold (sticky) | — | «الاستفسارات» | unread pill (custom) | — | yes |
| viewings | DcCrownScaffold (sticky) | — | «طلبات المعاينة» | — | CrownUnderlineTabs | yes |
| analytics | DcCrownScaffold (sticky) | back | «تحليلات العملاء» | — | CrownUnderlineTabs | no |
| moderation | DcCrownScaffold (flat body) | back | «سجل المراجعة» | — | — | no |
| leadDetail | DcCrownScaffold (+bottom composer) | back | custom (avatar+name+src) | — | — | no |
| inquiryDetail | DcCrownScaffold (+context bar +composer) | back | custom (avatar+name) | call icon | — | no |

---

## NEW reusable components to build once (Task #23)

1. **DcKpiCard** — icon-chip stat card + optional delta (dashboard); no-icon value/label/delta variant (analytics).
2. **DcBarChart** — single-hue vertical bars, x-labels, optional header total. `--primary` only.
3. **DcStackedBarChart** — single-hue **opacity-ramp** stacked bars (1/.72/.46/.26) + legend.
4. **DcMiniTable** — 3-col (label/value/delta) with header + total rows, green/red delta.
5. **DcStatusPill** — tones green/red/neutral/outline + icon + label (listings, viewings, moderation header).
6. **DcQuickLinkTile** (+ grid) — icon-chip tile with badge.
7. **DcActivityList** — icon-chip rows with dividers (green/blue tones).
8. **DcModerationTimeline** — node circle (green/red/neutral) + connector + content + optional body box.
9. **DcListingManageCard** — thumb + featured chip + price/status + stats + reason banner + 3-cell action row.
10. **DcLeadRow** + **DcStagePill** + **DcSourceChip** — CRM list primitives.
11. **DcStageChips** — selectable pill chips (on/off).
12. **DcReminderCard** — tonal banner (icon + title/sub + action).
13. **DcNoteCard** + **DcLabelValueRow** — lead-detail primitives.
14. **DcComposerBar** — bottom input + circular send (params: optional leading attach, placeholder, send icon); shared by leadDetail & inquiryDetail.
15. **DcInquiryRow** — inbox row (avatar+unread dot / name+time / listing chip / clamped message / count badge).
16. **DcListingContextBar** — sticky listing header (inquiryDetail).
17. **DcQuickReplyChips** — horizontal outlined chip row.
18. **DcViewingCard** — viewing request (avatar+name+status / listing / datetime / action pair).
19. **DcSkeleton** (Dash/List/Detail variants) — shimmer loaders.
20. **DcEmptyState** / **DcErrorState** — likely shared with Tier D chrome; per-screen icon/title/body/CTA config.
21. **DcChatBubble** — reuse existing Chat-tab bubble if already built; else new theirs/mine variant.

**Design-discipline checks passed by the DC file:** green used only for verified/WhatsApp/success/confirmed; gold only for featured; red only for unread/rejected/destructive; blue only for primary actions/selection/nav indicator; charts strictly single-hue `--primary` (opacity ramp, no rainbow); max radius 16 (FAB); western digits throughout; no glass/gradient/blur. The bottom light/dark gallery (lines 611–690) is a DC preview harness only — **not** an app surface.
