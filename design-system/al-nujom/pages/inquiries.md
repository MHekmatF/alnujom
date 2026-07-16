# Inquiries Page Overrides

> **PROJECT:** Al Nujom
> **Generated:** 2026-07-07 07:42:03
> **Page Type:** Product Detail

> ⚠️ **IMPORTANT:** Rules in this file **override** the Master file (`design-system/MASTER.md`).
> Only deviations from the Master are documented here. For all other rules, refer to the Master.

---

## Page-Specific Rules

### Layout Overrides

- **Max Width:** 1400px or full-width
- **Grid:** 12-column grid for data flexibility
- **Sections:** 1. Hero, 2. Bento Grid (Key Features), 3. Detail Cards, 4. Tech Specs, 5. CTA

### Spacing Overrides

- **Content Density:** High — optimize for information display

### Typography Overrides

- No overrides — use Master typography

### Color Overrides

- **Strategy:** Card backgrounds: #F5F5F7 or Glass. Icons: Vibrant brand colors. Text: Dark.

### Component Overrides

- Avoid: Visual-only error indication
- Avoid: Silent success
- Avoid: Toasts that never disappear

---

## Page-Specific Components

- No unique components for this page

---

## Recommendations

- Effects: Drill-down expand animations, breadcrumb click transitions, smooth detail reveal, level change smooth, data reload animation
- Accessibility: Use aria-live or role=alert for errors
- Feedback: Brief success message
- Feedback: Auto-dismiss after 3-5 seconds
- CTA Placement: Floating Action Button or Bottom of Grid
