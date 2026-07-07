# Favorites Page Overrides

> **PROJECT:** Al Nujom
> **Generated:** 2026-07-07 07:35:17
> **Page Type:** Search Results

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/MASTER.md`).
> Only deviations from the Master are documented here. For all other rules, refer to the Master.

---

## Page-Specific Rules

### Layout Overrides

- **Max Width:** 1200px (standard)
- **Layout:** Full-width sections, centered content
- **Sections:** 1. Hero (problem state), 2. Transformation slider/comparison, 3. How it works, 4. Results CTA

### Spacing Overrides

- No overrides — use Master spacing

### Typography Overrides

- No overrides — use Master typography

### Color Overrides

- **Strategy:** Contrast: muted/grey (before) vs vibrant/colorful (after). Success green for results.

### Component Overrides

- Avoid: Blank empty screens
- Avoid: No visual feedback on current location
- Avoid: Static URLs for dynamic content

---

## Page-Specific Components

- No unique components for this page

---

## Recommendations

- Effects: Tonal elevation (overlay colors instead of strong shadows), pill-shaped buttons and chips (borderRadius 999), emphasized easing Easing.bezier(0.2,0,0,1), state layers (pressed overlays 10–15% opacity), Reanimated-filled label float for inputs, HapticFeedback on FAB/toggles
- Feedback: Show helpful message and action
- Navigation: Highlight active nav item with color/underline
- Navigation: Update URL on state/view changes
- CTA Placement: After transformation reveal + Bottom
