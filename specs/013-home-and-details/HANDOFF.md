# Phase 13 Handoff Notes

Phase 13 (Public Home & Listing Details) is feature-complete from a code perspective. This file captures scope that did NOT make Phase 13 and is needed by downstream phases, plus user-facing verification work that the autonomous loop could not perform.

## Pre-merge user verification still owed (Infinix Note 8)

Per project memory `user_test_device.md`, the Infinix Note 8 is the primary physical device for AlNujom QA. The autonomous /wave loop completed Phase 13 verification on the Pixel 8 Pro emulator only (per R-72 secondary device). The following SCs would benefit from a final pass on the Infinix Note 8 before squash-merge:

| SC | Verification | Notes |
|---|---|---|
| **SC-001** | Cold-launch ≤ 3 sec on Infinix Note 8 | Stopwatch from launcher-tap to first 20 cards rendered. Pixel emulator times don't represent the Syrian-realistic Infinix performance. |
| **SC-024** | 4-combination visual check on Infinix | Pixel-emulator passed 2026-05-24; Infinix repeat would catch any device-specific RTL/font defects. |
| **SC-027** | Video tap → external VLC launch on Infinix | Phase 11's deferred external-player item; needs a real device with VLC installed. |
| **SC-033** | Q4=D deep-link back-button on Infinix | The `adb shell am start` path (or the in-app debug initialLocation route override used during T049 verification) needs to land on the Infinix to confirm back-button works there too. |
| **SC-034** | Q5=A ≤ 2 sec p95 infinite-scroll + pull-to-refresh on Infinix | The 10×10 stopwatch session needs Syrian-realistic 4G + Helio G80 timing. |
| **SC-035** | Q6=A background-resume preserves state on Infinix | Test 1-min + 30-min background intervals. |

**Recommended path**: cherry-pick these onto the PR description as a "user pre-merge gate". If the user signs off after running them, PR ships clean. If any fail, fix in Phase 13 OR capture in a Phase 13.1 follow-up.

## Phase 13.1+ housekeeping follow-ups (from DEFERRED.md)

| ID | Title | Responsible phase |
|---|---|---|
| **D-01** | `AppRoutes.shellHome` alias removal (4 in-tree consumers) | Phase 14 or standalone cleanup |
| **D-02** | ListingDetailsPage publisher attribution (FK gap on `listings.publisher_user_id`) | Phase 5/10 schema follow-up OR Phase 16 inquiry wiring |
| **D-03** | Sign-out routes to `/login` instead of `/` (race between context.go and refreshListenable) | Phase 5 auth-redirect follow-up |
| **D-04** | `ProfileCubit.emit` after close (pre-existing Phase 5 latent bug surfaced by Phase 13 verification) | Phase 5 polish patch |
| **D-05** | Full-scale T051 cursor pagination test deferred (insufficient seed data — 6 approved listings vs 25 needed) | Phase 13.1 follow-up OR Phase 22 verification cycle |

## Cross-phase forward-stated scope (carried from spec.md)

Phase 13 implements its own contract per the active spec; the following items are explicitly forward-stated for downstream specs and require no Phase 13 action:

- **Phase 14 search**: replaces the Q1=A stub hero-search-bar + property-type chips with `/search` route + `tsvector` infrastructure. The Phase 13 indexes (`idx_listings_governorate_status`, `idx_listings_property_type_status`) are pre-positioned for Phase 14 facet filters.
- **Phase 15 map**: ships `/map` route; may add a "View on map" CTA to `ListingDetailsPage` (consumer-of-listing-details concern, not a widget-internal change per Phase 12 Q8=A).
- **Phase 16 inquiry wiring**: replaces the Q2=A-stubbed Call / WhatsApp / Send-inquiry CTAs with `url_launcher` (`tel:` + `https://wa.me/`) + inquiry form + `record_lead_event` Edge Function. Phase 16 MUST adopt the Q3=A forward-state convention (`auth_required_please_sign_in` + `auth_required_sign_in_action` ARB keys — reserved in Phase 13's ARB delta).
- **Phase 22 push + Realtime**: adds Realtime subscription on `public.listings.status='approved'` (overrides Q6=A's no-auto-refresh baseline) + push-notification deep-links landing on `ListingDetailsPage` via `/listings/:id` (exercises Q4=D conditional back-button extensively). Also revisits Phase 6 PermissionChecker cache per project memory `project_phase22_perm_cache_revisit.md`.
- **Phase 24 observability**: may instrument SC-001 / SC-004 / SC-034 / SC-035 cold-launch + interaction-latency metrics for production telemetry.
- **Favorites + reports + share-wiring phases**: each later phase wires its respective Q2=A-stubbed CTA. The share-wiring phase introduces `share_plus` (Phase 13 explicitly excludes it per FR-033).

## Verification-time-only artifacts (revertable / removable)

The following code additions landed during verification and may be worth re-evaluating for v2:

- **`LocaleToggleAction` on HomePage AppBar** (commit `2ae0043`): added to support T063 visual verification (no in-app language switch existed for end users on the public surface). Reuses the already-existing Phase 8 widget. Could stay as permanent UX OR be relocated to a future settings page when Phase 14 ships.
- **Sign-out ListTile on ProfilePage** (commit `5d0a4a5`): added to support T043 verification (Phase 5 UX gap — no logout button for approved+approved publishers). Should stay permanently; addresses a real product gap.
