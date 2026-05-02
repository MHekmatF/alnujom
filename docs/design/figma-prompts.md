# AlNujom Figma prompt pack (DRAFT)

Copy-paste prompts for Figma AI, Magician for Figma, Galileo AI, Uizard, Visily, or v0. Each screen gets generated **twice** — once with the Direction A token block, once with the Direction B token block — so you can compare on real frames before picking.

Source of truth for tokens: [`docs/design/decision.md`](decision.md). When you pick a direction, the rejected token block goes to `docs/design/archive/`.

---

## 0. How to use this file

Every screen prompt has three parts that you assemble in order:

```
[BASE CONTEXT BLOCK]   ← paste once at top of any prompt; never changes
[TOKEN BLOCK A or B]   ← paste the one you want to render
[SCREEN PROMPT]        ← paste the specific screen
```

Workflow:

1. Open Figma → start a frame → invoke the AI plugin (First Draft, Magician, Galileo, etc.).
2. In the prompt box, paste **BASE + DIRECTION A + screen prompt**. Generate.
3. Duplicate the frame, swap to **DIRECTION B**, regenerate the same screen. You now have A and B side by side for that screen.
4. Repeat for the 12 core screens. ~2-3 hours of Figma work total.
5. Compare. Decide. Update `decision.md`.

### Tool-specific quirks

| Tool | Notes |
|---|---|
| Figma AI "First Draft" | Best for full-screen mockups. Accepts long prompts. Supports component variants via the "and generate variants" pattern. |
| Magician for Figma | Strong on isolated components. Use the component-sheet prompt at the bottom for this. |
| Galileo AI | Best high-fidelity. Charge per generation; give it the full base + token + screen block to avoid re-rolls. |
| Uizard / Visily | Wireframe-leaning. Token block matters less; lean on layout description in the screen prompt. |
| v0 by Vercel | Outputs React/Tailwind, not Figma. Visual reference only — use it for the **component sheet** to get raw layout + use those layouts in Figma manually. |

---

## 1. BASE CONTEXT BLOCK (paste at top of every prompt)

```
You are designing a mobile Android app screen for AlNujom (النجوم), an Arabic-first
real-estate marketplace serving Syria. Constraints that apply to every screen:

- Target device: Android phone, 360×800 dp viewport. Status bar at top, system nav bar at bottom. Design for the Infinix Note 8 form factor (6.78", 1080×2460 native, ~411×940 dp logical).
- Default language is Arabic with RTL layout. The brand mark renders as "النجوم" (Arabic) and "AlNujom" (Latin transliteration) — Arabic primary.
- All directional padding, alignment, and icons must mirror correctly under RTL. Show the Arabic version of every screen as the primary deliverable; you may also produce the LTR/English mirror as a secondary variant.
- Touch targets are ≥ 48×48 dp. Body text ≥ 4.5:1 contrast on its surface; large text and UI ≥ 3:1.
- No color-only state signals — every state is paired with an icon or label.
- The app is split across 24 build phases. The screens in this prompt pack are the MVP-establishing surfaces (auth, home, listing details, search, map, listing creation, profile, favorites). Admin/moderator screens reuse the same components and aren't critical for direction selection.
- Brand voice: confident, professional, calm. Syrian-friendly Arabic — natural Levantine register, not stiff Modern Standard Arabic. Place names: Damascus دمشق, Aleppo حلب, Homs حمص, Latakia اللاذقية, Tartus طرطوس, Hama حماة.
- Currencies are USD ($) and SYP (ل.س). Prices appear in the user's preferred currency with the alternate underneath in smaller, muted type.
- Photography: real-estate hero shots — exteriors, interiors, balconies, lobbies. Avoid stock-photo people; the listings are the heroes.
- On every full-screen frame you generate, place a small "Palette Tester" floating chip in the top-leading corner (inset 16 dp from each edge, below the status bar). The chip is a 32 dp tall pill with: a 12 dp color-swatch dot (filled with the active primary), a labelMedium text showing the active palette name ("Modern" or "Trust"), and a 16 dp "repeat" icon. Background = card, 1 px border = border token, elevation 2. This chip is the design-review counterpart to the runtime PaletteTester widget defined in `screens-and-components.md` § 5.18 — wire it to a Figma Variable named `palette` with values `Modern` and `Trust` so clicking the chip in prototype mode swaps every primary-colored element on the frame between #1D4ED8 (Modern) and #2457A6 (Trust). For each screen, generate two frames side by side: one with palette=Modern, one with palette=Trust.

Render the screen at 360×800 dp. Show the status bar with carrier "بـAlNujom" (or "AlNujom" in English mode), 5G/Wi-Fi icons, battery, and time 09:41. Show the system nav bar at the bottom (gesture pill).
```

