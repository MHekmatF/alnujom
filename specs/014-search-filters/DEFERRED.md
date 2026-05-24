# DEFERRED Work: Phase 14 — Search & Filters

**Branch**: `014-search-filters`
**Created**: 2026-05-24

---

## D-001 — Extract `DeepLinkAwareBackButton` widget

**Deferral reason**: Phase 13 R-71 forward-stated that `DeepLinkAwareBackButton` at `lib/core/widgets/deep_link_aware_back_button.dart` should be extracted when a second consumer is added. Phase 14 (`SearchPage`) is that second consumer, but the inline `Navigator.canPop(context) ? BackButton() : IconButton(home, ...)` pattern is implemented directly in `search_page.dart` per the team's preference (documented in `contracts/phase14-filter-state-persistence.md §DeepLinkAwareBackButton`). The extraction adds no user-visible value in v1.

**Where deferred**: `lib/core/widgets/deep_link_aware_back_button.dart` — NOT created in Phase 14.

**Trigger for action**: When a third consumer (e.g., Phase 15 `MapPage` or Phase 16 `InquiryPage`) adds the same inline back-button pattern, extract the widget in that phase's PR and migrate all existing consumers (`ListingDetailsPage`, `SearchPage`, and the new page) in the same PR.

**Upstream references**: `CLAUDE.md` cross-cutting notes; `contracts/phase14-filter-state-persistence.md §DeepLinkAwareBackButton`; Phase 13 R-71.
