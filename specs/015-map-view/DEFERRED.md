# Phase 15 — Map View: Deferred Items

This file tracks intentional gaps per project memory `project_deferred_work.md`.
A spec is not shippable until all items here are either resolved or explicitly
accepted as post-MVP.

---

## D-T013 — Sub-Phase B smoke test (back-button 4-scenario matrix)

**Task**: T013
**Sub-Phase**: B — DeepLinkAwareBackButton extraction
**Status**: Deferred — device unavailable at worktree commit time

**Gap**: The 4-scenario manual smoke test (deep-link to listing details + back;
card-tap to listing details + back; hero-search to search + back; deep-link to
search + back) could not be run because the Infinix Note 8 (primary QA device
per memory `user_test_device.md`) was not connected during the Sub-Phase B
worktree commit.

**Risk**: Low. The refactor is a pure textual substitution — the extracted
`DeepLinkAwareBackButton` contains the identical `Navigator.canPop(context)`
conditional that was previously inline in both pages. `flutter analyze` is clean.
No behavioral logic was introduced or removed.

**Resolution**: Run the 4-scenario matrix on the Infinix Note 8 during Phase 8
(Polish & Verification, T073+) or when the device is next available. If a
regression is found, fix it and re-open T013 with the corrected behavior before
merging the spec PR.

**Blocker for merge?**: No — this is a verification gap on a zero-logic-change
refactor, not a correctness gap. The Phase 8 checkpoint will catch any regression.