---

## 2. DIRECTION A TOKEN BLOCK (Luxury / Premium)

```
Use these tokens for every color, typography, spacing, radius, and elevation
choice on this screen. Do not introduce values outside this set.

COLORS — light theme (use unless told otherwise):
- primary       #1A2332  (deep ink navy — buttons, headings, brand)
- onPrimary     #F5EFE0  (warm cream)
- secondary     #B8924A  (warm gold — accents, "featured" badges)
- onSecondary   #FFFFFF
- tertiary      #7A6E55  (muted bronze — supporting metadata)
- surface       #FAF7F2  (warm off-white — main background, NOT pure white)
- onSurface     #1A2332
- surfaceVariant #EFEAE0 (card backgrounds)
- onSurfaceVariant #4A4538
- outline       #8C8475
- error         #B23A2C  (muted brick red)
- success       #2E6D43  (forest green)
- warning       #B8860B  (antique gold)

COLORS — dark theme variant:
- primary       #C9B084  (warm gold)
- surface       #14110D  (rich near-black with warm undertone)
- onSurface     #F5EFE0
- surfaceVariant #2A2520

TYPOGRAPHY:
- Latin display / headline: Playfair Display, weight 600 (serif)
- Arabic display / headline: Reem Kufi, weight 600 (Kufic)
- Latin title / body / label: Inter, weights 600 / 400 / 500
- Arabic title / body / label: IBM Plex Sans Arabic, weights 600 / 400 / 500
- Type scale (size/line-height in dp):
  displayLarge 57/64, displayMedium 45/52,
  headlineLarge 32/40, headlineMedium 28/36,
  titleLarge 22/28, titleMedium 16/24,
  bodyLarge 16/24, bodyMedium 14/20,
  labelLarge 14/20

SPACING (4dp grid, generous):
xs 4, sm 8, md 16, lg 24, xl 32, xxl 48, xxxl 64.
Card padding default: lg (24). Screen gutters: lg (24).

RADII: sm 8, md 12, lg 16, xl 24, pill 999.
Cards: lg (16). Buttons: md (12). Dialogs: xl (24).

ELEVATION (low and soft — luxury reads as restraint):
0: none
1: 0 1 2 rgba(0,0,0,0.04)
2: 0 2 4 rgba(0,0,0,0.06)
3: 0 4 8 rgba(0,0,0,0.08)

VIBE: curated, gallery-like, calm. Generous whitespace. Photography is the hero.
Featured items get a subtle gold corner ribbon, not a noisy badge. Buttons are
filled-primary or outlined; pill buttons only for filter chips. Hero images:
16:9 on detail, 4:3 on cards.
```

---

## 3. DIRECTION B TOKEN BLOCK (Modern Tech / Marketplace)

