# Prompt for Claude Design — the AlNujom ADMIN / super-admin console (Tier E)

Paste into a **new claude.ai/design chat** and ask for a design artifact. This is
the **admin batch** that was intentionally deferred from the A–D handoff. It
continues the approved `AlNujom.dc.html` "Blue Crown" system exactly. If it's too
much for one artifact, ask it to deliver in the marked groups (E1 → E5).

---

Continue the design of **"AlNujom" (النجوم)** — an Arabic-first (full RTL),
Material 3 Android real-estate marketplace for Syria. The whole buyer/publisher/
agency app is already designed and shipped in the "Blue Crown" system below.
Design the **internal ADMIN + super-admin console** in the SAME visual language so
it feels like one product. This is an operator tool (moderators/admins), so favor
**density, scannability, and fast queues** over marketing polish — but never an AI
mockup; it must look like a real ops console (think Stripe/Linear discipline, in
the Blue Crown skin).

## REUSE THIS EXACT SYSTEM (do not invent new colors/components)

Tokens (light / dark):
- bg #EAEDF2 / #0C0C10 · card/surface #FFFFFF / #131318 · surface2 #F2F4F9 / #1C1D25
- primary #1F4FE6 / #AEC2FF · brand crown header #1A3FC4 / #12235E (white text) · crown field #FFFFFF / #20232C
- tonal button #E2E9FF / #26356E (text #123287 / #DCE4FF) · selected/pill #DAE1F6 / #2A3352 (text #182C58 / #DEE4FA)
- text #1A1C22 / #E7E8ED · secondary #5B6070 / #A7ABB8 · chip/button border #C6CAD6 / #3B3D48 · divider #E7EAF1 / #26272F
- verified/success green #0E7A3C on #E4F3E9 (dark #74D99A on #12331F) · WhatsApp #1FA855 · gold(featured) #8A6912 on #FBEDC7
- **red/danger #D93B3B on #FBE6E6 (text #B42318; dark #FF6B6B on #3A1414 text #FF9B9B)** — reject/dismiss/destructive · amber/pending warning #C98318

Components already designed (reuse identically): the deep-blue **crown header**
(brand-blue bar, bold white title, back button, trailing white actions) over a
**white sheet** with a rounded top; **status chips** (green/red/neutral/outline
soft pills); the **KPI stat card** (flat surface + hairline, tonal icon chip,
optional ↑green/↓red trend); **single-hue bar charts**; the **moderation timeline**
(connected toned nodes); **document-verification rows**; tonal/outlined/filled pill
buttons; **grouped tool tiles** (tonal icon square + label + optional red count
badge); grouped list sections with toggle/nav rows. Fonts: Noto Sans Arabic +
Roboto for digits. **WESTERN digits everywhere** ($210,000, ٤ → 4). Material
Symbols icons. Android status bar tinted brand-blue. **Light AND dark for every
screen.**

Semantic color discipline: green = approved/verified/success only; red =
reject/dismiss/destructive/unread only; amber = pending/needs-review only; gold =
featured only; blue = actions/selection only. BANNED (reads as AI): glassmorphism/
blur, gradients (the CURRENT admin console wrongly uses a pink gradient header —
replace it with the flat brand crown), radii > 16, oversized padding, all-bold
text, Arabic-Indic numerals, emojis in UI.

## SCREENS TO DESIGN

### E1 — Admin home / console
1. **لوحة الإدارة (Admin console/home)** — a flat brand crown "لوحة الإدارة", a
   4-up **KPI row** (pending accounts, pending listings, open reports, active ads),
   then **grouped tool tiles** by section with **pending-count red badges**:
   - الإشراف (Moderation): مراجعة الحسابات · مراجعة الإعلانات · البلاغات · الوكالات · الاستفسارات
   - المحتوى (Content): الإعلانات المموّلة (ads) · المواقع · العملات
   - النظام (System): التحليلات · سجلّات التدقيق · الإعدادات · الأدوار (super-admin only)
   Each tile = tonal icon square + label + optional red count. Show a "مشرف عام /
   super-admin" identity chip in the crown when the viewer is super-admin.

