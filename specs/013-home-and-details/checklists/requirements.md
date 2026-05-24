# Specification Quality Checklist: Public Home & Listing Details

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-23
**Last validated**: 2026-05-23 (post-`/speckit-clarify` — 6 clarifications resolved across two passes: Q1-Q3 during `/speckit-specify`, Q4-Q6 during `/speckit-clarify`)
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

> Note on content quality: This spec follows the Phase 10 / 11 / 12 precedent of citing specific database object names, Edge Function paths, file paths, and table column names. Downstream spec-kit workflow (`research.md`, `data-model.md`, `contracts/`) consumes these names verbatim. User-value framing is preserved at the User Story layer.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain *(6 questions resolved in-session on 2026-05-23 as Q1=A, Q2=A, Q3=A, Q4=D, Q5=A, Q6=A)*
- [x] Requirements are testable and unambiguous *(all FRs reference SQL queries, file paths, grep checks, or visual checks)*
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic *(SC items reference observable outcomes — SQL row counts, grep results, manual UI checks, stopwatch times, dependency manifest entries — verifiable via the established SQL + manual-device verification surface)*
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded *(Scope note demarcates Phase 13 from Phases 10, 11, 12, 14, 15, 16, 17, 22, 23, 24)*
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification *(same caveat as Content Quality — DB object names + file paths cited follow Phase 10/11/12 precedent)*

## Clarifications Log

**Session 2026-05-23 (during `/speckit-specify`) — RESOLVED**:

- **Q1 = A** — Hero search + property-type shortcut stub behavior: visible + tappable; each surfaces a localized "Coming soon" snackbar (`home_search_coming_soon` for the bar, `home_property_shortcut_coming_soon` parameterized over the tapped property type). No navigation in Phase 13. Phase 14 swaps the tap-handlers from "show snackbar" to "navigate to search". FR-013 + SC-029 capture.
- **Q2 = A** — Contact / favorite / share / report CTA scope: ALL six CTAs uniform Coming-soon snackbar stubs in Phase 13. Phase 16 wires the three Contact CTAs + the lead-event analytics; later phases wire favorite + report; the share-wiring phase introduces `share_plus`. `url_launcher` IS still introduced per FR-027 for video-tap playback only (NOT for `tel:` / `wa.me/`). `share_plus` is NOT introduced in Phase 13. FR-021 + FR-032 + FR-033 + SC-030 capture.
- **Q3 = A** — Anonymous-tap behavior on auth-required CTAs: localized "Please sign in to use this feature" snackbar with a "Sign in" action button routing to the Phase 5 login page. Under Q2=A, this has NO Phase-13 user-visible behavior. Q3=A is captured AS a FORWARD-STATE PROJECT-WIDE CONVENTION for every later-phase auth-required CTA. The ARB keys `auth_required_please_sign_in` and `auth_required_sign_in_action` are reserved in Phase 13's ARB delta per FR-028 for the first future-phase consumer. SC-031 captures.

**Session 2026-05-23 (during `/speckit-clarify`) — RESOLVED**:

- **Q4 = D** — `ListingDetailsPage` back-arrow conditional behavior on deep-link entry: `if (Navigator.canPop()) Navigator.pop(); else context.go(AppRoutes.home)`. Preserves in-app navigation history when present (future Phase 14 search results, etc.); falls back to HomePage when back-stack empty (deep-link entry case). Implemented in both the AppBar back IconButton AND the `PopScope` / `WillPopScope` wrapper for Android system back. Forward-state convention for every later-phase deep-link-targetable page. FR-021 + SC-033 capture.
- **Q5 = A** — Steady-state interaction latency budget: ≤ 2 seconds p95 for HomePage infinite-scroll next-page load AND pull-to-refresh, measured at the device on Syrian-realistic network conditions. Aligns with Phase 12 Q6=A's Edge Function budget (same backend + network leg). Budget covers gesture-to-text-appearance; image bytes fill progressively and are excluded. FR-016 + SC-034 capture. Plan-time mitigations (thinned projection, materialized view, dedicated tier) reserved if budget is breached repeatedly.
- **Q6 = A** — HomePage background→foreground resume posture: NO auto-refresh on resume; user pulls-to-refresh manually. Cached `HomeBloc` state (cursor + loaded card list + scroll position) preserved across background/foreground transitions. No `AppLifecycleState` observer, no time-based threshold, no passive freshness badge. Consistent with the existing Realtime-deferred / pull-based freshness folded default. Phase 22 (Realtime + push) is the future attachment point for live freshness. New Edge Case bullet + SC-035 capture.