```
Use these tokens for every color, typography, spacing, radius, and elevation
choice on this screen. Do not introduce values outside this set.

COLORS — light theme (use unless told otherwise):
- primary       #2457A6  (trust blue — buttons, headings, brand)
- onPrimary     #FFFFFF
- secondary     #00897B  (teal — CTAs, "active" states)
- onSecondary   #FFFFFF
- tertiary      #F57C00  (orange — "new" highlights, price callouts)
- surface       #F8FAFF  (cool off-white)
- onSurface     #152033
- surfaceVariant #E1E5EE
- onSurfaceVariant #44474E
- outline       #74777F
- error         #BA1A1A
- success       #2E7D32
- warning       #ED6C02

COLORS — dark theme variant:
- primary       #9FC5FF
- surface       #101722
- onSurface     #E8EEF9
- surfaceVariant #3E4856

TYPOGRAPHY (sans throughout, no serifs):
- Latin display / headline / title / body / label: Inter, weights 700 / 600 / 600 / 400 / 500
- Arabic display / headline / title: Cairo, weights 700 / 600 / 600
- Arabic body / label: IBM Plex Sans Arabic, weights 400 / 500
- Type scale (size/line-height in dp):
  displayLarge 45/52, displayMedium 36/44,
  headlineLarge 28/36, headlineMedium 24/32,
  titleLarge 20/28, titleMedium 16/24,
  bodyLarge 16/24, bodyMedium 14/20,
  labelLarge 14/20, labelMedium 12/16

SPACING (4dp grid, tighter density):
xs 4, sm 8, md 12, lg 16, xl 24, xxl 32, xxxl 48.
Card padding default: md (12). Screen gutters: lg (16).

RADII: sm 4, md 8, lg 12, xl 16, pill 999.
Cards: md (8). Buttons: md (8). Dialogs: lg (12). Crisper than A.

ELEVATION (defined hierarchy):
0: none
1: 0 1 3 rgba(0,0,0,0.10)
2: 0 2 6 rgba(0,0,0,0.12)
3: 0 4 12 rgba(0,0,0,0.14)

VIBE: efficient, scannable, marketplace. Search is the primary affordance —
prominent and persistent. Cards are dense and information-rich (price, location,
beds/baths, area, agency badge all visible). Pill chips for filters. Tertiary
orange used sparingly for "new" / price emphasis. Hero images: 4:3 on detail,
16:10 on cards.
```

---

## 4. Screen prompts (12 core screens)

Each prompt is self-contained except for the BASE + TOKEN preludes. Copy `BASE + DIRECTION A + screen prompt` for the A render; swap A for B and re-run for B.

### Screen 1 — Splash

```
Generate a splash screen.

Layout:
- Full-bleed surface color (warm off-white for A, cool off-white for B).
- Centered brand mark: "النجوم" in display weight, primary color, displayLarge size.
- Beneath it, in tertiary color and labelLarge, the Latin transliteration "AlNujom".
- Bottom safe area: a slim progress indicator bar (primary color, 2dp tall, 64dp wide, animating left-to-right under LTR / right-to-left under RTL).

No other content. Show both light and dark variants side by side.
```

### Screen 2 — Onboarding carousel (3 frames)

```
Generate a 3-frame onboarding carousel. Same layout structure for all three
frames; swap illustration + headline + body per frame.

Layout per frame:
- Top 60% of screen: an illustration area. For frame 1: a stylized
  apartment-building skyline of Damascus or Aleppo. For frame 2: a hand holding
  a phone showing a listing card. For frame 3: a map pin over a neighborhood.
  Use the brand colors only — no third-party stock illustrations.
- Bottom 40%: headline (headlineMedium, primary color, RTL Arabic), body
  (bodyMedium, onSurfaceVariant, RTL Arabic).
- Page indicator: 3 dots, 8dp spacing, active dot in primary color, inactive
  in outline.
- Two buttons: "تخطّي" (Skip) outlined-secondary on the leading edge; "التالي"
  (Next) filled-primary on the trailing edge. On the third frame, "التالي"
  becomes "ابدأ" (Get started).

Frame copy (Arabic):
- Frame 1: "اعرض عقارك ووصلك للزبائن" / "أنشر شقّتك أو محلّك خلال دقايق وانتشر بأهم المدن السورية."
- Frame 2: "شوف وقارن قبل ما تقرّر" / "صور واضحة، تفاصيل دقيقة، وتواصل مباشر مع أصحاب العرض."
- Frame 3: "خريطة لكل المدن السورية" / "من دمشق لحلب لحمص للساحل — العقارات بين إيدك."
```

### Screen 3 — Login

