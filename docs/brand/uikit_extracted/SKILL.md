---
name: alnujom-design
description: Use this skill to generate well-branded interfaces and assets for Al Nujom (النجوم), the Arabic-first, RTL real-estate marketplace for Syria — for production or throwaway prototypes/mocks. Contains the brand's design guidelines, color directions, type, fonts, logo assets, reusable components, and a four-screen mobile UI kit.
user-invocable: true
---

# Al Nujom Design System — Skill

Al Nujom (**النجوم**, "The Stars") is an Arabic-first, **RTL** real-estate app for Syria.
Trust is the product: verified agencies, real photos, clear prices in **$** and **ل.س**,
and a direct **WhatsApp** contact path.

Read **README.md** for the full guide (sources, content fundamentals, visual foundations,
iconography), then explore the other files:

- `styles.css` → link this; it `@import`s all tokens.
- `tokens/` → fonts (Tajawal + Playfair), colors (brand constants + 4 theme scopes),
  type, spacing.
- `foundations/` → specimen cards for color / type / spacing / brand.
- `components/` → reusable React primitives (Button, Badge, Chip, Field, PropertyCard,
  BottomNav) with `.d.ts` + `.prompt.md`.
- `ui_kit/alnujom_app/` → the four-screen clickable app (Home · Listing · Search · Add).
- `assets/brand/` → logo (full + mark).

## How to use

- **Pick a direction.** Apply one theme scope to a screen root: `.theme-premium`
  (cream/gold), `.theme-airy` (white/teal), `.theme-dark` (navy/blue glow), or
  `.theme-bold` (navy/orange). Every semantic token retones automatically.
- **Stay Arabic-first.** `dir="rtl"`, Tajawal for UI, Playfair for Latin/premium display.
  Use directional CSS (`inset-inline-*`, `margin-inline-*`). Numbers read LTR inside RTL.
- **Use the brand constants** (stars-blue, coral, verified-green, WhatsApp-green, gold) for
  the logo and trust signals regardless of direction.
- **Icons = Lucide.** Load from CDN and call `lucide.createIcons()` after render. No emoji
  in product chrome.

If creating visual artifacts (slides, mocks, throwaway prototypes), copy assets out and
produce static HTML files for the user to view. For production code, copy assets and read
the rules here to design as an expert in this brand.

If invoked without other guidance, ask what the user wants to build, ask a few questions,
then act as an expert designer who outputs HTML artifacts **or** production code.
