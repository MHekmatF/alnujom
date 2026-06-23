# Al Nujom — Visual Identity Playbook

> A build-order guide + paste-ready prompts for the full brand identity.
> Decisions locked with the founder (2026-06-16):
> - **Logo:** explore *refined* (keep equity) **and** *fresh* concepts, then compare.
> - **Master color:** **blue-led, but a modern & creative blue** (not the old navy `#13507D`).
> - **Personality:** **Premium / upscale + Modern / tech-forward.**
> - **Scope:** everything — logo system, app icon/splash, social kit, print, website.

Brand: **Al Nujom** (النجوم — "The Stars"), a premium Syrian real-estate
marketing platform. Arabic-first (RTL), bilingual ar/en. The product (Flutter
app + Supabase) already exists and ships with a token-based theme — this
identity feeds **into** that theme; we don't rebuild the app.

---

## 0. The two non-negotiable rules

1. **Never let an AI image model render Arabic.** They mangle connected
   letterforms. Generate the *icon* + any *English* with AI; typeset **النجوم**
   yourself in a real Arabic font in Figma and place it.
2. **The final logo must be vector (SVG/PDF).** AI gives raster PNGs. Plan to
   re-create the chosen concept as vector (Recraft exports SVG, or trace in
   Figma/Illustrator) before it touches a sign or the app icon.

---

## 1. Foundation

