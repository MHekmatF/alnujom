# Phase 8 — Deferred Work

Four items were intentionally deferred during Phase 8 implementation. Each entry notes the deferred scope, rationale, and proposed follow-up target.

---

## 1. Manual device verification walks (T095, T100, T101, T102)

**Deferred scope:**
- T095 — US5 Area CRUD UI walk on Infinix Note 8 (add/edit/delete area; confirm seeded Mezzeh exposes Delete; audit SQL).
- T100 — US6 LocationPicker smoke-test walk (cascade 14 governorates; SC-015 deactivation test; locale toggle).
- T101 — Cross-device rename propagation (SC-007, SC-021, mid-session permission revoke). Requires a second physical device.
- T102 — Full `quickstart.md` Steps 1–12 end-to-end verification recipe against the remote Supabase project.

**Rationale:** Device walks require physical hardware and cannot be performed by an LLM agent. T101 additionally requires two simultaneous devices. All four tasks are explicitly marked `[HUMAN-ONLY]` or equivalent in tasks.md and the spec.

**Proposed follow-up:** Human reviewer runs T095 + T100 + T102 as part of PR review (before squash-merge). T101 can be run if a second device is available; it is optional for merge but MUST be verified before Phase 13 ships the LocationPicker as a production component.

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