```
Generate a login screen.

Layout:
- AppBar: transparent, with a leading "→" back arrow (mirrored for RTL so the
  arrow points right in Arabic mode). Title empty.
- Brand mark "النجوم" centered, headlineLarge, primary color, with md (16) bottom
  margin.
- Subtitle "أهلاً بعودتك" (Welcome back), titleLarge, onSurfaceVariant.
- Phone-number field: a labeled text field with a country-code prefix dropdown
  showing "+963" Syria flag by default. Direction A: outlined input, lg radius,
  generous internal padding. Direction B: filled input, md radius, denser.
- Password field: same style, with a trailing eye-icon visibility toggle.
- "نسيت كلمة السر؟" (Forgot password) link, label-large, primary color,
  trailing-aligned (right under RTL).
- Filled-primary button "تسجيل الدخول" (Log in), full-width, 48dp tall.
- A subtle divider with the text "أو" (or) centered.
- Outlined button "إنشاء حساب جديد" (Create new account), full-width, 48dp
  tall, secondary color border.
- At the bottom safe area: a tiny labelMedium link to "شروط الاستخدام" /
  "سياسة الخصوصية" separated by ·, in onSurfaceVariant.

Show:
1. Default state.
2. Error state — phone field outlined in error color with helper text "رقم
   الهاتف غير صحيح".
3. Loading state — primary button shows a spinner instead of text, button is
   disabled.
```

### Screen 4 — Register

```
Generate a registration screen.

Layout:
- AppBar with leading back arrow + title "إنشاء حساب" (Create account),
  titleLarge.
- Phone field with +963 prefix.
- Password field + confirm-password field.
- Optional email field labeled "بريد إلكتروني (اختياري)" — a helper text below
  in onSurfaceVariant: "يلزم لاستعادة كلمة السر فقط."
- Optional full-name field "الاسم الكامل (اختياري)".
- Checkbox "أوافق على شروط الاستخدام وسياسة الخصوصية" — required to enable
  the submit button.
- Filled-primary submit button "إنشاء الحساب".
- Below the button: "عندك حساب؟ سجّل الدخول" with the "سجّل الدخول" portion
  styled as a primary-color link.

Show two states: empty default, and one with all fields filled and a green
checkmark next to the password field indicating valid strength.
```

### Screen 5 — Pending approval

```
Generate a "pending account approval" screen.

Layout:
- Centered, vertical stack.
- A circular illustration (~120dp) showing a stylized hourglass or clock — use
  primary + secondary colors only.
- Headline "بانتظار الموافقة" (Pending approval), headlineMedium.
- Body paragraph (centered, bodyMedium, onSurfaceVariant): "حسابك قيد المراجعة
  من قبل الإدارة. عادةً تستغرق العملية أقل من 24 ساعة. سنرسل لك إشعاراً
  بمجرد الموافقة."
- A muted secondary button "تواصل مع الدعم" (Contact support) — opens
  WhatsApp / phone.
- A text-only link "تسجيل الخروج" (Log out) at the bottom in error color.
- No bottom navigation bar — this screen is gated and locks navigation.
```

### Screen 6 — Home (anonymous + authenticated)

```
Generate a home screen — the marketplace landing page.

Layout, top to bottom:
- AppBar (collapsing): brand "النجوم" leading-aligned in headlineMedium primary
  color; trailing icons: search 🔍 and a profile/avatar circle. AppBar
  background = surface, no elevation when at top, elevation 1 once scrolled.
- Hero search affordance: a large "ما الذي تبحث عنه؟" (What are you looking
  for?) input that looks like a search bar but is in fact a tap-to-go-to-search
  affordance. Trailing inside the field: a filter icon.
- A horizontal row of property-type shortcuts as pill chips with an icon +
  label: شقة (Apartment) 🏢, محل (Shop) 🛍️, أرض (Land) 🌳, فيلا (Villa) 🏡,
  مستودع (Warehouse) 📦. Scrollable.
- A small banner ad slot (placement: home_top_banner) — Direction A: a soft
  cream banner with gold border; Direction B: a clean white banner with
  primary-blue accent strip. Show "إعلان" (Ad) label in the corner.
- Section header: "أحدث العروض" (Latest listings), titleLarge, primary color.
  Trailing "عرض الكل" (View all) link.
- A vertical list (not grid) of 3 listing cards. Card anatomy:
    Direction A: photo top-full-bleed (4:3), gold "مميّز" (Featured) corner
      ribbon if featured. Below photo: title (titleLarge serif),
      price-primary (e.g. "$120,000") in primary color titleMedium,
      price-secondary "≈ 1,560,000,000 ل.س" in tertiary onSurfaceVariant
      bodyMedium. Then a row of metadata icons: 🛏 3 · 🛁 2 · 📐 145 m² ·
      📍 المالكي، دمشق. Card padding lg.
    Direction B: photo on the leading side (40% width, 16:10), content on
      trailing side. Title (titleMedium sans), price-primary in primary blue
      bold, price-secondary muted, metadata in a wrap row of small chips,
      tertiary-orange "جديد" (New) badge if posted < 24h. Card padding md.
- Bottom navigation bar with 4 items: الرئيسية (Home, active), البحث (Search),
  المفضلة (Favorites), حسابي (Account). Icons + labels. Active item uses
  primary color; inactive uses onSurfaceVariant.

Show: 1. populated default; 2. empty-state (no listings yet) with a friendly
illustration + "كن أول من يضيف عرضاً" CTA; 3. loading skeleton state.
```

