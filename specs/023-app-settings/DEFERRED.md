# DEFERRED — Phase 23 (App Settings)

Intentional gaps left at end-of-spec. Each is either an on-device verification the
orchestrator cannot run, or forward-stated future work explicitly OUT of Phase 23 scope.
Check this file before claiming the spec is fully shipped.

## A. On-device QA (code complete + analyzed; device walk pending)

All implementation is merged and `flutter analyze --fatal-infos` is clean; what remains is
the physical-device / two-device behavioural verification, which the orchestrator cannot run.
Wire-level and structural checks that *could* be run from the orchestrator were run (see T029/T031).

| Task | What's done | What's deferred |
|---|---|---|
| **T019** (FA acceptance) | editor + tile + route wired; `build_runner` + analyze clean | on-device: Dashboard→Settings tile opens the editor for a `settings.manage` user; tile hidden/absent otherwise |
| **T028** (FC acceptance) | gate + cubit + seeding + about wired; analyze clean; redirect invariants statically reviewed (both Opus audits SOUND) | two-device: toggle maintenance on device B → screen appears on device A next foreground; `settings.manage` bypass matrix; offline launch = fail-open (not maintenance, no crash) |
| **T030** (US6 render) | themed via Phase 2 tokens; bilingual ARBs (l10n-parity pass, 870 keys) | four-combination render (light/dark × ar/en) for editor + MaintenanceScreen + about on Infinix Note 8 + a 412 dp AVD |
| **T032** (US-level SC) | docs reconciled to reality; audit infra + RPC deny path wire-tested (T029) | two-device behavioural walks: SC-001 (editor persistence + audit row), SC-004/005 (forward-only seeding/defaults), SC-009 (surfaced support/terms) |

**Why deferred:** the orchestrator has no attached device/emulator. Per memory
`feedback_avd_acceptable_qa`, an AVD walk is acceptable primary QA for this (non
performance-sensitive) feature — run the above on the Pixel 8 Pro AVD or the Infinix Note 8
before tagging the release. Per `feedback_strict_task_completion`, these stay `- [ ]`
/`⚠️ PARTIAL` until physically run and recorded.

## B. Forward-stated future work (OUT of Phase 23 by design)

Each is a separate future spec, not a gap in this one (see `CLAUDE.md` → "Forward-stated future work"):

- **Per-user settings** beyond `user_preferences`.
- **Sensitive settings keys** (`is_public = false`): the column + the `app_settings_select_admin`
  policy exist and are wire-tested (T029), but **no `is_public = false` key is seeded in v1**.
- **Realtime-driven settings**: v1 is fetch-on-load + foreground-resume only (R-201); no
  Realtime subscription on `app_settings` (verified in T031, FR-012).
- **Curated supported-currencies allow-list**: Phase 9 `currencies.is_active` remains the source
  of truth (R-198); `app_settings` stores only the single `default_currency`.

## C. Pre-existing repo-wide lint/format debt (NOT Phase 23)

The full local verify suite (`project_wave_run_full_verify_suite`) is red repo-wide due to
debt that predates this spec and accumulated while CI auto-triggers were paused (2026-05-22):
**3 design-token + 9 l10n-literal + ~65 `dart format`** findings, all in Phase 13–21 files
(agency/reports/home/listing). **Phase 23 introduces zero** such violations (the one FA
`settingsEditorSaveError` literal was fixed; all Phase 23 files are formatted). Left for a
dedicated cleanup spec — fixing it here would balloon a settings PR into unrelated phases.
