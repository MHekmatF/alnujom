# Contract — Golden-path QA pass & carried-over fixes (QV + CF)

**Owner phases**: QV (verification + 1 test + docs + distribution) and CF (the code fixes). **Principles**: X (verifiable, recorded), III (APK secret-scan), I (drift recorded).

## The six golden paths (FR-013)

1. **Primary publish** — register → admin-approve → publish → admin-approve → public view → inquiry. **Automated** (`integration_test/primary_publish_path_test.dart`) **+ manual**.
2. Anonymous browse + filter + map. Manual.
3. Admin reports-queue resolution. Manual.
4. Super-admin role create + assign + revoke. Manual.
5. Currency switch + exchange-rate update. Manual.
6. Maintenance mode + recovery. **Manual two-device** (not automatable in-process).

Push delivery (notification leg) is **manual** (real FCM round-trip). Evidence is **hybrid** (R-214/FR-014): manual walks ×6 on Infinix Note 8 + Pixel 8 Pro AVD, plus the one automated test green.

## CF carried-over fixes (R-215) — what must be fixed in-PR

- **Agency-logo double-prefix** (Phase 19 residual): `supabase_agency_datasource.dart` stores a full public URL in `logo_path`/`cover_path`; `agency_badge.dart` re-prefixes → HTTP 400 → broken-logo placeholder. Fix **read-time** (store path only, or detect absolute-URL + skip re-prefix) — **no migration/backfill**.
- **`isClosed` sweep**: `if (isClosed) return;` before `emit` in `AdSlotCubit.load` (`ad_slot_cubit.dart:41`), `AgencyVerificationCubit.load` (`agency_verification_cubit.dart:101`), `ProfileCubit.load` (`profile_cubit.dart:37`), + a codebase sweep for the same async-load pattern (FR-017/SC-009).
- **Phase 19 D-1/D-2/D-3**: already DONE (2026-06-01) — verified, not re-done. **FE-1** (suspend/remove cascade choice) stays a **future spec** — OUT of scope.
- **Phase 22 T044–T046**: reconciled as **on-device verification** (owned by QV — admin-counter two-device pass; six-event in-app delivery with push blocked; cross-user RLS-denial from a real user-X JWT; non-admin Realtime delivers no admin rows) **+ the APK secret-scan** (QV). The `dispatch_push` redeploy + IMPORTANCE_HIGH push channel are **operator push-enablement** prerequisites, not v1.0.0 default-build code.

## QV deliverables (FR-011/FR-012/FR-013)

- **APK secret-scan** (Phase 22 T046): binary-scan the signed APK; confirm **no** DSN / keystore / Vault / FCM service-account material shipped.
- **Cold-start baseline**: measure on the Infinix Note 8 vs the §15 < 3 s budget; record as **advisory, not a gate** (clarify Q2).
- **`docs/release/v1.0.0.md`**: 6-path results, install/update steps, the **no-email account-recovery support flow** (admin issues a temp password via the super-admin UI, §15), the cold-start baseline, the secret-scan result, the distribution checklist.
- **Distribution** (R-216): upload APK + version manifest to Supabase Storage; post to Telegram; configure the Play Store internal testing track (QA-only).
- Any **new** out-of-scope issue surfaced during the walk → `specs/024-release-polish/DEFERRED.md` with a rationale (no silent drop).

## Invariants (verified)

- All six paths pass on the **signed release build**; the automated test is green; maintenance + push verified manually (SC-004).
- The APK contains no secret (SC-002/SC-008 boundary).
- The release notes exist and cover the required sections (SC-006).
- The three named carried-over buckets are closed (or, for already-done D-1/2/3, verified); FE-1 is left future (SC-008).