### Screen 7 — Listing details

```
Generate a listing-details screen.

Layout, top to bottom:
- A photo gallery taking ~45% of screen height. Pageable horizontally, with
  bottom-overlaid page indicator (3/12 style) and a small expand-to-fullscreen
  icon.
- Floating top action bar overlaid on the gallery: leading back arrow,
  trailing favorite ❤ icon, share ↗ icon, report ⚠ icon. Background: 60%
  surface color with blur (frosted).
- Sticky title section: title (Direction A: headlineMedium serif; Direction B:
  titleLarge sans). Below: price-primary in primary color displayMedium / 
  headlineMedium, price-secondary muted underneath.
- Status row: a featured badge (gold ribbon for A, orange chip for B if
  featured), a "جديد" new chip if recent, the listing date "نُشر قبل 3 أيام".
- Quick-facts row of 4 stat cards: Bedrooms 3 / Bathrooms 2 / Area 145 m² /
  Floor 4. Each card uses surfaceVariant background. Direction A: lg radius,
  generous padding. Direction B: md radius, tight padding.
- Description section header "الوصف" with body text. Truncate at 4 lines with
  "اقرأ المزيد" (Read more) link.
- Location section: a map preview (16:9, rounded corners) with a marker pin.
  Below: address text. Tap → Phase 15 map.
- Agency block (if listing is published under an agency): an avatar,
  agency name, "موثّق" (Verified) badge if verified, and "زيارة الصفحة"
  (Visit page) trailing link.
- Contact CTAs row, sticky at bottom of scroll: three full-width buttons in
  a row — اتصال (Call) primary filled, واتساب (WhatsApp) secondary filled
  (success-green for both directions, with WhatsApp icon), استفسار (Inquiry)
  outlined.

Show: 1. default. 2. with the "Inquiry" sheet expanded (modal bottom sheet
with name + phone + message form).
```

### Screen 8 — Search + filter sheet

```
Generate a search-results screen with a filter bottom sheet open over it.

Background screen layout:
- AppBar: leading back arrow, persistent search input (text "شقّة في دمشق")
  with trailing clear-X icon and filter icon.
- Result count + sort row: "127 عرض" leading, sort dropdown trailing
  ("الأحدث" / Newest, "السعر: من الأرخص" / Price low→high, etc.).
- Active filter chips row (horizontal scroll): "شقة ×", "دمشق ×", "$50K-200K
  ×", "3+ غرف ×". Each chip has a small × to remove.
- Listing cards (same component as home), scrollable.

Filter bottom sheet (overlaid, ~70% screen height):
- Drag handle at top.
- Title "تصفية النتائج" + leading "إعادة" (Reset) link in error color.
- Section: نوع العرض (Purpose) — segmented control: للبيع / للإيجار.
- Section: نوع العقار (Type) — wrap of pill chips: شقة, محل, فيلا, أرض,
  مستودع. Multi-select.
- Section: الموقع (Location) — three cascading dropdowns: محافظة, مدينة, منطقة.
- Section: السعر (Price) — currency toggle (USD / SYP) + a min-max slider with
  two thumbs.
- Section: المواصفات (Specs) — wrap of stepper inputs: غرف 0-5+, حمّامات
  0-3+, مساحة min-max.
- Sticky footer: "تطبيق (127)" filled-primary button, full-width, 48dp tall.

Show: 1. sheet open with all filters in default (showing 1,840 results).
2. sheet open with several filters applied (showing 127 results).
```

