# Product

## Register

product

## Users
Arabic-first users in Syria on Android phones: everyday **buyers and renters** browsing property, and **real-estate agencies / owners** who publish and manage listings. They're often on the go, on mid-range devices and variable networks, making high-stakes decisions where **trust and verification matter** (is this listing real? is this agency legit?). Admins/super-admins moderate, approve accounts and listings, and manage the catalog.

## Product Purpose
A real-estate marketplace that connects verified agencies and owners with buyers and renters across Syria. Users browse, search, filter, and map listings, then inquire; publishers create and manage listings through an approval workflow; admins moderate. Success = users **trust** what they see, find the right property quickly, and reach out with confidence.

## Brand Personality
**Trustworthy, clear, warm.** The voice is calm, helpful, and direct — never salesy or loud. It should feel like a credible, well-run marketplace that also feels human and welcoming. Emotional goal: **confidence + ease** (you can rely on this, and it's pleasant to use).

## Anti-references
- **Generic / templated** — must not look like stock Material/Bootstrap defaults; it should feel crafted.
- **Cluttered / dense** — no cramming; breathing room and clear hierarchy over packed screens.
- Loud/flashy gradients, neon, glassmorphism, over-animation.
- Cold / sterile / clinical-corporate.

## Design Principles
1. **Trust is the product.** Verification, honest pricing, clear states, and credible structure come first — every screen should feel reliable.
2. **Photos lead, data supports.** Photo-forward listing cards (Airbnb/VRBO) with crisp, scannable supporting data (Zillow). Let imagery do the selling.
3. **Breathing room over density.** Generous spacing and strong hierarchy; never cluttered.
4. **Arabic-first, equal in both.** RTL and Arabic typography are first-class, not retrofitted; light and dark are both intentional.
5. **Familiar, done well.** Standard affordances executed with craft (earned familiarity), not invented strangeness.

## Accessibility & Inclusion
WCAG **AA** contrast (body ≥ 4.5:1; enforced by `test/core/theme/color_scheme_contrast_test.dart`). Full **RTL + Arabic** localization (no English-only strings; `lint_l10n_*` enforced). Comfortable tap targets, `prefers-reduced-motion` honored, color never the sole signal. Mid-range Android performance is a constraint.
