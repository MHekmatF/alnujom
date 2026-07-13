# AlNujom "Blue Crown" — Chrome & States Tier — DESIGN SPEC

> Digest of `AlNujom - Chrome.dc.html`. The HTML file is ground truth for exact values.

Source: `AlNujom - Chrome.dc.html`. Single-file Claude-Design prototype; four screens switched by demo nav (`state.screen` ∈ `splash | onboarding | settings | states`). Token map matches the project DC contract (light / dark).

Phone frame: `400×842`, outer radius 46, inner screen inset 11 radius 35, `direction:rtl`.

## Token map
bg `#EAEDF2`/`#0C0C10` · surface `#FFFFFF`/`#131318` · surface2 `#F2F4F9`/`#1C1D25` · tonal `#E2E9FF`/`#26356E` · onTonal `#123287`/`#DCE4FF` · sec `#DAE1F6`/`#2A3352` · onSec `#182C58`/`#DEE4FA` · on(text) `#1A1C22`/`#E7E8ED` · onVar(secondary) `#5B6070`/`#A7ABB8` · outline `#C6CAD6`/`#3B3D48` · divider `#E7EAF1`/`#26272F` · primary `#1F4FE6`/`#AEC2FF` · onPrimary `#FFFFFF`/`#0A2063` · header `#1A3FC4`/`#12235E` · headerField `#FFFFFF`/`#20232C` · green/greenC `#0E7A3C`/`#E4F3E9` (dk `#74D99A`/`#12331F`) · wa `#1FA855`/`#2AAE60` · gold/goldC `#8A6912`/`#FBEDC7` (dk `#E6C56A`/`#39300B`) · red/redC/onRedC `#D93B3B`/`#FBE6E6`/`#B42318` (dk `#FF6B6B`/`#3A1414`/`#FF9B9B`) · scrim `rgba(15,18,30,.42)`/`rgba(0,0,0,.5)`.
Fonts: Arabic=Noto Sans Arabic; numerals/latin=Roboto, WESTERN digits. Icons=Material Symbols Outlined (splash+onboarding hero use FILL 1).

---

## SCREEN 1 — Splash · `شاشة البداية` (lines 64–75)
Full-bleed brand. Tap anywhere → onboarding.
**Shell:** `DcAuthScaffold({child})`. **Background:** `--header` `#1A3FC4`/`#12235E`, fills inset:0, entry `fade .3s`.
1. **Centered brand lockup** (column gap 18, `pulse 2.6s` scale 1→1.06 opacity 1→.92):
   - Logo tile **96×96**, radius **26**, bg `#FFFFFF` (literal white both themes), `box-shadow:0 12px 30px rgba(0,0,0,.25)`, icon `star` FILL 1 **58px** color `--header`.
   - Title `النجوم` **34px/700** `#fff` lh 1; tagline `سوق العقارات الأول في سوريا` mt 8, **14px** `rgba(255,255,255,.8)`.
2. **Bottom loading block** (abs bottom:56, centered column gap 16): progress track **150×4** radius 3 bg `rgba(255,255,255,.22)`, inner fill white `prog 1.8s` (8%→92%); label `جارٍ التحميل…` **12px** `rgba(255,255,255,.7)`.
**NEW:** `DcSplashScreen`.

---

## SCREEN 2 — Onboarding · `المقدمة` (lines 78–95)
3 slides. Background `--surface`. Entry `fade .25s`.
| # | icon | title | body |
|---|---|---|---|
| 0 | `verified` | ابحث بثقة | تصفّح آلاف العقارات الموثّقة ميدانياً في دمشق وحلب وكل المحافظات السورية. |
| 1 | `forum` | تواصل مباشرة | راسل الناشرين وتواصل معهم عبر واتساب أو الاتصال بضغطة واحدة. |
| 2 | `notifications_active` | لا تفوّت فرصة | احفظ بحثك واحصل على تنبيه فور نزول عقار جديد مطابق لمعاييرك. |

**Shell:** `DcAuthScaffold`. Vertical flex, inset:0.
1. **Skip row** (pad `40px 20px 0`, start): `تخطّي` transparent, `--onVar`, **13px/700**, pad 6.
2. **Hero** (flex:1 centered, pad `0 34px`): icon medallion **150×150** radius **44** bg `--tonal`, glyph FILL 1 **76px** `--onTonal`, mb 34; title **24px/700** `--on`; body mt 12 **15px** `--onVar` lh 1.85.
3. **Footer** (pad `0 24px 34px`): dots row (center, gap 7, mb 24) 3× h7 radius 4 bg `--primary`, active **w24 opacity 1**, inactive **w7 opacity .28**; CTA full-width **h52** radius 100 bg `--primary` `--onPrimary` **15px/700** press scale .98, label `التالي` (slides 0–1) / `ابدأ الآن` (last).
**NEW:** `DcOnboardingScreen` (PageView+dots+skip/next), `DcOnboardingSlide({icon,title,body})`, `DcPageDots({count,index})`. CTA = `AppButton(filled, expanded, h52)`.

---

