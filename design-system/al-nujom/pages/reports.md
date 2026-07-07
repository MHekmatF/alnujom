# Reports Page Overrides

> **PROJECT:** Al Nujom
> **Generated:** 2026-07-07 07:42:55
> **Page Type:** Blog / Article

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/MASTER.md`).
> Only deviations from the Master are documented here. For all other rules, refer to the Master.

---

## Page-Specific Rules

### Layout Overrides

- **Max Width:** 1200px (standard)
- **Layout:** Full-width sections, centered content
- **Sections:** 1. Hero (Value Prop + Form), 2. Recent Issues/Archives, 3. Social Proof (Subscriber count), 4. About Author

### Spacing Overrides

- No overrides — use Master spacing

### Typography Overrides

- No overrides — use Master typography

### Color Overrides

- **Strategy:** Minimalist. Paper-like background. Text focus. Accent color for Subscribe.

### Component Overrides

- Avoid: No feedback after submit
- Avoid: Placeholder-only inputs
- Avoid: Overflow or broken layout

---

## Page-Specific Components

- No unique components for this page

---

## Recommendations

- Effects: transform: translateY(scroll), position: fixed/sticky, perspective: 1px, scroll-triggered animations
- Forms: Show loading then success/error state
- Accessibility: Use label with for attribute or wrap input
- Content: Truncate with ellipsis and expand option
- CTA Placement: Hero inline form + Sticky header form
