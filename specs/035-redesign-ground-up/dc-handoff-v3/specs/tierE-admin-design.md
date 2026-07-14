# AlNujom ADMIN Console — DC "Blue Crown" Tier-E Design Spec

> Build bible for the admin unit (وحدة الإدارة). Source of truth = `../alnujom-real-estate-marketplace/project/AlNujom - Admin.dc.html` (read it for exact px). 12 screens / 20 sub-views switched by `state.screen`. RTL, Noto Sans Arabic; **western digits (Roboto)** for all numerals. Material Symbols icons. Charts single-hue off `primary`.

## Token legend (light / dark)
bg #EAEDF2/#0C0C10 · surface(card) #FFFFFF/#131318 · surface2 #F2F4F9/#1C1D25 · tonal/onTonal #E2E9FF·#123287 / #26356E·#DCE4FF · sec/onSec #DAE1F6·#182C58 / #2A3352·#DEE4FA · on/onVar #1A1C22·#5B6070 / #E7E8ED·#A7ABB8 · outline #C6CAD6/#3B3D48 · divider #E7EAF1/#26272F · primary/onPrimary #1F4FE6·#FFF / #AEC2FF·#0A2063 · header(crown) #1A3FC4/#12235E · green/greenC/onGreenC #0E7A3C·#E4F3E9·#0A5A2C / #74D99A·#12331F·#A9E9C0 · gold/goldC #8A6912·#FBEDC7 / #E6C56A·#39300B · red/redC/onRedC #D93B3B·#FBE6E6·#B42318 / #FF6B6B·#3A1414·#FF9B9B.
Flutter tokens: bg=colors.surface, card=colors.card, surface2=colors.surfaceVariant, tonal=primaryContainer/onPrimaryContainer, sec=secondaryContainer/onSecondaryContainer, greenC=verifiedContainer/onSuccess, redC=errorContainer/onErrorContainer, gold=tertiary/goldContainer, header=brandHeader/onBrandHeader.

## Shell patterns (all → DcCrownScaffold)
- **A · Overlap** (console, analytics, settings): crown over white sheet (radius 20 top, mt -14). `sheet:true`.
- **B · Sticky queue** (accounts, listings, reports, agencies, ads, locations, currencies, roles, audit): crown = back + title + optional trailing (count pill / "جديد" text-btn / underline tabs). Body sheet. `sheet:true`, crownBottom = tabs where noted.
- **C · Detail/form + bottom bar** (listingPreview, listingDiff, reportDetail, agencyDetail, adEditor, locationForm, currencyForm, roleEditor): `sheet:false`, body on bg, sticky footer action bar as a **Stack overlay** (NOT bottomNavigationBar — collapses sliver body).
Crown back = DcCrownIconButton(arrow_forward). Trailing "جديد"/"دور" = DcCrownTextButton with add icon. Count pill = white-16% bg pill.