### E2 — Moderation queues (the operator's daily work)
2. **مراجعة الحسابات (Account approvals)** — a queue of pending users: avatar +
   name + phone + "طلب منذ …" + a **موافقة/رفض** action pair per row; a filter
   (معلّق/مقبول/مرفوض) as crown underline tabs; an empty "لا طلبات معلّقة" state.
3. **مراجعة الإعلانات (Listing review)** — (a) a **queue** of pending listings
   (thumb + title + publisher + price + submitted-ago + status chip); (b) a
   **listing preview** detail with the full listing + a sticky action bar
   **موافقة / رفض (مع سبب) / تمييز**; (c) a **revision review** showing a
   before/after **diff** (old value struck / new value highlighted) for a
   stay-live edit, with موافقة التعديل / رفض التعديل.
4. **البلاغات (Reports)** — a reports queue (icon + subject «إعلان: …» / «مستخدم: …»
   + reason + reporter + status chip) and a **report detail** with the reported
   entity preview + resolve/dismiss actions.
5. **الوكالات (Agencies admin)** — an agency verification queue (logo + name +
   "عضو منذ" + doc-count + status) and an **agency detail** showing the uploaded
   verification documents (the doc-verification rows) with approve/reject per doc
   + an overall verify/decline.

### E3 — Content management
6. **إدارة الإعلانات المموّلة (Ads)** — an ads list (image preview + caption +
   placement + schedule window + priority + active toggle) and an **ad editor**
   form (image upload, caption, link URL + in-app target, placements multi-select,
   start/end date, priority, active).
7. **المواقع (Locations)** — governorates → cities → areas as an expandable list
   + a **location form** with name (ar/en), parent, and a **map centroid picker**
   (a map with a draggable pin) for areas.
8. **العملات (Currencies)** — a currencies list (code + symbol + name + active) +
   a **currency form** + **set-exchange-rate** (rate vs base) + a small **rate
   history** table/sparkline.

### E4 — Analytics & audit (⭐ the charts surface)
9. **التحليلات (Admin analytics)** — the RICHEST charts in the app: a KPI row +
   **listings/users/leads over time (line or area)**, **listings by governorate
   (horizontal bars)**, **category mix (donut)**, and a **cohort/activity heatmap**.
   Keep the **single-hue token palette** (primary blue ramp; success/danger only
   for up/down) — NO rainbow. This screen is where richer chart types are wanted;
   design them clean and legible, not decorative.
10. **سجلّات التدقيق (Audit logs)** — a dense, filterable log viewer: timestamp +
    actor (role, never a raw admin identity to publishers) + action + target +
    a details expander; filters by action type + date range.

### E5 — System / super-admin
11. **الإعدادات (App settings)** — grouped toggles/fields: maintenance mode,
    default locale + currency, feature flags, moderation thresholds — using the
    grouped list-section + toggle-row idiom.
12. **الأدوار (Roles — super-admin only)** — a roles list (name + member count +
    permission-count), a **role editor** (permission checklist grouped by
    category), create-role, and **assign role to user**.

## CONTENT REALISM
Real Syrian data: publisher names («مكتب الشام العقاري»، «دار الياسمين للعقارات»),
Damascus/Aleppo areas (أبو رمانة، المزة، كفر سوسة، الحمدانية، صحنايا), USD prices
$52,000–$340,000, relative times (منذ 3 ساعات)، pending counts (7 حسابات، 12 إعلاناً،
5 بلاغات). Reject reasons: صور غير واضحة / سعر غير واقعي / موقع خاطئ / وصف ناقص /
إعلان مكرّر. Show light AND dark. Density first — these are queues an operator works
through fast.
