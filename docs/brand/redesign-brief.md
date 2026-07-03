# Al Nujom — Ground-up UX Redesign Brief (Claude Design prompt + research)

> Status: research DONE, prompt READY. Next: founder runs the prompt in claude.ai
> (Claude Design), picks a direction, brings the artifact back → we rebuild the
> Flutter app against it (restructure, not re-skin).

## Why this exists

After the full design-system restyle (PRs #89/#90/#91) the founder's verdict was:
"I don't like the app style, widgets, and how it's divided." The problem is the
**structure / information architecture**, not the colors. So: benchmark the best
real-estate apps, then generate a ground-up multi-screen redesign to choose from.

## Research benchmark (deep-research, completed 2026-07)

**Top 3 global:** Zillow, Redfin, Idealista
**Top 3 Arab world:** Bayut, Property Finder, OpenSooq
**Top 3 Syria:** OpenSooq Syria, AqaarGate, Byoot

Verified findings that drive the redesign:

1. **Trust is the #1 differentiator in MENA.** Bayut **TruCheck**: two-tier badge —
   docs "Checked" + a GPS-locked site-visit photo taken within 500 m, timestamped,
   **expiring**, and ranked first in search. Property Finder **SuperAgent**: verified
   profile + listing quality + **WhatsApp responsiveness** (replies < 2 h).
2. **Syrian apps already bet on trust:** AqaarGate ("Safest Way to Buy & Sell",
   verified listings + natural-language AI search); Byoot (3 **transaction modes**
   as top-level nav + Syria-native filters: deed type طابو أخضر/أحمر/مؤقت/زراعي,
   finish على العظم → سوبر ديلوكس); OpenSooq (deep محافظة→مدينة→منطقة tree — but
   property buried inside general classifieds = a pitfall to avoid).
3. **Global UX to borrow:** Redfin draw-your-own-search-area on the map; Idealista
   rich-but-optional media; usability finding: show listings immediately on the
   landing screen and keep Saved/Favorites in the primary nav.
4. **Hard constraint:** Syrian phones are low-end and mobile data is expensive →
   lightweight, image-frugal, data-saver mode, skeletons, graceful offline.

Refuted claims — do NOT reuse: Byoot "first Syrian app"; PF "+25% WhatsApp
conversion"; 2G-penetration figures; Bayut "guarantees depiction matches reality".

## Decisions already locked

- **IA: 5 tabs** — استكشف (Home) · بحث+خريطة · المحفوظة · الرسائل · حسابي + prominent
  أضف عقار. **Reels folds into Home** as a "جولات فيديو" video-tours rail.
- Brand: royal blue `#1F4FE6`, navy `#0B182B`, steel `#9AA4B2`, surface `#F5F7FA`,
  gold `#C2A14D` = Featured ONLY, coral `#F4795B` favourite, green `#1F7A4D`
  verified / `#1DAB61` WhatsApp. Font **Tajawal**. Orbit-emblem logo.
- Verification model adapted for Syria (no reliable land registry): site-visit +
  geotagged live photo + freshness timestamp, verified ranks first, "الموثّقة فقط" filter.

---

## THE PROMPT (paste into claude.ai / Claude Design, attach the orbit logo)

You are a senior product designer. Design the complete UI/UX, ground-up, for
"النجوم / Al Nujom" — an Arabic-first (RTL) real-estate app for SYRIA. Output ONE
long scrollable HTML artifact showing every screen below as mobile frames (~390px),
in Arabic RTL, with realistic Syrian content (دمشق/حلب/اللاذقية; prices in ل.س and $).
Make it look like a real, shipped, premium app — not a generic AI mockup. At the
very top, output a design-tokens table (colors, type, spacing, radii) so a
developer can rebuild it 1:1 in Flutter/Material 3.

**MARKET TRUTH (drives every decision):** Syrian buyers distrust Facebook-group
listings and fear scams; they contact sellers by WhatsApp/phone; phones are
low-end and mobile data is expensive. So this app must win on TRUST + SIMPLICITY +
being LIGHTWEIGHT, not feature volume.

**BRAND:** royal blue #1F4FE6, navy #0B182B, steel #9AA4B2, surface #F5F7FA, white
cards; Tajawal font; gold #C2A14D for the "مميّز/Featured" badge ONLY; coral
#F4795B favourite; green #1F7A4D verified / #1DAB61 WhatsApp.

**INFORMATION ARCHITECTURE — 5 tabs:** استكشف (Home) · بحث+خريطة (Search/Map) ·
المحفوظة (Saved) · الرسائل (Messages) · حسابي (Account), plus a prominent أضف عقار
publish action. Show listings immediately on Home (no empty landing). Keep Saved
in the nav.

**SIGNATURE FEATURES TO DESIGN (the differentiators):**
1. Trust/verification (the #1 thing): a visible "موثّق / Verified" badge on
   listings + agents, Syria-adapted (no land registry): owner/agent site-visit +
   geotagged live photo + a freshness timestamp ("تم التأكد من توفّره قبل ٣ أيام");
   verified listings rank first; a "الموثّقة فقط" filter. Clearly show a verified
   vs. unverified listing.
2. Transaction modes as a primary segmented control: للبيع · إيجار سنوي · إيجار شهري/يومي.
3. Syria-native filters: نوع الملكية/الطابو (أخضر/أحمر/مؤقت/زراعي), الكسوة (على
   العظم → سوبر ديلوكس), مفروش, الغرف, الحمامات, السعر, and المحافظة→المدينة→المنطقة.
4. WhatsApp-first contact + a responsiveness signal ("يرد عادة خلال ساعة");
   one-tap واتساب / اتصال / حجز معاينة.
5. Smart search bar: natural-language ("شقة بدمشق تحت ١٠٠ ألف دولار") sitting
   above the filters.
6. Map search with a draw-your-area tool + a bottom listing sheet + verified
   markers — kept data-light.
7. Lightweight / data-frugal: a visible "وضع توفير البيانات", skeleton loaders,
   one image per card by default, graceful empty/offline states.

**SCREENS (design all, cohesive):**
1. Splash + one onboarding slide.
2. Home (استكشف): top bar (logo + city selector + notifications), NL search bar,
   transaction-mode toggle, category chips, a Featured "مميّز" row (gold), then
   the listing feed immediately, an optional "جولات فيديو" video-tours rail, a
   trust strip. Bottom nav.
3. Search results + filter sheet (all the Syria filters above) + Map view
   (draw-area, bottom sheet, verified price markers).
4. Listing detail: photo gallery → verified badge + timestamp → price → key facts
   (غرف/حمامات/مساحة/طابق/كسوة/طابو tiles) → mini-map → agent card (verified +
   responsiveness + واتساب/اتصال/حجز معاينة) → description → similar listings.
5. Saved (المحفوظة): saved listings + saved searches with alert toggles.
6. Messages: conversation list + a WhatsApp-style thread.
7. Add listing (أضف عقار): a guided multi-step flow including the verification
   step (capture the geotagged photo).
8. Account (حسابي): profile + my listings + settings + language + data-saver.
9. A small component library: listing card (with a verified variant), buttons,
   chips/filters, badges (verified / featured / transaction), inputs, bottom nav,
   empty + skeleton states.

**REQUIREMENTS:** RTL everywhere; light AND dark for Home + Listing-detail; WCAG
AA; keep it Flutter/Material-3-implementable (gradients, shadows, blur, standard
layouts — no effects that can't translate); realistic Syrian Arabic content, not
lorem ipsum.

**AT THE END:** also show 2 alternative Home-screen directions — one "minimal &
calm" (Airbnb-style: big photos, lots of whitespace) and one "rich & dense"
(Bayut/Zillow-style: more data per card, filters up front) — so I can choose the
overall vibe.

Make it the single best, most cohesive version you can.

---

## FOLLOW-UP PROMPT #2 (paste into the SAME Claude Design chat)

Decision: instead of picking ONE home direction, ALL THREE become user-switchable
view modes (like OpenSooq/Bayut list-grid switch). This prompt adds the switcher
+ the screens the first artifact skipped (login/signup/notifications).

### English version

```text
In the exact same design system and style, add the following:

1) A VIEW-MODE SWITCHER: we will NOT pick one home direction — we want all
three as user-switchable view modes. Design a small view-toggle button (icon)
that sits above the listings feed on Home and Search results. It opens a choice
of 3 modes: "Comfortable" (big photos, airy spacing), "Balanced" (the current
default), and "Compact" (dense rows, more info per row, a WhatsApp button on
every row). Show the SAME listings feed three times side by side in the three
modes with the switcher visible, and show the listing card in each mode
(including the green "Verified" badge and the gold "Featured" badge).

2) A Login screen (phone/email + password + continue as guest) and a Sign-up
screen.

3) A Notifications list screen (new listing matching a saved search, message
reply, verification status update, viewing-appointment reminder).

Same colors, same Tajawal font, same components, full RTL Arabic content like
the rest of the artifact.
```

### Arabic version (same content)

```text
في نفس النظام والتصميم تماماً، أضف ما يلي:

١) مبدّل طريقة العرض: لن نختار اتجاهاً واحداً للرئيسية — بل الاتجاهات الثلاثة معاً كأوضاع عرض يبدّلها المستخدم بنفسه. صمّم زراً صغيراً (أيقونة تبديل العرض) يظهر فوق قائمة العقارات في الرئيسية ونتائج البحث، يفتح اختياراً بين ٣ أوضاع: «مريح» (صور كبيرة ومساحات واسعة)، «متوازن» (الوضع الحالي الافتراضي)، «مضغوط» (صفوف كثيفة بمعلومات أكثر وزر واتساب على كل صف). اعرض نفس قائمة العقارات ثلاث مرات جنباً إلى جنب بالأوضاع الثلاثة مع المبدّل ظاهراً، وبيّن بطاقة العقار في كل وضع (مع شارة «موثّق» و«مميّز» الذهبية).

٢) شاشة تسجيل الدخول (هاتف/بريد + كلمة مرور + دخول كزائر) وشاشة إنشاء حساب.

٣) شاشة قائمة الإشعارات (عقار جديد يطابق بحثاً محفوظاً، رد على رسالة، تحديث حالة التوثيق، تذكير موعد معاينة).

بنفس الألوان والخط والمكونات، RTL كاملاً.
```

## After the founder picks

1. Founder runs the prompt, scrolls the artifact, picks the Home direction
   (minimal-calm vs rich-dense) and flags any screen to redo.
2. Founder sends the artifact/HTML (or screenshots) back here.
3. We rebuild against it as a new spec: restructured 5-tab IA, verification
   feature, transaction-mode control, Syria-native filters — a real restructure,
   not a re-skin. Backend additions (verification fields, deed/finish columns)
   get their own migrations via Supabase MCP.