## Screens → shell + widgets
1. **console** (A): crown identity (shield_person 44 tile + "لوحة الإدارة" + super-admin badge, bell w/ red badge) → "نظرة عامة" → 2-col **DcStatCard** KPIs (7 حسابات/12 إعلانات/5 بلاغات/8 نشطة, no-trend) → grouped **DcQuickLinkTile** tiles w/ red count badges (الإشراف: accounts•7/listings•12/reports•5/agencies•3; المحتوى: ads/locations/currencies; النظام: analytics/audit/settings/+roles super-admin).
2. **accounts** (B + CrownUnderlineTabs معلّقة/مقبولة/مرفوضة): **DcAccountCard** (avatar + name/type/phone/ago + DcStatusChip + inline approve/reject/preview). 82px GREEN empty badge.
3. **listings** (B, pill "12 معلّق"): **DcReviewRow** (thumb 82×70 + price + status chip [revision=sec edit_note / fresh=neutral hourglass] + publisher + flag). tap→ diff | preview.
4. **listingPreview** (C, status pill): gallery strip + price + deed DcMetaChip + facts row **DcFactCell** + publisher card + desc + result banner. Bottom bar: موافقة(greenC)/رفض(outlined red→opens reason chips)/feature(goldC star). Reasons: صور غير واضحة/سعر غير واقعي/موقع خاطئ/وصف ناقص/إعلان مكرّر.
5. **listingDiff** (C): sec info banner + **DcDiffRow** (old strike onRedC / new greenC block onGreenC). Bottom: موافقة التعديل(greenC)/رفض التعديل(outlined red).
6. **reports** (B, pill "5 مفتوحة"): report row (redC icon box + subject/reason/reporter + DcStatusChip[open=neutral/resolved=green/dismissed=red] + chevron).
7. **reportDetail** (C): reason pill + entity card + reporter card + action chips (إزالة الإعلان/تحذير الناشر/إيقاف الحساب/لا إجراء). Bottom: حلّ البلاغ(primary gavel)/تجاهل(outlined).
8. **agencies** (B, pill "3 معلّقة"): row (logo tile + name/since/docs + DcStatusChip[verified/pending/rejected]).
9. **agencyDetail** (C, bespoke crown logo+name): tonal banner + **DcDocRow** (doc icon + label + status chip + view + accept/reject) × السجل التجاري/الهوية/إثبات العنوان/رخصة المهنة. Bottom: توثيق الوكالة(greenC verified)/رفض(outlined red).
10. **ads** (B, "جديد"): **DcAdCard** (thumb + caption + placement chip + priority chip[عالية green/متوسطة neutral/منخفضة outline] + window footer + تعديل + DcSwitch).
11. **adEditor** (C): **DcUploadZone**(dashed 130) + text + URL(LTR) + in-app dropdown + placement DcChoiceChips(sec) + start/end date fields + priority 3-seg + active toggle row. Bottom: إلغاء/حفظ الحملة.
12. **locations** (B, "جديد"): **DcLocationTree** (2-level gov→city accordion + area chips + dashed add-chip).
13. **locationForm** (C): name ar/en + parent dropdown + **DcMapPicker** (draggable pin on faux grid + coord chip, ~33.5138,36.2765). Bottom: إلغاء/حفظ الموقع.
14. **currencies** (B, "جديد"): **DcCurrencyRow** (symbol box + code/base badge/name + rate + DcSwitch). USD base/SYP 13000/TRY 32.40/EUR 0.92.
15. **currencyForm** (C): code/symbol/name fields + active toggle + set-rate card(input+تحديث) + **rate-history card w/ DcSparkline** (SVG area+line, RATE_SPARK) + history rows.
16. **analytics** (A, pill "آخر 30 يوماً") ⭐ CHARTS: 2-col **DcStatCard w/ trend** (12,480 users▲8/3,240 listings▲5/1,890 inquiries▲12/82% approval▼3) → **DcLineChart** "التطوّر عبر الزمن" (area+line+dots, series tabs الإعلانات/المستخدمون/الاستفسارات, month axis شباط..تموز) → **DcBarChart** "حسب المحافظة" (دمشق1240..اللاذقية260) → **DcDonutChart** "توزيع الفئات" (conic ring + legend, شقق46/فلل22/أراضٍ18/محلات9/مكاتب5, 5-stop single-hue ramp) → **DcHeatmap** "نشاط المستخدمين" (7×6 alpha grid + scale legend).
17. **audit** (B + scrollable crown filter chips الكل/موافقة/رفض/تعديل/بلاغات/نظام): date-range bar + **DcAuditRow** (expandable: tone icon box + action/target/time + expand → role chip + details). Kinds: approve→green check_circle/reject→red cancel/edit→blue edit/resolve→green gavel/system→neutral settings_suggest.
18. **settings** (A): grouped **DcSettingsTile** rows — عام(وضع الصيانة DcSwitch red-track / اللغة chevron / العملة chevron) · حدود الإشراف(2 switches + threshold **DcStepper** −/+ 1-9) · مفاتيح الميزات(360°/reels/ai/compare switches) · صيانة النظام(مسح الكاش/إعادة الفهرسة chevrons).
19. **roles** (B super-admin, "دور"): role card (badge tile + name + all-perms gold badge + members/perms meta + chevron). مشرف عام/مشرف محتوى/مراجع حسابات/محلّل.
20. **roleEditor** (C): read-only name field + **DcPermChecklist** (grouped checkbox rows, live count) الإشراف/المحتوى/النظام perms + assigned-members card + تعيين عضو. Bottom: إلغاء/حفظ الدور.

## Shared non-OK states (reuse empty/error widgets — 88px DC badges): loading skDash(console/analytics)/skList(rest); empty 88px tonal; error 88px redC + refresh.

## NEW widgets to build (20)
DcSwitch (46×28, red-track variant) · DcChoiceChip (on/off fills per context) · DcStepper (−/+ clamp 1-9) · DcSettingsTile · DcAccountCard · DcReviewRow · DcFactCell · DcDiffRow · DcDocRow · DcAdCard · DcLocationTree/DcGovAccordion · DcMapPicker (draggable pin + faux grid) · DcCurrencyRow · DcSparkline (SVG/CustomPaint) · DcLineChart (area+line+dots+axis) · DcDonutChart (conic/CustomPaint + legend) · DcHeatmap (alpha grid) · DcAuditRow (expandable) · DcPermChecklist/DcPermCheckRow · DcUploadZone (dashed).
**Reused:** DcCrownScaffold(+titleWidget), DcStatCard (console no-trend / analytics trend), DcBarChart (gov bars), DcQuickLinkTile (console + badge), DcStatusChip (accounts/reports/agencies/docs), DcMetaChip (deed/facts), CrownUnderlineTabs (accounts tabs; audit scrollable), AppButton, empty/error states. NOT used: DcModerationTimeline, RatingStars. No bottom nav in admin.

## Charts (⭐ founder wants native-vs-fl_chart comparison here)
All single-hue off primary. Line = area fill primary@.13 + stroke primary 2.5 + dots. Bars = surface2 track + primary fill. Donut = 5-stop primary ramp (light #1F4FE6/#4E74EC/#7E9CF2/#AEC2F8/#D8E1FB; dark #AEC2FF/#8AA3E4/#6E85C2/#54689C/#3D4C72). Heatmap = rgba(primary,α) α=0.1+0.85·v. Build native (CustomPaint) first; offer fl_chart adapter comparison for line/donut on the analytics screen.
