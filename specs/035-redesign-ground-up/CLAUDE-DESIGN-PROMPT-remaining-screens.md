# Prompt for Claude Design — the screens NOT in AlNujom.dc.html

Paste into a **new claude.ai chat** and ask for a design artifact. It continues
the approved `AlNujom.dc.html` "Blue Crown" system (Home/Search/Detail/Saved/
Messages/Chat/Account/Notifications/Map/Add-listing/Auth/Filters were already
designed and built) and covers everything that handoff did **not**. If it's too
much for one artifact, ask it to deliver in the batches marked **TIER A → E**.

---

Continue the design of "AlNujom" (النجوم), an Arabic-first (full RTL), Material 3
Android real-estate marketplace for Syria. The core buyer/renter journey is
already designed and shipped in the "Blue Crown" system below — design the
REMAINING screens (publisher tools, agency, special features, chrome, and
admin) in the SAME visual language so the whole app stays one coherent product.
Never an AI mockup — it must look like Bayut / dubizzle / OpenSooq.

## REUSE THIS EXACT SYSTEM (do not invent new colors/components)

Tokens (light / dark):
- bg #EAEDF2 / #0C0C10 · card/surface #FFFFFF / #131318 · surface2 #F2F4F9 / #1C1D25
- primary #1F4FE6 / #AEC2FF · brand crown header #1A3FC4 / #12235E (white text) · crown field #FFFFFF / #20232C
- tonal button #E2E9FF / #26356E (text #123287 / #DCE4FF) · selected/pill #DAE1F6 / #2A3352 (text #182C58 / #DEE4FA)
- text #1A1C22 / #E7E8ED · secondary text #5B6070 / #A7ABB8 · chip/button border #C6CAD6 / #3B3D48 · divider #E7EAF1 / #26272F
- verified green #0E7A3C on #E4F3E9 (dark #74D99A on #12331F) · WhatsApp #1FA855 · gold(featured) #8A6912 on #FBEDC7 · red #D93B3B · heart #FF5B6E

Components already designed (reuse identically): the deep-blue **crown header**
(brand-blue bar with a bold white title, back button, and trailing actions) over
a **white sheet** with a rounded top; the **bottom nav** with a pill indicator
(الرئيسية، البحث، المحفوظة، الرسائل، حسابي); the **listing card** (16:10 photo,
موثّق badge, heart, bold price, bed/bath/area, title, location · time, hairline,
publisher + verified tick + tonal اتصال + green واتساب); **underline tabs** on the
crown; the **"إعلان" sponsored card**; the detail **sticky اتصال/دردشة/واتساب bar**;
tonal/outlined/filled pill buttons; filter chips; the **facts strip** (surface2
strip of icon-over-value columns); the **green verify card**; tonal icon squares.
Fonts: Noto Sans Arabic + Roboto for digits. **WESTERN digits everywhere**
($210,000). Material Symbols icons. Android status bar tinted brand-blue.
**Light AND dark for every screen.**

Semantic color discipline: green = verified/WhatsApp/success only; gold = featured
only; red = unread/destructive only; blue = actions/selection only. BANNED (reads
as AI): glassmorphism/blur, gradients, floating pill nav, radii > 16, oversized
padding, all-bold text, Arabic-Indic numerals, emojis in UI.

## SCREENS TO DESIGN

### TIER A — Publisher tools (a publisher runs their business here; highest value)
1. **لوحة الناشر (Publisher dashboard)** — KPI stat cards (active listings, views,
   leads, response rate), a simple bar/line chart in the token palette (no
   rainbow), and quick links to the sections below.
2. **إعلاناتي (My listings)** — the publisher's own listings as rows/cards with a
   status pill (منشور / قيد المراجعة / مرفوض / منتهٍ / مسودّة), views + leads counts,
   and per-row actions (تعديل / تمييز / أرشفة).
3. **تحليلات العملاء (Lead analytics)** — lead events over time (calls / WhatsApp /
   inquiries / viewings) as token-palette charts + a leads table.
4. **سجل المراجعة (Moderation history)** — a timeline of a listing's review events
   (submitted / approved / rejected-with-reason / revision requested).
5. **إدارة العملاء المحتملين — CRM** — a **leads list** (name, source badge
   [conversation/inquiry/viewing], stage, last-contact) + a **lead detail** (contact,
   notes timeline, reminders, stage changer).
