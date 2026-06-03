# Phase 24 — DEFERRED items

Items that surfaced during Phase QV (T038 structural gate + verify suite) but
are intentionally out of scope for this PR. Each entry has a one-line rationale
per the `project_deferred_work` memory convention.

---

## Pre-existing lint baseline (not introduced by Phase 24)

### design-token violations (3) — `features/agency` + `features/admin/agencies`

Files:
- `lib/features/admin/agencies/presentation/pages/agency_detail_page.dart:325,354` — inline `TextStyle`
- `lib/features/agency/presentation/pages/agency_members_page.dart:96` — raw `EdgeInsetsDirectional`

**Rationale**: These violations pre-date Phase 24 (agency feature, prior specs).
Fixing them is a cosmetic refactor with no functional impact; deferred to a
future "design-token sweep" spec to keep Phase 24 focused on the release gate.

### l10n-literals violations (9) — `features/agency`

Files: `agency_analytics_page.dart`, `agency_listings_page.dart`,
`agency_profile_page.dart`, `agency_verification_page.dart`.

**Rationale**: All in the agency presentation layer, pre-dating Phase 24.
Deferred to a future l10n-cleanup spec; no user-visible regression introduced.

---

## On-device / operator-dependent tasks (cannot be automated here)

| Task | Rationale |
|------|-----------|
| T032 — integration test green (AVD + seeded backend) | Needs AVD + provisioned backend; test is written (T031 DONE) |
| T033 — six manual golden-path walks | Needs physical device (Infinix Note 8) + AVD |
| T034 — APK binary secret-scan | Needs the signed release APK (keystore not in repo) |
| T035 — cold-start baseline measurement | Needs physical Infinix Note 8 |
| T037 — distribution ops (Supabase Storage + Telegram + Play Store) | Operator step |
| T039 — Phase 22 carried-over QA residual (T044/T045/T046) | Needs two-device setup + real user JWT |

---

## Future spec items (explicitly out of Phase 24 scope)

| Item | Rationale |
|------|-----------|
| Phase 19 FE-1 — agency suspend/remove cascade choice | Deliberately deferred; left as future spec per R-215 |
| In-place/silent auto-update | Phase 24 ships a manual-download prompt; silent update is a v2 spec |
| Force / minimum-supported-version gate | Not required for v1.0.0 launch; future spec |
| Crash-reporting opt-out toggle | Forward-stated future work per spec.md clarification; automatic capture ships in v1.0.0 |
| Automating the remaining 5 golden paths | One automated test relaxation per `feedback_no_new_tests`; full automation is a future spec |