### Screen 9 — Map view

```
Generate a map view screen.

Layout:
- Full-bleed OpenStreetMap tile background (use a generic light-gray map tile
  for the mockup — Damascus area; you can render the streets schematically).
- Floating search input pinned to top with safe-area inset, content "ابحث في
  المنطقة" + filter icon. Surface background, elevation 2.
- Marker pins for ~12 listings. Direction A: drop-shaped pins in primary navy
  with gold dot center. Direction B: square rounded pins in primary blue with
  a price label "$95K" inside. Cluster pins where overlapping (show a "+12"
  cluster).
- A bottom-sheet listing-preview: peeks ~120dp from bottom, draggable to full
  height. Peek state shows a single listing card horizontally with photo
  thumbnail leading, title + price + metadata trailing. Drag up reveals
  vertical list of all visible-area listings.
- Floating action button (FAB), trailing-bottom, primary color: a "تحديد
  موقعي" (Locate me) icon.
- Bottom-left attribution chip: "© OpenStreetMap" (this is a license
  requirement and must be visible).

Show: 1. default with peek sheet. 2. expanded sheet showing 8 listings in
a list. 3. zoom-in state where pins are individual (no clusters).
```

### Screen 10 — Listing creation form (multi-step)

```
Generate a multi-step listing-creation form. Render 3 of the 7 steps as
separate frames so the layout pattern is clear.

Common chrome (top of every step):
- AppBar: leading × close (with a confirm-discard dialog), title "إضافة عرض
  جديد" (New listing), no trailing.
- Step indicator below AppBar: 7 dots with a connecting line; the current
  step is filled primary, completed steps are filled secondary, future are
  outline. Current step label "الأساسيات (1/7)".

Step 1 — Basics:
- Section header "البيانات الأساسية".
- Fields: العنوان (Title) text field; نوع العرض (Purpose) segmented
  control بيع/إيجار; نوع العقار (Type) dropdown.
- Sticky footer: outlined "السابق" (Previous) — disabled on step 1; filled
  "التالي" (Next).

Step 4 — Prices:
- Section header "الأسعار".
- Currency selector tabs (USD / SYP).
- Primary price field (large) with currency suffix.
- A "أضف عملة أخرى" (Add another currency) link that adds a secondary price
  field.
- Toggle: "السعر قابل للتفاوض" (Negotiable).
- Validators visible: "السعر يجب أن يكون أكبر من 0" if invalid.

Step 6 — Media:
- Section header "الصور والفيديو".
- A grid of image slots (up to 10), 3 columns. Empty slots show a + add icon
  + outlined dashed border. Filled slots show the photo with a top-trailing
  × delete and a bottom "تعيين كصورة رئيسية" (Set as main) toggle on the
  first one. The main image gets a small "رئيسية" badge.
- Below: "فيديو" section with a single "إضافة رابط فيديو" (Add video link)
  field + an "أو ارفع من الجهاز (≤30MB)" upload slot.

Show all three step frames side by side.
```

### Screen 11 — Profile + settings

```
Generate a profile + settings screen.

Layout, top to bottom:
- AppBar with title "حسابي" (My account).
- Profile card at top: a circular avatar (~80dp), name, phone, account-status
  pill chip ("معتمد" Approved / "قيد المراجعة" Pending). A small "تعديل"
  (Edit) trailing link.
- Stats row: 3 mini-cards — عروضي (My listings) 12, المفضلة (Favorites) 24,
  الاستفسارات (Inquiries) 5.
- Settings list (each row 56dp tall, leading icon, title, trailing chevron):
  - عروضي / My listings
  - المفضلة / Favorites
  - الاستفسارات / Inquiries (publisher inbox)
  - وكالتي / My agency (if applicable)
  - --- divider ---
  - اللغة / Language → "العربية" trailing
  - المظهر / Theme → "النظام" / "فاتح" / "داكن"
  - العملة المفضلة / Preferred currency → "$" / "ل.س"
  - --- divider ---
  - الإشعارات / Notifications
  - الخصوصية / Privacy
  - الدعم / Support
  - --- divider ---
  - تسجيل الخروج / Log out (in error color)
- Bottom: app version label labelMedium, onSurfaceVariant.
```