## Notes

- The spec is ready for `/speckit-plan` — both `/speckit-specify` and `/speckit-clarify` quotas are exhausted (3 + 3 = 6 questions across the two passes; the project's Phase 12 precedent went to 8 across the same two passes, so Phase 13's 6 is within the conventional range).
- Q1=A, Q2=A, Q3=A, Q4=D, Q5=A, Q6=A resolutions chose the most conservative + project-consistent stub treatment for each surface, narrowing Phase 13's blast radius to exactly the read-side + the index migration + the router rewire + the five-widget composition + the deep-link-aware back navigation + the latency budget + the explicit no-auto-refresh resume posture.
- Total spec growth from `/speckit-specify` → `/speckit-clarify`: 3 new clarification bullets (Q4-Q6); 1 amended FR (FR-016 + Q5 budget; FR-021 + Q4 conditional back-arrow); 1 new Edge Case (deep-link back entry); 3 new SCs (SC-033, SC-034, SC-035); 1 reworded Clarifications section narrative.
- The spec follows the Phase 10 / 11 / 12 depth + bilateral-traceability convention between FRs and SCs.

## Coverage Summary (post-`/speckit-clarify`)

| Taxonomy Category | Status | Notes |
|---|---|---|
| Functional Scope & Behavior | Resolved | 6 user stories cover anonymous + auth browsing, RLS verification, pagination, design compliance. Scope note demarcates from Phases 10/11/12/14/15/16/17/22/23/24. |
| Domain & Data Model | Resolved | New entities `HomeListingCard` + `Cursor` defined. Existing entities reused. Cursor wire format deferred to plan-time research (legitimate implementation detail). |
| Interaction & UX Flow | Resolved | Q1 (search/shortcut stubs), Q2 (CTA scope), Q3 (auth-required), Q4 (deep-link back), Q6 (resume freshness) — all UX boundaries pinned. |
| Non-Functional Quality Attributes | Resolved | Performance: SC-001 cold-launch + SC-004 card-tap + Q5=A steady-state budget. Reliability: Retry buttons on network failure. Observability: explicitly deferred to Phase 24. Security: RLS-only filter. |
| Integration & External Dependencies | Resolved | `url_launcher` narrowed per FR-032. `share_plus` deferred per Q2=A / FR-033. Supabase storage + PostgREST patterns clear. |
| Edge Cases & Failure Handling | Resolved | 20+ edge cases including deep-link entry (new per Q4=D), background resume (new per Q6=A), network failure, stale data, status flip mid-browse. |
| Constraints & Tradeoffs | Resolved | Every Q1-Q6 captured the rejected alternatives + rationale. |
| Terminology & Consistency | Clear | Canonical terms ("approved listing", "home feed", "details page", "Q8=A widgets") used consistently. |
| Completion Signals | Resolved | 35 SCs are testable. Manual UI verification per `feedback_no_new_tests.md`. |
| Misc / Placeholders | Clear | Remaining "plan-time-codifies" markers are legitimate implementation details, not spec ambiguities. |

**Next command**: `/speckit-plan` (no further `/speckit-clarify` pass needed; both quotas exhausted and coverage is Resolved across all categories).
