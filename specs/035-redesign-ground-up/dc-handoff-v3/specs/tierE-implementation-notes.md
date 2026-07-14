# Tier-E Admin — Implementation Notes (DC "Blue Crown")

Status of the admin-console restyle (spec: [`tierE-admin-design.md`](tierE-admin-design.md)).

## Shipped (branch `035-redesign-ground-up`)

All 12 admin screens / ~25 pages moved onto `DcCrownScaffold` (crown header, `arrow_forward`
back leading, brand-header-tinted trailing actions), flat cards, and the shared `DcStatusChip`.
Each commit passed `flutter analyze` + `tool/lint_design_tokens.dart` + l10n parity/literals.

| Commit | Scope |
|---|---|
| `40282d3` | Console (admin home + quick-stats → `DcStatCard`, quick links → `DcQuickLinkTile`) |
| `b91b1e9` | Moderation + system: account approvals, listing review (preview / diff / pending), reports, agencies, audit log, app-settings editor, super-admin roles. Agency `_StatusPill` → `DcStatusChip`. |
| `58558ca` | Content: ads (list + editor), currencies (list / form / set-rate / history), locations (list / governorate / city / form). `ad_status_chip` → `DcStatusChip`. |
| `a34953b` | **Analytics restyle + chart experiment** (see below). |
| `e499f18` | Design handoff source + this spec. |

## Analytics + the chart experiment ⭐

`admin_analytics_page.dart` rebuilt on the crown with:

- **KPI row** — 2×2 `DcStatCard`s from the real series. The month cards carry an **honest
  month-over-month delta** (last vs previous month); the window totals carry none (a single
  window has nothing to compare against — no fabricated trend).
- **Evolution line chart** — a `DcLineChart` shell with **two toggles**:
  - *Series*: الإعلانات ⇄ المستخدمون (both monthly, shared month axis).
  - *Engine*: **أصلي (Native) ⇄ fl_chart** — the same data + styling drawn two ways under one
    shell, so only the renderer differs.
- **Governorate bars** (`DcBarChart`) and a **daily lead trend** (`DcLineChart`), both real data.

### How to pick a chart engine
Open the admin console → analytics. On the "التطوّر عبر الزمن" card, flip the bottom
**أصلي / fl_chart** toggle and compare:

- **أصلي (Native `DcLineChart` / `CustomPaint`)** — zero dependencies, ~120 lines, exact token
  control, cheapest on low-end devices. What every other chart in the app already uses.
- **fl_chart (`FlLineChartPlot`)** — the `fl_chart: ^0.69` package. More features out of the box
  (touch tooltips, animation, gradients) if we want them later; one more dependency.

Both are wired identically (`DcLineChartPlot` vs `FlLineChartPlot`, same `values`). Tell me which
you prefer and I'll make it the default and drop the toggle (and the unused engine, if you want
to shed the dependency). syncfusion / graphic can be added as further candidates on request.

## Deliberate scope calls (not omissions)

- **No custom `DcSwitch`** — the stock `Switch` is already the Material-3 toggle themed by the DC
  `ColorScheme` (primary track). A bespoke one would reimplement it for no visible gain.
- **No donut / heatmap** — the analytics RPCs expose no category-mix or activity-grid series, so
  those two design tiles have no real data. Not fabricated. If we add the backing queries later,
  `DcDonutChart` / `DcHeatmap` slot in against the existing card grid.
- Existing admin row components (e.g. `CurrencyCard`) were already DC-clean (flat `AppSurface`,
  tonal accents, soft pills), so no per-row rebuild was needed — the crown was the real gap.

## Optional further polish (low priority)
Bespoke widgets from the spec that would deepen fidelity but aren't blocking: `DcAdCard`,
`DcLocationTree`, `DcSparkline` (currency rate history), `DcMapPicker` styling. Flag if wanted.
