# Prompt for Claude Design — the COMPLETE AlNujom app (all remaining screens)

Paste this into a **new claude.ai chat** (English instructions; the generated UI
stays Arabic). It continues the approved `AlNujom.dc.html` "Blue Crown" design so
every new screen drops into the same app. Ask for a design artifact. If it's too
much for one artifact, ask it to deliver in the batches marked **TIER 1 → 2 → 3**.

---

Continue the design of "AlNujom" (النجوم), an Arabic-first (full RTL), Material 3
Android real-estate marketplace for Syria. I already have Home, Search results and
Listing Detail designed (the "Blue Crown" system below). Design ALL the remaining
screens, states and components in the SAME visual language so they form one
complete, shippable app that looks like Bayut / dubizzle / OpenSooq — never an AI
mockup.

## REUSE THIS EXACT SYSTEM (do not invent new colors/components)

Tokens (light / dark):
- bg #EAEDF2 / #0C0C10 · card/surface #FFFFFF / #131318 · surface2 #F2F4F9 / #1C1D25
- primary #1F4FE6 / #AEC2FF · brand crown header #1A3FC4 / #12235E (white text) · crown search field #FFFFFF / #20232C
- tonal button #E2E9FF / #26356E (text #123287 / #DCE4FF) · selected/pill #DAE1F6 / #2A3352 (text #182C58 / #DEE4FA)
- text #1A1C22 / #E7E8ED · secondary text #5B6070 / #A7ABB8 · chip/button border #C6CAD6 / #3B3D48 · card border/divider #E7EAF1 / #26272F
- verified green #0E7A3C on #E4F3E9 (dark #74D99A on #12331F) · WhatsApp #1FA855 · gold(featured) #8A6912 on #FBEDC7 · red(badges) #D93B3B · heart #FF5B6E

Components (already designed — reuse identically): the deep-blue crown header with
a white search field and a white content sheet (rounded top 20) overlapping it; the
bottom navigation with a pill indicator behind the selected icon (الرئيسية، البحث،
المحفوظة، الرسائل، حسابي); the listing card (16:10 photo, موثّق green badge, heart,
bold price, bed/bath/area specs, title, location · time, a hairline, then publisher
name + verified tick + tonal "اتصال" + green "واتساب"); tonal/outlined/filled pill
buttons; filter chips (removable ×, toggle ✓); tonal icon squares. Fonts: Noto Sans
Arabic + Roboto for digits. **WESTERN digits everywhere** (123, $210,000). Material
Symbols icons. Android status bar tinted brand-blue, clock on the LEFT. Light AND
dark for every screen.

Semantic color discipline: green = verified + WhatsApp only; a small gold chip =
"featured" only; red = unread badges + destructive only; blue = actions + selection
only. Nothing decorative. BANNED (reads as AI): glassmorphism/blur, gradients,
floating pill nav, radii > 16, oversized padding, all-bold text, Arabic-Indic
numerals, emojis in UI.

## TWO DESIGN DECISIONS I WANT YOU TO MAKE
1. **The buy / rent / daily-rent control.** On Home it is currently a full-width
   segmented pill and it feels heavy / out of place. Redesign this: EITHER move it
   into the search-and-filters flow (a top-level toggle inside the Search screen and
   the Filters sheet), OR replace the Home version with a lighter treatment (e.g. a
   compact tab strip under the crown, or a chip row). Show your recommendation.
2. **Ad banner / sponsored slot.** Design a clean, premium ad component that appears
   in the Home feed, the Search results, and the Listing detail — clearly labeled
   "إعلان" / sponsored, never intrusive, that fits the card system (not a loud
   coloured box). Include its empty/collapsed state (renders nothing when no ad).

## SCREENS TO DESIGN