### 1.1 Color system — "Steel & Star" (grey + blue)
Evolves the heritage palette (royal blue + grey + white from the old cards) into
a premium, modern, tech-forward system: a confident royal blue as the energy,
cool **graphite/steel greys** as the sophisticated neutral (the "architectural /
concrete" real-estate feel), deep navy as the dark anchor, gold kept *only* for
the Featured signal.

| Role | Name | Hex | Use |
|---|---|---|---|
| Anchor (dark) | Ink Navy | `#0E1A2E` | dark surfaces, hero/premium backgrounds, headings |
| **Primary** | **Nujom Blue** | `#1F4FE6` | buttons, links, active states, price, icons (AA ✓ on white) |
| Highlight | Sky Spark | `#4D8DFF` | active glow, the star "twinkle", gradients — **never as text** |
| Neutral (dark) | Graphite | `#39414F` | secondary text, dark UI elements |
| Neutral (mid) | Steel | `#9AA4B2` | the silver star-crown, muted text, dividers |
| Neutral (light) | Mist | `#E6E9EF` | hairlines, borders |
| Surface (light) | Cloud Grey | `#F2F4F8` | app/site background |
| Card (light) | White | `#FFFFFF` | cards, sheets |
| Surface (dark) | Deep Space | `#0B1322` | dark background |
| Card (dark) | Slate | `#16203A` | dark cards |
| Ink | Ink | `#0E1A2E` / `#475569` / `#7A8597` | heading / secondary / muted |
| Premium | Gold | `#CBA24E` | Featured/مميّز badge — **fill behind dark ink, never text** |
| Trust | Verified Green | `#1F7A4D` | verification |
| Trust | WhatsApp | `#1DAB61` | WhatsApp CTAs |
| Favorite | Coral | `#F4795B` | favourite heart |

**Signature look (the "creative" part):** the **N in royal blue**, the
**star-crown in brushed steel/silver**, on white or Ink Navy — with a subtle
steel→blue gradient for premium surfaces (splash, hero, premium cards). Grey
carries the upscale/architectural feel; blue carries trust + energy.

> Locked direction. The exact blue may nudge slightly once the logo is final;
> then I realign the app tokens to match (see §8).

### 1.2 Typography (proposed)
| Slot | Latin | Arabic |
|---|---|---|
| Display / headings | **Space Grotesk** (geometric, tech-forward) | **Readex Pro** or **Tajawal** (modern, premium) |
| Body / UI | **Inter** (already in app) | **IBM Plex Sans Arabic** (already in app) |

Premium feel comes from **weight + letter-spacing + whitespace**, not a serif
(serif-Arabic is impractical). Changing the *app's* fonts is optional and
heavier than a recolor — flag if you want it.

### 1.3 The star motif system
Define once, reuse everywhere: a single five-point star (the logo's), a sparse
**star-field** texture for dark backgrounds, and a "twinkle" cyan accent. This
single motif is what makes cards, social, splash, and signage feel like one
family.

### 1.4 Photography direction
Real Damascus/Aleppo/Levantine architecture, warm natural light, clean and
uncluttered, shot slightly wide. Avoid generic Western stock. Every shared
listing photo gets the brand frame (§5).

---

## 2. Logo system

### What we actually need (a *set*, not one file)
- Primary lockup (icon + النجوم wordmark + EN tagline "Al Nujoom Real Estate Marketing")
- Horizontal lockup, Stacked lockup
- **Icon-only** (app icon, avatar, favicon)
- Wordmark-only
- Monochrome (solid black, solid white/reversed)
- On-navy and on-white versions
- Clear-space + minimum-size rules + a "don'ts" sheet

### Step A — Mood board (Nano Banana Pro)
> Create a 3×3 mood board for a **premium, tech-forward Syrian real-estate**
> brand called *Al Nujom* ("The Stars"). Show: modern Damascus/Levantine
> architecture in warm light, a clean minimal real-estate app UI, elegant
> signage, a subtle five-point star motif, and a palette of deep navy + royal
> blue + electric cyan + a touch of gold. Editorial, high-end, photographic. No
> text, no logos — atmosphere only. 16:9.

### LOCKED concept — evolve the heritage emblem
The old logo already has the DNA: a **circular emblem**, a **crown of ~13 stars**,
a central monogram, "ALNUJOM" beneath, in **blue + grey**. We modernize it:
- center monogram → the **letter N creatively formed from modern building towers**;
- crown of **~13 five-point stars** in brushed **steel/silver**;
- N in **royal blue `#1F4FE6`**; clean, premium, minimal.

We produce **two executions** from the same idea:
- **(A) Emblem** — circular badge with the star-crown → for cards, signage, stamps.
- **(B) Icon-only monogram** — the N-of-buildings alone (one tiny star) → for the
  app icon, favicon, avatar (the emblem's tiny stars vanish at small sizes).

### Step B — main emblem (Nano Banana Pro / Recraft)
> Design a **premium, modern logo emblem** for a high-end real-estate company.
> Concept: a **circular emblem** — in the center the **letter N creatively formed
> from sleek modern building towers** (a small skyline that reads as an N); a
> **crown of about 13 small five-point stars arcing around the top** inside the
> ring. Style: refined, premium, **minimal flat vector**, balanced negative
> space — NOT busy. Colors: the **N in royal blue `#1F4FE6`**, the **stars and
> ring in brushed steel/silver-grey `#9AA4B2`**, on white; deep navy `#0E1A2E`
> for depth. Sophisticated, architectural, trustworthy. Transparent background.
> **6 polished, simple variations** on a clean grid. **No text, no Arabic.** Avoid
> clutter, circuit/tech lines, gradients-as-noise.

### Step C — icon-only monogram (Nano Banana Pro / Recraft)
> Design a **minimal app-icon mark**: just the **letter N formed from modern
> building towers**, with **one small five-point star** as a spark at the top.
> Ultra-clean geometric flat vector, lots of negative space, readable at 48px.
> Royal blue `#1F4FE6` + steel-grey `#9AA4B2` on transparent. **6 simple
> variations** on a grid. No circle, no crown of stars, no text — keep it bold
> and simple.

### Step E — Vectorize the winner (Recraft, or Figma/Illustrator)
> Recreate this logomark as a clean **vector / SVG** in flat style — exact
> shapes, crisp paths, solid fills. Colors: blue `#1F4FE6`, cyan `#4D8DFF`, gold
> `#CBA24E`, navy `#0E1A2E`. Provide on transparent background.

Then in Figma: place the vector icon, set **النجوم** in Readex Pro/Tajawal, add
the EN tagline, and export the full variation set.

### How to choose (scoring rubric, 1–5 each)
Recognizable at 24px · works in 1 color · unique vs other SY real-estate brands ·
feels premium **and** modern · pairs cleanly with Arabic wordmark · no awkward
negative space. Put the refined winner next to the two fresh winners and score.

---

## 3. App icon + splash (I implement these in the app)

### Icon concept (Nano Banana Pro, then vectorize)
> Create a 1024×1024 **app icon** for Al Nujom: the icon-only logomark centered
> on a **deep-navy `#0E1A2E`** background with a subtle blue→cyan radial glow;
> the mark in white/blue with a cyan star spark. Keep all critical elements
> within the **centre 80% (maskable safe zone)**. Bold, premium, high-contrast,
> still readable at 48px.

### Splash concept
> A mobile splash screen, deep-navy `#0E1A2E` with a soft blue→cyan vertical
> gradient and a faint star-field; the logo centered, small EN tagline beneath.
> Provide a **light** variant (cloud `#F2F4F8` background, blue mark) too.

**Then I do the code:** drop the assets in `assets/branding/`, regenerate via
`flutter_launcher_icons` + `flutter_native_splash` (light + dark), verify on the
AVD. No design tool needed for this step — just the final art.

---

## 4. Business cards + print

### Business card (Figma Make)
> Design a **double-sided premium business card, 90×55mm with 3mm bleed**, for
> *Al Nujom Real Estate Marketing*. **Front:** deep-navy `#0E1A2E` with a subtle
> blue→cyan gradient + faint star-field; centered logo + EN/AR tagline.
> **Back:** white, bilingual (Arabic right-aligned / English left-aligned): name,
> title, phone, WhatsApp, email, website, office address, and a small QR to the
> app/website; royal-blue `#1F4FE6` accents + a fine gold `#CBA24E` rule. Type:
> Space Grotesk + Readex Pro. Minimal, upscale, generous whitespace. CMYK,
> print-ready.

### Also in the print set (same prompt pattern, swap the spec)
- **Letterhead** (A4, logo top, contact footer, subtle star-field watermark).
- **Yard / property sign** ("للبيع / للإيجار" + logo + phone + QR, high-contrast, readable from the street).
- **Email signature** (HTML, logo + name + contact + social icons).
- **Stamp / watermark** for documents.

### Detail I need from you for print (see §9).

---

## 5. Social media kit

### Profile avatar (Nano Banana / Figma)
> Icon-only logomark centered on deep-navy `#0E1A2E` with a blue→cyan glow,
> circular safe area, 1000×1000. Crisp at 64px.

### Listing post template — **the most valuable asset** (Figma Make)
> Design a **1080×1080 Instagram/Facebook listing post template** for a premium
> real-estate brand. Top 70% = property photo placeholder; bottom = a frosted
> navy bar with: price chip (royal-blue `#1F4FE6`), location, key specs
> (beds/baths/area icons), a gold `#CBA24E` "مميّز/Featured" badge slot, and the
> logo. Bilingual-ready, RTL Arabic. Provide **3 status variants**: للبيع (sale),
> للإيجار (rent), تم البيع/SOLD overlay. Clean, premium, editorial.

### Story template (Figma Make)
> 1080×1920 story version of the listing template with a swipe-up/"التفاصيل في
> التطبيق" CTA and the blue→cyan gradient + star-field.

### Listing-photo FRAME / watermark (Figma Make) — stamp on photos before sharing
> A reusable **branded frame overlay** for property photos: a thin royal-blue
> border, a logo lockup in one corner, a semi-transparent price/location chip,
> and a small gold Featured star — exported as a transparent PNG template to
> drop over any listing photo. Keep it subtle so the property stays the hero.

### Facebook/cover + highlight icons (Canva Pro or Figma)
Cover 820×312, story-highlight circle icons (a star, a key, a building, a
verified badge) in the brand line style.

---

## 6. Website / landing page

### Design (Claude Design — outputs HTML/Tailwind)
> Design a modern, **premium, tech-forward landing page** for *Al Nujom*, a
> Syrian real-estate marketing platform. **Arabic-first RTL**, with an EN toggle.
> Sections: sticky nav (logo + language toggle + "افتح التطبيق" CTA); hero
> (headline + a search bar + a phone mockup of the app, on a navy→cyan gradient
> with a faint star-field); trust strip (verified listings · cities covered ·
> publishers); featured-listings grid (cards with a gold "مميّز" badge);
> how-it-works (3 steps); a "للناشرين/for agents" CTA band; app-download section
> (store badges + QR); footer (links, contact, socials). Palette: navy
> `#0E1A2E`, blue `#1F4FE6`, cyan `#4D8DFF`, gold `#CBA24E`, cloud `#F2F4F8`
> surfaces. Type: Space Grotesk + Readex Pro. Responsive, lots of whitespace,
> subtle scroll motion. Output clean semantic HTML + Tailwind.

### Build (Antigravity)
Hand the Claude-Design HTML to Antigravity and prompt:
> Build this landing page as a production site: [framework — e.g. Next.js +
> Tailwind], fully responsive, RTL-correct, accessible (AA), with the EN/AR
> toggle wired, store-badge + QR links, and an SEO/OpenGraph head. Deploy-ready.

### Supporting web assets
- **Favicon** (16/32/180px) — from the icon-only mark.
- **OpenGraph share image** (1200×630): logo + tagline on navy→cyan, star-field.

---

## 7. Brand guidelines PDF (assemble in Figma)
Cover · brand story + personality · logo system (variations, clear space, min
size, **don'ts**) · color (with hex/RGB/CMYK) · typography · the star motif ·
iconography · photography do/don't · application mockups (app, card, post, site,
sign) · contact. Export as PDF — this is what keeps everyone consistent.

---

## 8. App-side work I execute (the only code part)
The app currently ships a **teal** accent (we set it before this blue decision).
Once the logo's exact blue is locked, I will:
1. Retune `lib/core/theme/color_palette.dart` + `elevation.dart` from teal →
   the **Steel & Star** grey+blue system above (light + dark), keeping the
   token discipline (linter green) and AA contrast.
2. Drop the final logo art into the app and regenerate **app icon + splash**
   (light + dark) via `flutter_launcher_icons` / `flutter_native_splash`.
3. Verify on the Pixel 8 Pro AVD across light/dark × ar/en, then PR + squash-merge.

I can do step 1 as an **immediate preview** (so the app reflects the blue
direction now, reversible) even before the logo is final — just say the word.

---

## 9. Project facts (locked) + heritage reference

**Name & contact (locked):**
- Name: **النجوم للتسويق العقاري** (AR) / **Alnujom Real Estate** (EN). No tagline.
- Mockups use **2 dummy phone numbers + a dummy QR code** for now (swap real later).
- **Print scope: ALL** — business card, yard sign (للبيع/للإيجار), car branding,
  office sign, roll-up banner.
- **Agent cards: 1** (owner only).

**Heritage reference (from the old cards — for continuity, not for copying):**
- Old emblem = blue + grey + white, circular, ~13-star crown over a house/roof
  monogram, "ALNUJOM" banner. → we modernize this (see §2 LOCKED concept).
- Old Arabic name was **النجوم للعقارات**; cardholder **باسل العلي / Basel Al Ali**.
- Real contact on file (Aleppo: بستان الباشا، خلف نادي العروبة / حريتان، الطريق
  الرئيسي حلب–غازي عنتاب; phones 0964847378, 0955248245, 0944283105) — use when we
  switch off dummy data.

**Still open (nice-to-have, not blocking):**
- WhatsApp number, email, website domain, social handles.
- Final logo **source file** (we'll create vector ourselves regardless).
- Website: marketing landing only, or fuller site? (default: landing first.)
