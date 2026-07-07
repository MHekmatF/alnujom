# Listing Card Page Overrides

> **PROJECT:** Al Nujom
> **Generated:** 2026-07-07 07:35:17
> **Page Type:** Search Results

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/MASTER.md`).
> Only deviations from the Master are documented here. For all other rules, refer to the Master.

---

## Page-Specific Rules

### Layout Overrides

- **Max Width:** 1400px or full-width
- **Grid:** 12-column grid for data flexibility
- **Sections:** 1. Hero (value prop), 2. Feature grid/cards (4-6), 3. Use cases or benefits, 4. Social proof or logos, 5. CTA

### Spacing Overrides

- **Content Density:** High — optimize for information display

### Typography Overrides

- No overrides — use Master typography

### Color Overrides

- **Strategy:** Brand primary + card bg #FAFAFA. Feature icons accent. CTA contrasting.

### Component Overrides

- Avoid: Default keyboard for all inputs
- Avoid: Desktop-first causing mobile issues
- Avoid: Default mobile tap handling

---

## Page-Specific Components

- No unique components for this page

---

## Recommendations

- Effects: Hover scale (1.02), soft shadow expansion, smooth layout shifts, content reveal
- Forms: Use inputmode attribute
- Responsive: Start with mobile styles then add breakpoints
- Touch: Use touch-action CSS or fastclick
- CTA Placement: Hero (sticky) + After features + Bottom