### Screen 12 — Favorites + empty states

```
Generate a favorites screen with two states.

State 1 — Populated:
- AppBar title "المفضلة" (Favorites), trailing edit/select icon.
- A vertical list of listing cards (same component as home). Each card has
  a filled heart in error color trailing-top corner (tap to unfavorite).
- An optional sort dropdown above the list: "حسب الإضافة" (By added date) /
  "حسب السعر" (By price).

State 2 — Empty:
- Centered illustration (~120dp) of a heart outline with a small house icon
  inside.
- Headline "لا توجد مفضلات بعد" (No favorites yet), titleLarge.
- Body "اضغط على أيقونة القلب في أي عرض لإضافته هنا." bodyMedium,
  onSurfaceVariant.
- Filled-primary button "تصفّح العروض" (Browse listings) → goes to Home.

Show both states side by side.
```

### Screen 13 — Palette Tester (utility component, not a real screen)

```
Generate a Figma component called "PaletteTester" that lives in the top-leading
corner of every full-screen frame. It is a design-review utility — never seen
by end users — used by the team to compare two primary-color palettes live on
real screens.

Component anatomy (32 dp tall pill):
- Container: card-color background, 1 px border (border token), pill radius
  (999), 12 dp horizontal padding, 6 dp vertical padding, elevation 2.
- Leading (RTL leading = right): a 12 dp circular swatch dot filled with the
  active primary color.
- Center: labelMedium text showing the palette name — either "Modern" or
  "Trust" — in textPrimary.
- Trailing: a 16 dp "repeat-2" / cycle icon in textSecondary.

Two component variants (use Figma Variants):
- Variant 1: palette = Modern. Swatch fill #1D4ED8. Label "Modern".
- Variant 2: palette = Trust.  Swatch fill #2457A6. Label "Trust".

Wiring:
- Create a Figma Variable named `palette` of type STRING with two values:
  "Modern" and "Trust". Bind every fill in your design that previously used
  the primary color to a token expression that reads from `palette` (Modern →
  #1D4ED8, Trust → #2457A6). Bind onPrimary, primaryContainer, and accent the
  same way using the values listed in screens-and-components.md § 2.1.
- Add an interaction to the PaletteTester component: "On click → Set Variable
  `palette` = (next value in cycle)". This makes every primary-colored
  element on the frame flip between the two palettes on click in prototype
  preview mode.

Placement on every screen frame:
- Top-leading corner, inset 16 dp from leading edge, inset 16 dp below the
  status bar.
- Floats above all content. Marked as "design tools — strip before export".

Output:
- The PaletteTester component itself (both variants visible side by side).
- A demonstration: take the Home screen frame (Screen 6 in this prompt pack)
  and render it twice — once with PaletteTester showing Modern, once showing
  Trust — so a reviewer can see exactly what each palette does to the same
  layout.
```

---

## 5. Component sheet prompt (paste into Magician for Figma or any component-aware tool)

