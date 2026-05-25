# Phase 15 — Map View: Success Criteria Matrix

**Verification date**: 2026-05-24 (initial) + 2026-05-25 (Pixel 8 Pro AVD walks: user + orchestrator)
**Branch**: `worktree-agent-afa866be767dc4de1` (based on `015-map-view` @ `0616b11`); supplementary AVD evidence on `015-map-view` HEAD
**Verifier**: Phase 8 (Polish & Verification) agent — T076; supplementary AVD walks captured 2026-05-25

Legend:
- `[VERIFIED]` — confirmed by grep gate, wire-level SQL, code review, or static analysis
- `[VERIFIED — AVD]` — confirmed via Pixel 8 Pro AVD walk (2026-05-25); still PARTIAL on primary device per memory `feedback_strict_task_completion.md` until Infinix Note 8 walk confirms
- `[PARTIAL — device]` — requires Infinix Note 8 (primary QA device); not yet walked
- `[PARTIAL — AVD]` — requires Pixel 8 Pro AVD; AVD unavailable in orchestrator environment

---

| SC | Status | Evidence / Gap |
|----|--------|----------------|
| SC-001 | [VERIFIED — AVD] | User walked on Pixel 8 Pro AVD 2026-05-25: home tile tap → map opens Syria-wide; OSM tiles render. Still PARTIAL on Infinix Note 8 (gap §D-T073). |
| SC-002 | [VERIFIED] | Wire-level SQL: `SELECT COUNT(*) FROM v_listings_map_public` = 6; `search_map()` = 6. Marker coords correct per visibility tier — 4a/4b/4c all return 0. Code review confirms `map_jitter_coordinates` SQL function plus passthrough for `exact`. |
| SC-003 | [VERIFIED] | Wire-level SQL gates all pass: 4a `leak_count=0` (hidden/admin_only excluded), 4b `non_approved_count=0` (status gate works), 4c `approximate_leak_count=0` (jitter applied). Zero client-side visibility filter confirmed by T068 grep gate (0 matches). |
| SC-004 | [VERIFIED — AVD] | User walked on Pixel 8 Pro AVD 2026-05-25: marker tap → popover appears with image+title+price+badge. Still PARTIAL on Infinix Note 8 (gap §D-T073). |
| SC-005 | [VERIFIED — AVD] | User walked on Pixel 8 Pro AVD 2026-05-25: popover tap → listing details → back → map restored. Route-scoped `MapBloc` preserves state per R-77. Still PARTIAL on Infinix Note 8 (gap §D-T073). |
| SC-006 | [VERIFIED — AVD] | Orchestrator walked on Pixel 8 Pro AVD 2026-05-25 via adb input: cluster of 6 tap → auto-zoom + split into 1 marker + cluster of 5; tap cluster of 5 → split into 5 individual approximate markers. `zoomToBoundsOnClick: true` from R-93 confirmed working. Spiderfy at max zoom not testable with current test data (no co-located markers in 6-row dataset). Still PARTIAL on Infinix Note 8 (gap §D-T073). |
| SC-007 | [VERIFIED — AVD light/ar] | Orchestrator walked on Pixel 8 Pro AVD 2026-05-25 (light theme + Arabic locale): "© مساهمو OpenStreetMap" attribution visible bottom-end of map. PARTIAL for (light/en), (dark/ar), (dark/en) — not walked this session. Gap in §D-T073 + new §D-T075-followup. |
| SC-008 | [VERIFIED — AVD light/ar] | Orchestrator walked on Pixel 8 Pro AVD 2026-05-25 (light theme + Arabic locale): MapPage chrome (AppBar with RTL-flipped back-arrow + title + refresh; OSM attribution; FAB; cluster badges; marker pins; approximate marker halo) all render correctly. PARTIAL for the other 3 combos. Gap in §D-T073 + new §D-T075-followup. |
| SC-009 | [VERIFIED] | T067 grep gate: `Select-String -Pattern "google_maps|mapbox|apple_maps" -Path pubspec.yaml pubspec.lock` → 0 matches. OSM + `flutter_map` confirmed in pubspec.yaml. FR-019 fully satisfied. |
| SC-010 | [VERIFIED] | Wire-level SQL T074: BEFORE=6, SET `location_visibility='hidden'` on `5a58a9e8-09a9-4ab5-ae32-b63eddd2d0d7` → AFTER=5, RESTORE → RESTORED=6. View WHERE gate removes row immediately on visibility change. In-app `MapRefreshButton` re-fetch = PARTIAL — device; gap in §D-T074. |
| SC-011 | [VERIFIED] | Wire-level: `v_listings_map_public` is a public view with `SECURITY INVOKER` and RLS-free (no auth-dependent WHERE clause beyond the status/visibility/publish-window gates). Count is identical regardless of role. View definition cross-checked in migration `20260526120002_create_v_listings_map_public.sql`. |
| SC-012 | [VERIFIED — AVD] | User walked on Pixel 8 Pro AVD 2026-05-25: apply ≥2 filters → "Show on map" → restricted marker set + filter-active alert. Still PARTIAL on Infinix Note 8 (gap §D-T073). |
| SC-013 | [VERIFIED — AVD] | User walked on Pixel 8 Pro AVD 2026-05-25: `FilterActiveAlertDialog` appears with chip summary + Reset/Keep actions; Reset path reloads unfiltered set. Show-once gating + barrier-tap-dismisses-cleanly (Wave 3 audit fix) working. Still PARTIAL on Infinix Note 8 (gap §D-T073). |
| SC-014 | [VERIFIED — AVD] | User walked on Pixel 8 Pro AVD 2026-05-25 (grant path): first FAB tap → Android runtime prompt → grant → camera pans to device location. Orchestrator confirmed system prompt fires on first tap 2026-05-25. Still PARTIAL on Infinix Note 8 (gap §D-T057). |
| SC-015 | [PARTIAL — device + AVD-followup] | Orchestrator confirmed on Pixel 8 Pro AVD 2026-05-25: system permission dialog appears on first FAB tap with permissions revoked. Deny-path snackbar text not visually captured (adb-driven taps drifted; snackbar 4s display window closed before precise screencap). Permanently-denied "Open settings" snackbar not walked. Code: `isPermanentlyDenied` path dispatches `GeolocationPermissionPermanentlyDenied`; `!isGranted` dispatches `GeolocationPermissionDenied`. Gap in §D-T057 + new §D-T075-followup. |

---

## Summary

**6/15 strictly VERIFIED** (SC-002, SC-003, SC-009, SC-010 wire-level, SC-011 + RPC parity)
**8/15 VERIFIED — AVD** (SC-001, SC-004, SC-005, SC-006, SC-007 light/ar, SC-008 light/ar, SC-012, SC-013, SC-014 grant-path) — Pixel 8 Pro AVD walk 2026-05-25; **still PARTIAL on Infinix Note 8** (primary QA device) until walked there
**1/15 PARTIAL — device + AVD-followup** (SC-015 — system prompt verified; deny + permanent-deny snackbar text not visually captured)

> All PARTIAL items require the Infinix Note 8 primary QA device (or Pixel 8 Pro AVD for §D-T075
> supplementary check). The device was not available in the orchestrator worktree environment.
> Static analysis (`flutter analyze --fatal-infos`), build verification (`flutter build apk --debug`),
> and all 6 grep gates are clean. Wire-level SQL confirms SC-002, SC-003, SC-009, SC-010, SC-011.
> Deferred items are captured in `DEFERRED.md` §D-T073, §D-T074 (in-app portion), §D-T075.
