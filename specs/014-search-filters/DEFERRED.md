# DEFERRED Work: Phase 14 — Search & Filters

**Branch**: `014-search-filters`
**Created**: 2026-05-24

---

## D-001 — Extract `DeepLinkAwareBackButton` widget

**Deferral reason**: Phase 13 R-71 forward-stated that `DeepLinkAwareBackButton` at `lib/core/widgets/deep_link_aware_back_button.dart` should be extracted when a second consumer is added. Phase 14 (`SearchPage`) is that second consumer, but the inline `Navigator.canPop(context) ? BackButton() : IconButton(home, ...)` pattern is implemented directly in `search_page.dart` per the team's preference (documented in `contracts/phase14-filter-state-persistence.md §DeepLinkAwareBackButton`). The extraction adds no user-visible value in v1.

**Where deferred**: `lib/core/widgets/deep_link_aware_back_button.dart` — NOT created in Phase 14.

**Trigger for action**: When a third consumer (e.g., Phase 15 `MapPage` or Phase 16 `InquiryPage`) adds the same inline back-button pattern, extract the widget in that phase's PR and migrate all existing consumers (`ListingDetailsPage`, `SearchPage`, and the new page) in the same PR.

**Upstream references**: `CLAUDE.md` cross-cutting notes; `contracts/phase14-filter-state-persistence.md §DeepLinkAwareBackButton`; Phase 13 R-71.

---

## D-002 — T037 full SC verification on Infinix Note 8

**Deferral reason**: T037 requires verification on Infinix Note 8 (primary QA device). Emulator verification on Pixel_8_Pro AVD (Android API 37) was performed 2026-05-24; 10/11 SCs passed fully. Two gaps remain:
- **SC-001** (Arabic keyword search): tsvector + `search_listings` RPC verified via direct SQL. UI typing of Arabic characters blocked by ADB — `adb shell input text` does not support Unicode. Requires physical device or manual testing session.
- **SC-010** (Pagination): `_PaginationSentinel` + cursor logic implemented; only 1 approved listing in DB. Requires ≥11 listings (page boundary) to verify cursor pagination end-to-end.

**Where deferred**: `specs/014-search-filters/tasks.md T037`

**Trigger for action**: When Infinix Note 8 is available AND DB has ≥11 approved listings, re-run `quickstart.md` steps 5–17 on the physical device, update T037 to `[X]`, and open the end-of-spec PR.

---

## D-003 — TextEditingController not synced from BLoC state

**Deferral reason**: The `_SearchBar` `TextEditingController` only syncs user → BLoC (via `onChanged`), not BLoC → controller. When `SearchFiltersCleared` resets `FilterState.query` to `''`, the text field still shows the old query string. A `BlocListener` updating the controller when `state.filterState.query` diverges from `controller.text` would fix this.

**Where deferred**: `lib/features/search/presentation/pages/search_page.dart` — `_SearchBar._controller`

**Trigger for action**: Phase 15 or first UX bug report where "clear filters" doesn't clear the visible search text.