```
Generate a single-frame design-system canvas (1440×2400 dp) that exhibits
every primitive component we'll build. Render it twice: once with Direction A
tokens, once with Direction B tokens. Use the BASE CONTEXT BLOCK and the
appropriate TOKEN BLOCK above.

Components to render, grouped by section:

A. BUTTONS (a 4×3 grid)
- Filled primary, filled secondary, outlined, text — each in default,
  hovered/pressed, and disabled states.
- Two sizes: regular (48dp tall) and dense (36dp tall).
- One full-width filled-primary at the bottom of the section.

B. INPUTS
- Text field: empty / focused / filled / error / disabled.
- Phone field with country-code prefix dropdown.
- Password field with eye toggle.
- Search bar with leading icon + clear-X.
- Dropdown / select.
- Stepper (− value +).

C. CARDS
- Listing card (matches the home screen card spec).
- Stat card (icon + number + label).
- Agency card (avatar + name + verified badge + trailing CTA).
- Empty-state card (illustration + headline + body + CTA).

D. CHIPS & BADGES
- Filter chip default + selected.
- Status chips: pending (warning), approved (success), rejected (error),
  draft (outline).
- "جديد" (New) badge — tertiary color.
- "مميّز" (Featured) corner ribbon — secondary color (gold for A,
  orange for B).

E. NAVIGATION
- Bottom nav bar with 4 items.
- AppBar variants: default, with-search, with-back, transparent-on-image.
- Tab bar (segmented control) — 2 segments and 3 segments.

F. FEEDBACK
- Snackbar: info (primary), success, error, warning. Each with action.
- Inline alert / banner — same four variants.
- Loading skeleton for a listing card.
- Toast / dialog (modal): title + body + two-button footer.

G. TYPOGRAPHY SAMPLES
- A column of every type style with both Latin and Arabic text:
  displayLarge "AlNujom النجوم", displayMedium, headlineLarge "Damascus
  دمشق", headlineMedium, titleLarge, titleMedium, bodyLarge with a paragraph,
  bodyMedium with a paragraph, labelLarge, labelMedium.

H. COLOR SWATCHES
- A swatch grid of every color token, light theme on top row, dark theme on
  bottom row. Each swatch shows the hex value as a labelMedium overlay.

Label every component with its name. Lay out the canvas in a 2-column flow
with section headers as displayMedium. Annotate with arrows for any
non-obvious interaction (e.g., "tap to expand", "long-press to remove").
```

---

## 6. Comparison checklist (use after both A and B canvases exist)

Run through this list for each of the 12 screens before deciding:

- [ ] **Brand fit** — which direction looks more like the AlNujom brand you want to build? Curated boutique (A) or efficient marketplace (B)?
- [ ] **Listing scan** — open the home screen for both directions. Which one makes it easier to compare 5 listings at a glance? B usually wins on density; A wins on hero photography.
- [ ] **Search affordance** — open the search-results screen. In which direction is the filter chip row clearer? In which one are price filters more obvious?
- [ ] **Arabic typography** — pick a longer Arabic heading (e.g., a real listing title). Which font pairing reads more naturally to a Syrian user — Reem Kufi (A) or Cairo (B)?
- [ ] **Photography weight** — listing details: in which direction does the photo gallery feel like the hero, and in which does it feel like one element among many? A treats photos as hero; B treats them as data.
- [ ] **Density vs. whitespace** — flick through the listing-creation form steps. A's generous padding makes long forms calmer; B's tighter density makes them shorter to scroll.
- [ ] **Dark theme honesty** — open the dark variant of any screen. Does it look intentional or like an afterthought? (Both A and B have proper dark palettes — verify your chosen direction holds up.)
- [ ] **Map markers** — does the marker style read clearly at thumbnail scale? B's price-label markers carry more info per pixel; A's gold-dot pins look more refined at the cost of legibility.
- [ ] **48dp touch targets** — check the bottom-nav, the contact CTAs, and the filter chips. Both directions should hit ≥ 48dp; if A's "calm whitespace" makes any control look smaller than 48dp, that's a render mistake to flag.
- [ ] **Production cost** — A requires sourcing Playfair Display + Reem Kufi font assets and re-coloring all stub tokens. B reuses the existing stub primary `#2457A6` and surface colors — cheaper to land in Phase 2.

After this pass, write the chosen direction + rationale into the **Decision** block at the bottom of `decision.md` and tell me. I'll archive the rejected direction, cut the `002-design-system` branch, and run `/speckit-specify`.

---

## 7. After you decide — Figma MCP integration

When you've picked, you can stand up Figma MCP so I read your finished comps directly:

1. Install the Figma MCP server (e.g., `figma-developer-mcp` or the official Figma Dev Mode MCP) following its README.
2. Add it to `.mcp.json` at the repo root with your Figma personal access token.
3. Run `/mcp` in Claude Code to verify the connection.
4. From spec 002 onward, when I'm building widgets, I'll request the Figma frame URL and read the design tokens / component anatomy directly from your file.

The Figma MCP step is **after** the decision — there's no point wiring it before there's a chosen design to read.
