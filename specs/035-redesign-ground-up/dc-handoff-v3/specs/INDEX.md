# DC v3 (A–D) handoff — recon index

Reconnaissance of the `handoff (2).zip` Claude-Design batch (Tiers A–D). Source HTML in
`../alnujom-real-estate-marketplace/project/` is ground truth for exact pixel/token values;
these docs are navigation digests + code mappings.

| Tier | Design spec (what it should look like) | Code map (existing files → edits) |
|---|---|---|
| A · Publisher | [tierA-publisher-design.md](tierA-publisher-design.md) | [tierA-publisher-codemap.md](tierA-publisher-codemap.md) |
| B · Agency | [tierB-agency-design.md](tierB-agency-design.md) | [tierB-agency-codemap.md](tierB-agency-codemap.md) |
| C · Features | [tierC-features-design.md](tierC-features-design.md) | [tierC-features-codemap.md](tierC-features-codemap.md) |
| D · Chrome & states | [tierD-chrome-design.md](tierD-chrome-design.md) | [tierD-chrome-codemap.md](tierD-chrome-codemap.md) |

**Shared components to build once:** [components-catalog.md](components-catalog.md) — reconciled
against `lib/core/widgets/` + `lib/core/widgets/ds/`. Most of the kit already exists
(`TokenBarChart`, `StatCard`, `StatusPill`, `RatingStars`, empty/error/loading states,
`AppToggle`, `crown_underline_tabs`) → the batch is mostly **extend + restyle**, not build-from-scratch.

**Charts recommendation (founder wants to compare packages):** all A–D charts are trivial bar/stacked-bar
shapes → stay **native** (extend `TokenBarChart`, token-linter-clean, zero deps). Run the
`fl_chart` vs native experiment at the **Admin (Tier E)** dashboard where richer line/area/donut
charts land and the comparison is meaningful.

**Not in this batch:** Admin / super-admin (Tier E) — separate Claude Design prompt owed to the founder.

**Security note:** two recon agents hit transient prompt-injection noise in their *context* (not in the
handoff files — the design HTML + support.js are clean); the affected design specs were re-run cleanly.
