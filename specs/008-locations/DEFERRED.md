# Phase 8 — Deferred Work

Six items were intentionally deferred or surfaced during Phase 8 implementation. Each entry notes the deferred scope, rationale, and proposed follow-up target.

**Status (2026-05-17):** T072, T083, T090, T095, T100, and T101 manual walks were completed on Pixel 8 Pro emulator + Infinix Note 8 + Chrome (super-admin). All Phase 8 success criteria were verified except those requiring the full `quickstart.md` Steps 1–12 sweep (T102), which remains outstanding.

---

## 1. Full quickstart end-to-end recipe (T102)

**Deferred scope:** T102 — Full `quickstart.md` Steps 1–12 end-to-end verification recipe against the remote Supabase project (the per-FR / per-SC verification map at the bottom of `quickstart.md`).

**Rationale:** The 12-step quickstart is broader than the per-story device walks (T083/T090/T095/T100/T101 all done) and overlaps substantially with the verified scope. Outstanding bits are the Step 12 cross-FR sweep + the success-criteria final tick-down.

**Proposed follow-up:** Human reviewer runs T102 as the final pre-squash-merge gate.

---

## 2. LocationPicker public API gaps — initialSelection, required, areaRequired (Findings 1–3)

**Deferred scope:** `LocationPicker`'s constructor declares three parameters — `initialSelection`, `required` (field-level validation), and `areaRequired` — that are accepted but silently ignored in the current implementation. The `onChanged` callback fires correctly; the ignored parameters affect:
- Pre-population from an existing location selection (e.g., editing a listing that already has a city/area).
- Form-validation blocking submit when a governorate/city is required but not yet chosen.
- Whether an area selection is mandatory vs. optional in the containing form.

**Rationale:** No Phase 8 consumer uses these parameters. The spec's own contract (`contracts/location-picker-widget.md`) defines them for Phase 13's listing form, not for the Phase 8 admin pages. Implementing them now without a live consumer would be speculative and untestable.

**Proposed follow-up:** Phase 13 (Listing creation form). The Phase 13 spec MUST implement:
1. `initialSelection` — mount the bloc with a `SelectionPreloaded` event that sets initial dropdown values from the pre-existing `governorateId`/`cityId`/`areaId`.
2. `required` — expose a `SelectionRequiredFailure` state that the parent form can check before submit.
3. `areaRequired` — add an `areaRequired` flag to the bloc that blocks `SelectionCommitted` until area is non-null.
4. Clear-area affordance — when governorate or city changes mid-edit, the downstream selections must be cleared and `onChanged(null)` fired.

---

## 3. Smoke-test page — dev-only throwaway surface (T099 / R-21)

**Deferred scope:** `LocationPickerSmokeTestPage` at `/dev/locations-picker` is a development-only verification scaffold. It has a hardcoded English title, no ARB key, and is gated by `kDebugMode` so it never ships in release builds. It serves Phase 8's manual SC-011/SC-012/SC-015 walk but has no production use.

**Rationale:** R-21 explicitly defers the "admin-side picker preview" to Phase 13. The smoke-test page fulfils R-21's Phase 8 obligation as a dev-only surface. Removing or replacing it is Phase 13's responsibility.

**Proposed follow-up:** Phase 13 (Listing creation form). When the LocationPicker is embedded in the listing form, the smoke-test page should be removed (or kept behind `kDebugMode` if still useful during Phase 13 development). Decision at Phase 13 authoring time.

---

## 4. Lat/lng columns on cities and areas (Clarifications Q1)

**Deferred scope:** `cities` and `areas` tables have no `latitude`/`longitude` columns in Phase 8.

**Rationale:** Closed as a deliberate Phase 8 non-goal. Clarifications Q1 + R-10 record this decision: Phase 8 ships the hierarchical catalog only; Phase 15 (Map view) MAY add `latitude`/`longitude` via a non-breaking `ALTER TABLE ... ADD COLUMN` migration if real demand emerges.

**Proposed follow-up:** Phase 15 spec. If map coordinates are needed earlier (e.g., Phase 13 listing geo-tagging), a follow-up migration can be authored independently without touching Phase 8 artifacts.

---

## 5. ProfileCubit "emit after close" warning (Phase 5 pre-existing)

**Deferred scope:** Surfaced during Phase 8 device walk on the emulator: `ProfileCubit.load()` at `lib/features/profile/presentation/cubit/profile_cubit.dart:37` emits a new state after the cubit has been closed by navigation away from `/profile`. Logged as an unhandled exception (`Bad state: Cannot emit new states after calling close`) but does not crash the app — navigation continues normally.

**Rationale:** Pre-existing Phase 5 bug, unrelated to Phase 8 scope. The fix is a single guard: `if (isClosed) return;` after each `await` in `ProfileCubit.load()` before the subsequent `emit(...)`. Out of scope for Phase 8.

**Proposed follow-up:** Track as a Phase 5 polish item (or fold into Phase 11's broader cubit/bloc hygiene pass). Not blocking for Phase 8 squash-merge.

---

## 6. PermissionChecker app-resume refresh (Phase 22 forward-stated)

**Deferred scope:** During Walk 5 SC-021 verification, the admin's Locations tile did not disappear on pure background → foreground resume; the user had to back-navigate and re-open admin home for the rebuild to recheck `PermissionChecker.has(...)`. The spec ("no sign-out required") was met — navigation suffices — but pure app-lifecycle resume does not currently force a PermissionChecker cache refresh.

**Rationale:** Phase 6 established the three-point cache-refresh strategy (sign-in, route push to `/admin`, etc.). App-lifecycle resume isn't one of those points. Phase 22 (Push + Realtime, per project memory `project_phase22_perm_cache_revisit.md`) is the planned home for adding a Realtime subscription on `user_roles` that propagates permission deltas to every device instantly — at which point the resume-refresh question becomes moot.

**Proposed follow-up:** Phase 22 spec. Add a Realtime subscription on `user_roles` (or extend the cache-refresh trigger set to include `WidgetsBinding.lifecycleState == AppLifecycleState.resumed`). Document the decision in Phase 22's research.md alongside the existing three-point strategy.