### TIER 1 — core buyer/renter + publisher journey (most important)
1. **الفلاتر (Filters bottom sheet)** — opened from Search. Sections: الغرض (buy/rent/
   daily segmented — per decision #1), نوع العقار (chips), المدينة/المنطقة, نطاق السعر
   (range slider), الغرف/الحمامات (1/2/3/4+ stepper chips), المساحة, نوع الطابو (طابو
   أخضر…), الكسوة (سوبر ديلوكس…), a "الموثّقة فقط" switch. Sticky footer: "مسح الكل" +
   "عرض (24) نتيجة".
2. **الخريطة (Map results)** — full-screen map with price pins; a peeking bottom card
   carousel of listings in view; a list/map toggle; the filter chips row on top.
3. **المحفوظة (Saved)** — two tabs: العقارات (saved listing cards) and عمليات البحث
   (saved searches: query + filters summary + result count + an alert bell toggle).
   Teaching empty states for both.
4. **الرسائل (Conversations list)** + **المحادثة (Chat thread)** — list rows (avatar,
   name + verified tick, last message, time, unread count). Thread: in-app bubbles, a
   pinned listing-preview card at the top, an input bar with attach.
5. **حسابي (Account)** + **تعديل الملف (Edit profile)** — profile header (avatar, name,
   phone, verified state, publisher status), grouped rows (إعلاناتي، المفضلة، عمليات
   البحث المحفوظة، لوحة الناشر، الإعدادات، اللغة، المظهر، المساعدة، تسجيل الخروج).
6. **أضف إعلانك (Add-listing flow)** — a stepper: (a) الغرض + نوع العقار, (b) الموقع
   (governorate/city/area + map pin), (c) التفاصيل (rooms/baths/area/floor/طابو/كسوة),
   (d) الصور (upload grid + cover), (e) السعر + الوصف, (f) مراجعة ونشر. Also a compact
   "express" single-scroll variant. Stepper header + primary التالي/نشر.
7. **الإشعارات (Notifications center)** — rows (icon, title, body, time; unread tint +
   dot), date section headers, empty state.
8. **الدخول / التسجيل / استعادة كلمة المرور / رمز التحقق (Auth)** — login (phone/email +
   password), register, reset-password, OTP; brand crown + star logo at top; a
   "متابعة كزائر" option. Plus the account-status screens: قيد المراجعة (pending),
   مرفوض (rejected), موقوف (suspended).

### TIER 2 — publisher / agency + secondary
9. **لوحة الناشر (Publisher dashboard)** + **إعلاناتي (My listings)** + **تحليلات
   العملاء (Lead analytics)** + **سجل المراجعة (Moderation history)** — KPI stat cards,
   simple bar/line charts (using the token palette, not rainbow), listing rows with
   status pills (منشور/قيد المراجعة/مرفوض/منتهٍ).
10. **صفحة الوكالة (Agency profile)** + edit + listings + members + analytics +
    verification — an agency header (logo, name, verified, "عضو منذ", listing count),
    tabs.
11. **المقارنة (Compare listings)** — 2–3 listings side by side in a scrollable table
    (price, specs, deed, finish, location) with sticky row labels.
12. **جولات فيديو / ريلز (Reels)** — full-screen vertical video feed with a listing
    overlay card (price, title, save, contact), used as a Home rail + a tab.
13. **المساعد (AI search assistant)** — a conversational search entry ("شقة بدمشق تحت
    100 ألف") with result chips.
14. **طلبات المعاينة (Viewings)** + **الاستفسارات (Inquiries inbox + detail)** — request
    rows with status, date, listing preview.

### TIER 3 — states, components, chrome (specs, not full screens)
15. **Empty / error / loading states** for every list (teaching empty states, a
    friendly error with retry, skeleton loaders shaped like the real content).
16. **Dialogs / bottom sheets / snackbars / toasts** — confirm-delete dialog, a
    generic action bottom sheet, success/error snackbars.
17. **Onboarding + Splash** — 3-slide intro + the branded splash.
18. **Search entry / recent searches** — the state after tapping the search field
    before typing (recent + suggested searches).
19. **Settings + About/Support** — grouped toggle/row settings, language, theme,
    data-saver, contact-support.

## CONTENT REALISM
Real Damascus/Aleppo/rural areas (أبو رمانة، المزة، كفر سوسة، الحمدانية، دمشق القديمة،
صحنايا)، USD prices $52,000–$340,000 with "≈ … مليار/مليون ل.س" secondary lines,
relative times (منذ يوم، منذ 3 أيام), Syrian features (field verification موثّق ميدانياً،
طابو أخضر، الكسوة سوبر ديلوكس، WhatsApp-first). Publisher/agency names like "مكتب الشام
العقاري"، "دار الياسمين للعقارات". Show light AND dark.
