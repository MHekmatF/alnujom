# Al Nujom — Design System

**النجوم للعقارات · Al Nujoom Real Estate Marketing**

An Arabic-first, **RTL** real-estate marketplace for Syria. Buyers and renters discover
listings; owners and agencies post and manage them. The brand is **النجوم** ("The
Stars") — a deep stars-blue **N** mark ringed by stars, with a building silhouette built
into the letterform. Trust is the product: verified agencies, real photos, clear prices in
both **$** and **ل.س** (Syrian pounds), and a direct **WhatsApp** contact path.

This design system packages the brand's foundations (color, type, spacing, iconography),
a set of reusable React UI primitives, and a four-screen mobile UI kit that explores four
art-directed visual treatments of the same product.

---

## Sources

This system was reverse-engineered from the production codebase and design docs. If you
have access, read deeper:

| Source | Where | What's in it |
|---|---|---|
| **Flutter app** (codebase) | `alnujom-project/` (mounted locally) | Production token system (`lib/core/theme/`), reusable widgets (`lib/core/widgets/`), full Arabic localization (`lib/l10n/app_ar.arb`, 2200+ strings). |
| **UI/UX spec** | `alnujom-project/docs/design/screens-and-components.md` | Authoritative 1000-line spec: every screen, every state, the component library, motion, RTL + a11y checklists. |
| **GitHub** | https://github.com/MHekmatF/alnujom | The same project's repository — explore for deeper component implementations and Arabic copy. |
| **Brand assets** | `alnujom-project/assets/branding/`, `branding/` | Logo (full + mark), splash, app icon. Copied into `assets/brand/`. |

> The production app is **Flutter**, not web. Token values, copy, spacing, radii, motion
> and iconography are ported faithfully. This DS renders them as **CSS + React** for web
> design work.

---

## The four directions

The brief asks for four art-directed treatments of the same app. Each is a CSS theme
scope (`.theme-*`) that retones every semantic token. Apply one to a screen root.

| Direction | Scope | Mood | Surface / Ink / Accent |
|---|---|---|---|
| **Premium** (Home) | `.theme-premium` | Warm, editorial, luxury | cream `#FAF6EF` · brown `#1A1714` · **gold** `#C2A14D` · Playfair headings |
| **Airy** (Listing detail) | `.theme-airy` | Light, calm, spacious | white / `#F5F7FA` · slate `#0F172A` · **teal** `#0EA5A4` |
| **Dark** (Search results) | `.theme-dark` | Crisp, focused, premium-tech | midnight `#0B1020` · `#161C2D` cards · **electric blue** `#3B82F6` glow |
| **Bold** (Add listing) | `.theme-bold` | Confident, high-contrast | navy `#0A1A3F` · `#10245A` inputs · **orange** `#FF6B35` gradient |

The **brand constants** (stars-blue `#13507D`, coral `#F4795B`, verified-green `#1F7A4D`,
WhatsApp-green `#1DAB61`, gold `#C2A14D`) live on `:root` and are theme-independent — use
them for the logo and trust signals regardless of the active direction.

---

## Content fundamentals

**Language.** Arabic-first, **Syrian Levantine register** — natural and warm, never stiff
Modern Standard Arabic. Numbers may be Western Arabic ("85,000,000 ل.س"); currency suffix
**follows** the number.

**Voice.** Confident, professional, calm. Trust over novelty. Photos are the hero on
cards; copy is the hero everywhere else.

- ✅ "ابحث عن شقة، منزل، محل…" (search placeholder — conversational)
- ❌ "البحث عن العقارات الموجودة في النظام" (robotic)
- ✅ "بيتك يبدأ من هنا" (tagline — "Your home starts here")
- ✅ "مرحباً بعودتك" (welcome back), "أنشئ حسابك" (create your account)

**Person.** Addresses the user directly and familiarly (second person, "بيتك" = *your*
home). System messages are reassuring: "بياناتك محمية ولا تُشارك مع أي طرف خارجي."

**Casing / punctuation.** Arabic has no case. Section headers are short noun phrases
("عقارات مميّزة" = Featured properties, "أحدث الإعلانات" = Latest listings). Counts read
naturally: "127 عرض". Step counters "(1/7)". Prices: "85,000,000 ل.س" or "$32,000".

**Standard copy you'll reuse:**

| EN | AR |
|---|---|
| For sale / For rent | للبيع / للإيجار |
| Featured | مميّز |
| Verified | موثّق |
| See all | عرض الكل |
| Contact via WhatsApp | تواصل عبر واتساب |
| Rooms · Baths · Area · Floor | الغرف · الحمّامات · المساحة · الطابق |
| Continue / Next | متابعة / التالي |
| Nav: Home·Search·Add·Favorites·Account | الرئيسية · البحث · إضافة · المفضلة · حسابي |

**Emoji.** Not used in product chrome. The spec uses small unicode/icon glyphs (🛏 🛁 📐)
*illustratively* in docs; in the UI these are **Lucide icons** (`bed`, `bath`, `square`).

---

## Visual foundations

**Color vibe.** Each direction owns one accent and a tightly-controlled neutral ramp.
Premium is warm (cream + gold + brown). Airy is cool and bright (white + slate + teal).
Dark is near-black navy with a single electric-blue that *glows*. Bold is saturated navy
with a hot-orange gradient. Never mix two accents in one screen.

**Imagery.** Real property photography is the hero — warm, well-lit interiors and
exteriors (Unsplash in mocks). Listing cards: **4:3** image, full-bleed within the card.
Details hero: **16:9**, rounded bottom corners. A bottom **scrim gradient**
(`--photo-scrim`) keeps over-photo text/chips legible; never a flat overlay box. Missing
image → a soft `accent-soft` block with the property-type icon centered (never a broken
glyph).

**Typography.** Tajawal across the UI; Playfair Display serif reserved for Premium
headings. Strong size hierarchy (display 34 → label 12). Prices are bold and lead; the
currency suffix is smaller and lighter.

**Spacing & layout.** 4px grid. Screen gutter **16px**. Section header rhythm: **24px**
above, **12px** below. Card inner padding **12–16px**, card-to-card gap **12px**. Fixed
elements: top app bar and bottom nav; sticky CTA bars on detail/form screens.

**Corner radii.** Cards **12px**, buttons **12px** (or pill for chips/filters), sheets &
hero cards **24px**, dialogs **16px**, chips/badges **pill**.

**Borders.** Hairline 1px in `--border`; inputs use `--border-strong`. Light themes lean
on **soft shadows**; the Dark theme uses **crisp 1px borders + a blue glow** ring (shadows
are nearly invisible on near-black). Bold inputs glow orange on focus.

**Shadows.** Three soft, tinted levels (`--shadow-sm/md/lg`) — navy-tinted in light
themes, deep black in dark themes. Cards rest at `sm`; floating bars at `md`; sheets at
`lg`. No harsh or colored drop shadows except the intentional accent **glow** on Dark/Bold.

**Animation.** Subtle and purposeful. Durations 150 / 200 / 250ms, shared easing
`cubic-bezier(.2,.7,.3,1)`. Heart toggle: scale 1→1.3→1 with overshoot + color cross-fade.
Card press: scale to 0.98. Sheets: 240ms ease-out slide-up. Avoid parallax, long hero
animations, or anything > 400ms on a routine action. No infinite decorative loops.

**States.** Hover/press darken or lighten the fill subtly; press also shrinks (scale 0.98).
Disabled = ~50% opacity, no shadow. Active nav item: accent color + a 2px top accent bar.

**Transparency & blur.** Used sparingly — frosted app bar over a hero image (≈60% surface
+ blur), and over-photo chips on a translucent dark base (`--photo-scrim`). Not decorative.

---

## Iconography

- **Library: Lucide** (the production app uses `flutter_lucide`). Keep one library — do
  not mix Material + Lucide + custom. In web mocks, load Lucide from CDN
  (`https://unpkg.com/lucide@latest`) and call `lucide.createIcons()`.
- **Stroke** 2px at 24px. Default size **24px**; inline-with-text **16px**; tab icons
  **24px**. Color = `--ink` by default, `--accent` when active, `--ink-faint` when disabled.
- **Common icons:** `search`, `bell`, `heart`, `share-2`, `phone`, `message-circle`
  (WhatsApp), `map-pin`, `home`, `plus`/`plus-circle`, `user`, `sliders-horizontal`,
  `arrow-up-down`, `bed`, `bath`, `square` (area m²), `badge-check` (verified),
  `chevron-left`/`chevron-right` (RTL-mirrored back arrows).
- **No emoji** in product chrome. Property specs (🛏🛁📐 in spec prose) render as Lucide
  `bed`/`bath`/`square`.
- **Brand mark:** raster logo in `assets/brand/` (`logo-full.png`, `logo-mark.png`). The
  star-ring N is the identity; a single vector mark also exists in the codebase
  (`branding/mark_blue.svg`, `mark_white.svg`) — copied to `assets/source/`.

> ⚠️ **Substitutions to confirm.** (1) **Fonts** — the production app ships *Cairo* +
> *IBM Plex Sans Arabic* + *Inter*; per the brief this DS uses **Tajawal** (Arabic UI) +
> **Playfair Display** (serif). (2) **Icons** are loaded from the Lucide CDN rather than
> vendored. Send the original Cairo/IBM Plex font files if you want pixel-parity with the
> app, and tell me if icons should be vendored locally.

---

## Index

```
styles.css              ← link THIS (manifest of @imports)
tokens/
  fonts.css             Tajawal + Playfair (Google Fonts)
  colors.css            brand constants + 4 theme scopes
  typography.css        families, weights, type scale
  spacing.css           4px grid, radii, device frame, motion
assets/
  brand/                logo-full.png, logo-mark.png
  source/               raw copies from the codebase (svg marks, splash, icon)
foundations/            @dsCard specimen cards — Colors (6) · Type (4) · Spacing (3) · Brand (1)
components/
  core/                 Button · Badge · Chip · Field  (+ core.card.html)
  listing/              PropertyCard  (+ listing.card.html)
  navigation/           BottomNav  (+ navigation.card.html)
ui_kit/alnujom_app/     the four-screen mobile UI kit (index.html + screens.css)
templates/alnujom-app/  consumer-ready starting point (loads the DS via ds-base.js)
SKILL.md                Agent-Skill manifest for download/reuse
```

**Inventory:** 6 components · 18 Design-System cards · 1 template · 147 tokens across the
4 theme scopes. Namespace for `@dsCard` HTML: `window.AlNujomDesignSystem_6d1292`.

See **the Design System tab** for the rendered specimen cards, and
`ui_kit/alnujom_app/index.html` for the interactive four-screen prototype.