## SCREEN 3 — Settings + About/Support · `الإعدادات` (lines 98–162)
**Shell:** `DcCrownScaffold`. Crown sticky (bg `--header`, pad `34px 8px 16px`, back `arrow_forward` 40×40 white active `rgba(255,255,255,.14)`, title `الإعدادات` **18px/700** white). Content sheet: bg `--surface`, radius `20 20 0 0`, mt -14, pad `16px 14px 26px`, gap 18 between 4 groups; scroll bg `--bg`.
Section label: **12px/700** `--onVar` ls .3 mb 9 pad `0 2px`. Grouped card: `--surface`, 1px `--divider`, radius **14**, overflow hidden, rows split by 1px `--divider`.

- **Group 1 Appearance (المظهر)** — segmented theme (surface2 pill track radius 100 pad 4 gap 3; 3 segments `فاتح`/`داكن`/`تلقائي`; selected flex:1 h38 radius 100 bg `--surface` `--on` **13/700** shadow `0 1px 3px rgba(0,0,0,.12)`; unselected transparent `--onVar` 13/600).
- **Group 2 General (عام)** — nav rows (pad `13px 14px` gap 12, active `--surface2`; leading icon **22px** `--onVar`, label flex:1 **14/600** `--on`, trailing value **13px** `--onVar`, chevron `chevron_left` **20px**): Language `language`/اللغة/العربية · Currency `payments`/العملة/`USD ($)` (Roboto) · Data-saver toggle `data_saver_on` + title توفير البيانات + sub تحميل صور بجودة أقل + `DcSwitch`.
- **Group 3 Notifications (الإشعارات)** — 3 toggle rows (no leading icon): عقارات جديدة مطابقة (ON), الرسائل والردود (ON), العروض والتنبيهات التسويقية (OFF).
- **Group 4 About & Support (حول والدعم)** — 5 nav rows: `info`→عن تطبيق النجوم · `support_agent`→تواصل مع الدعم · `description`→الشروط والأحكام · `shield`→سياسة الخصوصية · `star_rate`→قيّم التطبيق. Version footer center pad `16px 0 4px` **12px** `--onVar` Roboto: `النجوم · الإصدار 2.4.0`.

**Toggle switch (DcSwitch):** track **46×28** radius 100 pad 3; ON bg `--primary` thumb **22×22** white flex-end; OFF bg `--outline` thumb `--surface` flex-start.
**NEW:** `DcSettingsSection({label,child})`, `DcSettingsGroupCard({children})`, `DcSettingsNavRow({icon?,title,subtitle?,trailingText?,showChevron})`, `DcSettingsToggleRow`, `DcSwitch`, `DcSegmentedControl` (reused by States tabs).

---

## SCREEN 4 — Shared States Showcase · `الحالات المشتركة` (lines 165–209)
**Shell:** `DcCrownScaffold` + scroll. Crown identical to Settings; title `الحالات المشتركة`.
Content sheet (surface, radius `20 20 0 0`, mt -14, pad `16px 14px 26px`):
1. Intro para **13px** `--onVar` lh 1.7 mb 14: مكوّنات موحّدة تُعاد عبر كل قوائم التطبيق…
2. Tab strip = `DcSegmentedControl` (labels فارغ تعليمي · خطأ · هيكل تحميل), mb 16.
3. Preview box: 1px `--divider`, radius **16**, min-height 360, bg `--bg`.

- **EMPTY** (pad `52px 30px` centered): badge **84×84** circle bg `--tonal`, icon `bookmark` **42px** `--onTonal`, mb 18; title لا عقارات محفوظة بعد **17/700** `--on`; body اضغط على أيقونة القلب… **13px** `--onVar` lh 1.7; CTA تصفّح العقارات mt 20 h44 pad `0 22` radius 100 bg `--primary` `--onPrimary` **13/700** (hug width).
- **ERROR** (same frame): badge bg `--redC` icon `cloud_off` `--onRedC`; title تعذّر تحميل البيانات; body حدث خطأ في الاتصال بالخادم…; retry CTA icon `refresh` **19px** + إعادة المحاولة gap 6.
- **LOADING** (pad 14, gap 12): 3 skeleton listing cards — card 1px `--divider` radius **12** overflow hidden bg `--surface`; image block 100%×aspect **16/10** shimmer `linear-gradient(90deg, surface2 25%, divider 37%, surface2 63%)` size `400% 100%` `shim 1.4s`; text block pad 11 gap 8, 3 shimmer bars radius 6 (42%×15 / 78%×12 / 60%×12).

**NEW (state kit — highest value):** `DcEmptyState({icon,iconTint:tonal,title,body,ctaLabel,onCta})`, `DcErrorState({icon:cloud_off,title,body,onRetry})`, `DcSkeletonListLoading({count})`, `DcSkeletonListingCard`, `DcShimmerBox({width,height,radius})`.

---

## Cross-screen notes
- RTL: back = `arrow_forward`; row-forward chevron = `chevron_left`; skip/back on RIGHT.
- Crown+sheet pattern (Settings/States): `--header` bg, pad `34px 8px 16px`, 40px white icon btn, 18/700 white title, then `--surface` sheet radius `20 20 0 0` mt -14 z-index 2.
- Segmented control appears twice (theme mode + state tabs) → one `DcSegmentedControl`.
- Splash+Onboarding = `DcAuthScaffold`; Settings+States = `DcCrownScaffold`.
- Appearance segmented control IS the app theme switch (auto = system).
- Only version string + currency value are Roboto/western; rest Noto Sans Arabic.