6. **الاستفسارات (Inquiries inbox + detail)** — inbox rows (buyer, listing preview,
   message, time, unread) + a detail thread with a reply box.
7. **طلبات المعاينة (Viewings)** — request rows with a status pill (معلّق / مؤكّد /
   مرفوض / منتهٍ), date/time, listing preview, and confirm/decline actions.

### TIER B — Agency
8. **صفحة الوكالة (Agency profile)** — a header (logo, name, verified, "عضو منذ",
   listing + rating counts) with tabs: العقارات / نبذة / الأعضاء / التقييمات.
9. **إدارة الوكالة** — edit agency profile, **members** (list + roles + invite),
   **agency analytics**, and **verification** (upload documents + status).

### TIER C — Special features (user-facing)
10. **المقارنة (Compare)** — 2–3 listings side by side in a scrollable table
    (photo, price, beds/baths/area, deed, finish, location) with sticky row labels
    and a per-column remove.
11. **ريلز / جولات فيديو (Reels)** — a full-screen vertical video feed with a listing
    overlay (price, title, save, contact) + a right-rail of actions; and the Reels
    **tab** entry.
12. **الجولة الافتراضية 360° (Panorama viewer)** — a full-screen 360° photo viewer
    with a thumbnail strip of scenes and a close/share control.
13. **المساعد الذكي (AI assistant)** — a conversational search entry ("شقة بدمشق تحت
    100 ألف") with suggestion chips and result cards inline.
14. **كتابة تقييم (Write review)** — a bottom sheet: star rating + text + submit, and
    the **reviews list** state (avg + count + review cards).
15. **عمليات البحث المحفوظة (Saved searches — full page)** — saved-query cards (query
    + filters summary + result count + an alert-bell toggle) with a teaching empty.
16. **معلوماتي الخاصة (Private profile)** — the user's private info (ID/phone/email
    verification states) in grouped rows.
17. **بلاغاتي (My reports)** — the reports the user filed, with status.

### TIER D — Chrome & states
18. **المقدمة (Onboarding)** — a 3-slide intro (value props) + skip/next + dots.
19. **شاشة البداية (Splash)** — the branded splash (logo on brand-blue).
20. **الإعدادات + حول والدعم (Settings + About/Support)** — grouped toggle/row settings
    (language, theme, data-saver, notifications) + about/contact-support.
21. **الحالات المشتركة (Shared states)** — teaching empty states, a friendly error
    with retry, and skeleton loaders shaped like the real content — for every list.

### TIER E — Admin & super-admin (internal tools; lower priority, design if time)
22. **لوحة الإدارة (Admin console/home)** — grouped tool tiles (approvals, listing
    review, reports, agencies, ads, analytics, locations, currencies, settings,
    roles, audit logs) with pending-count badges.
23. **مراجعة الحسابات (Account approvals)** — pending-user queue + approve/reject.
24. **مراجعة الإعلانات** — pending-listing **queue**, a **listing preview** (approve /
    reject-with-reason / feature), and a **revision review** (before/after diff).
25. **البلاغات (Reports)** — reports queue + report detail (resolve/dismiss).
26. **إدارة الإعلانات المموّلة (Ads)** — ads list + an ad editor (image, caption,
    link, placements, schedule, priority).
27. **الوكالات (Agencies admin)** — agency verification queue + agency detail.
28. **التحليلات + سجلّات التدقيق (Analytics + audit logs)** — admin analytics
    dashboards + an audit-log viewer.
29. **المواقع (Locations)** — governorates/cities/areas list + a location form with a
    map centroid picker.
30. **العملات (Currencies)** — currencies list + a currency form + set-exchange-rate
    + rate history.
31. **الإعدادات + الأدوار (App settings + roles)** — app-settings editor; and
    super-admin **roles** (list, editor, create, assign).

## CONTENT REALISM
Real Damascus/Aleppo/rural areas (أبو رمانة، المزة، كفر سوسة، الحمدانية، دمشق القديمة،
صحنايا)، USD prices $52,000–$340,000 with "≈ … مليار/مليون ل.س" secondary lines,
relative times (منذ 3 أيام), Syrian specifics (موثّق ميدانياً، طابو أخضر، الكسوة سوبر
ديلوكس، WhatsApp-first), publisher/agency names ("مكتب الشام العقاري"، "دار الياسمين
للعقارات"). Show light AND dark.
