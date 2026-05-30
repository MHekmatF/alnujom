# Tasks — Agencies

**Feature**: `specs/019-agencies/` | **Branch**: `019-agencies`
**Inputs**: `plan.md` (Sub-Phases A–J + wave plan), `spec.md` (US1–US6, FR-001..FR-041, SC-001..SC-015), `data-model.md` (full SQL + entities), `contracts/` (8), `research.md` (R-135..R-153), `quickstart.md`.

> **Organization**: Phases 1–10 map 1:1 to the plan's Sub-Phases A–J (the dependency nodes the `/wave` orchestrator dispatches). Each task carries a `[US#]` label when it directly implements a user-story behavior; pure infra / backend-foundation / localization tasks carry none (per the speckit Setup/Foundational/Polish convention). `[P]` marks tasks that can run in parallel with their siblings (different files, no unmet intra-phase dep).
>
> **User-story coverage**: US1 (create agency + submit verification) → Phases 2, 4, 5, 6, 8. US2 (admin verify/approve/reject/suspend) → Phases 2, 3, 5, 7, 9. US3 (members + publish under agency) → Phases 2, 4, 5, 6, 8. US4 (RLS isolation + Vault PII) → Phases 2, 3, 4, 5. US5 (public profile + verified badge) → Phases 3, 6, 8. US6 (agency analytics) → Phases 6, 8.
>
> **No new automated tests** (memory `feedback_no_new_tests.md`): verification is the `quickstart.md` manual recipe (Phase 10/Polish). Existing tests stay.
>
> **Checkbox mandate (read before executing)**: each sub-agent dispatched against this file MUST flip its `- [ ] T<id>` → `- [X] T<id>` **in the same commit** as the implementation for that task. Do NOT defer checkbox-flipping to a cleanup pass.

---

## Phase 1 (Sub-Phase A) — Bootstrap: routes + redirect helper + shared domain enums/entities + stubs

**Goal**: `/agency*` + `/agency/:id` + `/admin/agencies` resolve end-to-end (to stubs); the shared agency value objects exist for both feature folders to type against. No story behavior yet.

- [X] T001 Add route constants to `lib/core/routing/app_router.dart`: `AppRoutes.agency='/agency'`, `agencyMembers='/agency/members'`, `agencyListings='/agency/listings'`, `agencyAnalytics='/agency/analytics'`, `agencyVerify='/agency/verify'`, `agencyProfile='/agency/:id'`, `adminAgencies='/admin/agencies'` (+ matching `AppRouteNames`).
- [X] T002 Add `String? requireAgenciesManageRedirect(BuildContext, GoRouterState)` to `lib/core/routing/auth_redirect.dart` returning `'/admin?denied=agencies'` when `!getIt<PermissionChecker>().any([PermissionKeys.agenciesView, PermissionKeys.agenciesApprove, PermissionKeys.agenciesSuspend])` (mirror `requireListingReviewRedirect`, lines 112–124).
- [X] T003 Register the routes in `lib/core/routing/app_router.dart`: the `/agency*` self-service routes with `redirect: (c,s) => authBloc.state is Unauthenticated ? AppRoutes.login : null` (mirror `/favorites`, lines 480–487), the public `/agency/:id` (no redirect), and a child `GoRoute(path:'agencies', name: AppRouteNames.adminAgencies, redirect: requireAgenciesManageRedirect, builder: … AgencyQueuePage())` under `/admin` (mirror `reports`, lines 354–359). (Depends on T001 + T002; same file as T001.)
- [X] T004 [P] Create `lib/features/agency/domain/entities/agency_status.dart` — `enum AgencyStatus { pending, approved, rejected, suspended }` with `wireValue`/`fromWire`/`isPublic`/`canPublishUnder` (data-model §2.1).
- [X] T005 [P] Create `lib/features/agency/domain/entities/agency_member_role.dart` — `enum AgencyMemberRole { admin, agent }` + `wireValue`/`isAdmin`/`fromWire` (data-model §2.2).
- [X] T006 [P] Create `lib/features/agency/domain/entities/agency_member_status.dart` — `enum AgencyMemberStatus { pending, active, removed }` + `wireValue`/`isActive`/`fromWire` (data-model §2.2).
- [X] T007 Create `lib/features/agency/domain/entities/agency.dart` — the `Agency` `Equatable` entity per data-model §2.3 (imports `AgencyStatus` from T004).
- [X] T008 [P] Create `lib/features/agency/domain/entities/agency_member.dart` — per data-model §2.4 (imports T005/T006).
- [X] T009 [P] Create `lib/features/agency/domain/entities/agency_verification_request.dart` — the `AgencyVerificationRequest` entity + `enum VerificationDecision` per data-model §2.5.
- [X] T010 [P] Create stub `lib/features/agency/presentation/pages/agency_home_page.dart` (empty `Scaffold` + `AppBar`).
- [X] T011 [P] Create stub `lib/features/admin/agencies/presentation/pages/agency_queue_page.dart` (empty `Scaffold` + `AppBar`).

**Checkpoint**: `flutter analyze` clean; `/agency` (auth-redirects signed-out) and `/admin/agencies` (redirects without `agencies.*`) navigate to stubs; `/agency/:id` resolves publicly.

---

## Phase 2 (Sub-Phase B) — Backend schema: 3 tables + `agency_status` enum + listings FK  [US1, US2, US3, US4, US5]

**Goal**: all three tables exist with indices (incl. the open-verification dedup index) + the membership predicates + the enforced `listings.agency_id` FK; RLS enabled.

- [X] T012 [US1] Create migration `supabase/migrations/20260531120001_create_agencies_table.sql` — `CREATE TYPE agency_status` + `public.agencies` (UNIQUE `owner_user_id` ON DELETE CASCADE, `name` NOT NULL CHECK) + `idx_agencies_status` + `set_updated_at` trigger + `ENABLE ROW LEVEL SECURITY`, per data-model §1.1.
- [X] T013 [P] [US3] Create migration `supabase/migrations/20260531120002_create_agency_members_table.sql` — `public.agency_members` (PK `(agency_id,user_id)`, FKs CASCADE, role/status CHECKs) + `idx_agency_members_user` + the SECURITY DEFINER `is_agency_member`/`is_agency_admin` predicates + `ENABLE ROW LEVEL SECURITY`, per data-model §1.2.
- [X] T014 [P] [US1] Create migration `supabase/migrations/20260531120003_create_agency_verification_requests_table.sql` — `public.agency_verification_requests` (account-approval-template CHECKs) + `ux_agency_open_verification` partial unique + `idx_agency_verification_decision` + `set_updated_at` trigger + `ENABLE ROW LEVEL SECURITY`, per data-model §1.3.
- [X] T015 [US3] Create migration `supabase/migrations/20260531120004_enforce_listings_agency_fk.sql` — `ALTER TABLE public.listings ADD CONSTRAINT fk_listings_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id) ON DELETE SET NULL`, per data-model §1.4. (Depends on T012; existing listings all have `agency_id = NULL`.)
- [X] T016 [P] Create `supabase/docs/agencies.md` (columns, UNIQUE owner, FK delete behaviors R-144, forward-stated RLS + name-unique-among-approved).
- [X] T017 [P] Create `supabase/docs/agency_members.md` (PK, lifecycle, predicates, FK behaviors).
- [X] T018 [P] Create `supabase/docs/agency_verification_requests.md` (account-approval template, Vault note, one-open-request index).

**Checkpoint**: `apply_migration` 120001–120004 succeed; `list_tables` shows all 3 with RLS on + the listings FK; `get_advisors` clean.

---

## Phase 3 (Sub-Phase C) — Policies + `v_agencies` view + `v_listings_public` badge amendment + audit triggers  [US2, US4, US5]

**Goal**: the public/owner/member/admin read matrix, the definer view, the badge join, and the three audit triggers are in place.

- [X] T019 [US4] Create migration `supabase/migrations/20260531120005_create_agency_policies.sql` — the 3 SELECT policies (`agencies` authenticated + anon-approved; `agency_members`; `agency_verification_requests`) using `is_agency_member`/`is_agency_admin`/`current_user_has_permission('agencies.view')` + `REVOKE INSERT,UPDATE,DELETE` on all 3 + `ux_agencies_name_approved` partial unique index, per data-model §1.5.
- [X] T020 [P] [US5] Create migration `supabase/migrations/20260531120006_create_v_agencies_view.sql` — `public.v_agencies` SECURITY DEFINER view with the owner/member/admin WHERE (never projects Vault fields) + `GRANT SELECT TO anon, authenticated`; AND the additive `CREATE OR REPLACE VIEW public.v_listings_public` badge amendment (`LEFT JOIN public.agencies … AND status='approved'` projecting `agency_id`/`agency_name`/`agency_logo_path`), per data-model §1.6. **Do NOT edit the Phase 14 file in place — `CREATE OR REPLACE` here.**
- [X] T021 [P] [US2] Create migration `supabase/migrations/20260531120011_create_agency_audit_triggers.sql` — `trg_agencies_audit_status`, the SPLIT `trg_agency_members_audit_ins_del` + `trg_agency_members_audit_upd` (valid syntax; `user_id` target + composite columns), and `trg_agency_verification_audit`, all reusing `log_audit()`, per data-model §1.11.
- [X] T022 Update `supabase/docs/agencies.md` + `agency_members.md` + `agency_verification_requests.md` with the full RLS reader/writer matrix (data-model §1.14) + the `v_agencies` scoping + audit-trigger notes.

**Checkpoint**: wire-level read-matrix smoke (anon approved-only / owner own-any-status / non-admin no roster-or-verification) per `contracts/phase19-agency-policies-and-v-agencies.md`; `get_advisors` shows only the expected `v_agencies` definer-view note.

---

## Phase 4 (Sub-Phase D) — Vault helpers + create/member/verification RPCs  [US1, US3, US4]

**Goal**: the admin-decrypt Vault helpers + the bypass-proof create/membership/verification write paths.

- [X] T023 [US4] Create migration `supabase/migrations/20260531120007_create_agency_vault_helpers.sql` — `app_vault_set_agency_secret` (is_agency_admin gate, allowlist, **idempotent update-or-create** so re-submission overwrites) + `app_vault_secret_for_agency` (`agencies.view`-gated admin decrypt), per data-model §1.7.
- [X] T024 [US1] Create migration `supabase/migrations/20260531120008_create_agency_write_rpcs.sql` — the 6 SECURITY DEFINER RPCs per data-model §1.8: `create_agency` (approved-publisher, one-per-owner, seeds owner admin/active member); `invite_agency_member` (is_agency_admin, resolve phone→existing account `user_not_found`, idempotent ON CONFLICT); `respond_agency_invitation` (invitee-only); `set_agency_member_role`/`remove_agency_member` (is_agency_admin, owner protected); `submit_agency_verification` (is_agency_admin, inserts request + Vault-stores both numbers). Grants → `authenticated`.

**Checkpoint**: `contracts/phase19-agency-write-rpcs.md` smoke tests (non-publisher `not_a_publisher`; 2nd-agency `already_owns_agency`; unregistered-phone `user_not_found`; invitee accept→active; owner protected; Vault decrypt admin-only).

---

## Phase 5 (Sub-Phase E) — Moderation RPC + Edge Function + `submit_listing` amendment + advisor + storage  [US1, US2, US3, US4]

**Goal**: the atomic dual-layer-gated agency moderation; the soft-gate publish validation; advisor hardening; the storage buckets.

- [X] T025 [US3] **Integration check (R-143) — BLOCKING for T026 (author T026 ONLY after T025 completes)**: read `supabase/migrations/20260522120004_amend_submit_listing_rpc_for_media_minimum.sql` (the LATEST `submit_listing` body) and confirm the exact insertion point — after the final required-field validation, immediately BEFORE the `UPDATE … status='pending_review'`. Re-base T026's amendment on that body so NO existing validation (profile approval, ≥1 price, ≥1 image, residential rules) is dropped. T026 MUST be a `CREATE OR REPLACE` that re-asserts the ENTIRE existing body verbatim PLUS the agency-membership branch.
- [X] T026 [US3] Create migration `supabase/migrations/20260531120009_amend_submit_listing_agency_check.sql` — `CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id uuid)` re-asserting the latest body PLUS the agency-membership `IF v_listing.agency_id IS NOT NULL THEN … not_an_agency_member` branch (active member of an agency in {pending,approved}), per data-model §1.9 / `contracts/phase19-submit-listing-agency-amendment.md`. **The existing per-user publish RLS is untouched.**
- [X] T027 [US2] Create migration `supabase/migrations/20260531120010_create_agency_moderation_rpcs.sql` — `public.moderate_agency_internal(p_agency_id, p_actor_user_id, p_action, p_reason_json)` SECURITY DEFINER (service_role only) per data-model §1.10: `set_config('app.current_user_id')` → `no_pending_verification` guard → `rejection_reason_required` guard → transition guards (`invalid_transition`) → `name_taken` guard on approve → agency UPDATE (fires audit) → verification-request UPDATE on approve/reject (fires audit) → return row.
- [X] T028 [US2] Create Edge Function `supabase/functions/moderate_agency/index.ts` — a near-copy of `supabase/functions/approve_listing/index.ts`: validate `{agency_id, action, reason?}` (reject requires reason) → `parseJwtSub` → per-action `jwtClient.rpc('current_user_has_permission',{perm_key})` (`agencies.approve` for approve/reject, `agencies.suspend` for suspend/reinstate; 403 on false) → `adminClient.rpc('moderate_agency_internal', {...})` → map `agency_not_found`→404, `invalid_transition`/`name_taken`/`no_pending_verification`→409, `rejection_reason_required`→400, success→200, per `contracts/phase19-moderate-agency-edge-function.md`.
- [X] T029 [US4] Create migration `supabase/migrations/20260531120012_phase19_advisor_hardening.sql` — safety-net `ALTER FUNCTION … SET search_path` for all Phase 19 functions + re-assert grants (write RPCs + vault helpers + predicates → `authenticated`; `moderate_agency_internal` → `service_role`) + re-assert `REVOKE INSERT,UPDATE,DELETE` on the 3 tables + `GRANT SELECT ON public.v_agencies TO anon, authenticated`, per data-model §1.12.
- [X] T030 [US1] Create migration `supabase/migrations/20260531120013_create_agency_storage.sql` — the `agency-assets` (public, image/jpeg, 5 MB) + `agency-documents` (private) buckets + their policies (public read of approved-agency logos; agency-admin write via `^[uuid]/.+$` path-shape + `is_agency_admin`; owner/`agencies.view` read of private documents), per data-model §1.13.

**Checkpoint**: `contracts/phase19-moderate-agency-edge-function.md` + `phase19-submit-listing-agency-amendment.md` smoke tests; dual-layer unauthorized-moderation rejection (SC-011); approve name-collision (SC-004); publish membership validation (SC-007).

---

## Phase 6 (Sub-Phase F) — Agency self-service domain + data layer  [US1, US3, US5, US6]

**Goal**: the `AgencyRepository` + datasource the self-service UI consumes.

- [ ] T031 [US1] Create `lib/features/agency/domain/repositories/agency_repository.dart` — `createAgency`, `loadMyAgency`, `updateProfile`, `submitVerification`, `loadMembers`, `inviteMember`, `respondInvitation`, `setMemberRole`, `removeMember`, `loadMyInvitations`, `loadAgencyListings`, `loadAnalytics` (all `Result<T>`), per data-model §2.7.
- [ ] T032 [P] [US1] Create the agency-profile use cases under `lib/features/agency/domain/usecases/` — `create_agency.dart`, `load_my_agency.dart`, `update_agency_profile.dart`, `submit_agency_verification.dart`, `load_agency_listings.dart`, `load_agency_analytics.dart` (each `@injectable`, one repo method).
- [ ] T033 [P] [US3] Create the membership use cases under `lib/features/agency/domain/usecases/` — `load_agency_members.dart`, `invite_agency_member.dart`, `respond_agency_invitation.dart`, `set_agency_member_role.dart`, `remove_agency_member.dart`, `load_my_agency_invitations.dart` (each `@injectable`).
- [ ] T034 [P] [US1] Create `lib/features/agency/data/dtos/agency_dto.dart` + `agency_member_dto.dart` (mirror `v_agencies` + `agency_members` rows; `fromJson` + `toEntity()`).
- [ ] T035 [US1] Create `lib/features/agency/data/datasources/supabase_agency_datasource.dart` — `createAgency`/member-ops/`submitVerification` via `rpc(...)`; `loadMyAgency`/`loadMembers`/`loadMyInvitations` via `from('v_agencies'/'agency_members').select()`; verification doc upload to the `agency-documents` bucket; `loadAgencyListings` via the badge-augmented `v_listings_public`; `loadAnalytics` via bounded count queries.
- [ ] T036 [US1] Create `lib/features/agency/data/repositories/agency_repository_impl.dart` mapping RPC error codes (`not_a_publisher`, `already_owns_agency`, `user_not_found`, `permission_denied`, …) to `Failure`s.
- [ ] T037 Register the use cases + repository (`@LazySingleton(as: AgencyRepository)`) + datasource with `@injectable`; run `build_runner` to regenerate `lib/core/di/injection.config.dart`.

**Checkpoint**: `flutter analyze` clean; no `package:supabase_flutter` import under `lib/features/agency/domain/`.

---

## Phase 7 (Sub-Phase G) — Admin agencies domain + data layer  [US2]

**Goal**: the `AgenciesAdminRepository` + datasource the verification queue/decision UI consumes.

- [X] T038 [P] [US2] Create `lib/features/admin/agencies/domain/entities/agency_verification_item.dart` per data-model §2.6 (the `Agency` + `AgencyVerificationRequest` + admin-only decrypted id/registration numbers + owner display name).
- [X] T039 [US2] Create `lib/features/admin/agencies/domain/repositories/agencies_admin_repository.dart` — `loadQueue({status?, cursor?})`, `loadDetail(agencyId)`, `approve`, `reject`, `suspend`, `reinstate` (all `Result<T>`).
- [X] T040 [P] [US2] Create the 5 use cases under `lib/features/admin/agencies/domain/usecases/` — `load_agency_verification_queue.dart`, `approve_agency.dart`, `reject_agency.dart`, `suspend_agency.dart`, `reinstate_agency.dart` (each `@injectable`).
- [X] T041 [US2] Create `lib/features/admin/agencies/data/dtos/agency_verification_item_dto.dart`.
- [X] T042 [US2] Create `lib/features/admin/agencies/data/datasources/supabase_agencies_admin_datasource.dart` — `loadQueue`/`loadDetail` via `from('v_agencies'/'agency_verification_requests').select()` + `rpc('app_vault_secret_for_agency',…)` for the decrypted id fields; `approve`/`reject`/`suspend`/`reinstate` via `functions.invoke('moderate_agency', body:{...})`.
- [X] T043 [US2] Create `lib/features/admin/agencies/data/repositories/agencies_admin_repository_impl.dart`.
- [X] T044 Register the use cases + repository + datasource with `@injectable`/`@LazySingleton`; regenerate `lib/core/di/injection.config.dart`.

**Checkpoint**: `flutter analyze` clean; admin domain imports the shared `Agency`/`AgencyStatus` from `lib/features/agency/domain/entities/`; no Supabase import under `domain/`.

---

## Phase 8 (Sub-Phase H) — Agency self-service presentation + entry wiring  [US1, US3, US5, US6]

**Goal**: the create/profile/members/verify/analytics pages, the pending-invitations surface, the verified badge, and the publish-under-agency selector.

- [ ] T045 [US1] Create `lib/features/agency/presentation/bloc/agency_home_cubit.dart` (`@injectable`) — none/owner/member state via `LoadMyAgency`.
- [ ] T046 [US3] Create `lib/features/agency/presentation/bloc/agency_members_bloc.dart` (+ `_state.dart`) — roster load + invite/role/remove via the membership use cases.
- [ ] T047 [US1] Create `lib/features/agency/presentation/bloc/agency_verification_cubit.dart` — submit + status via `SubmitAgencyVerification`/`LoadMyAgency`.
- [ ] T048 [US3] Create `lib/features/agency/presentation/bloc/agency_invitations_cubit.dart` — pending invitations + accept/decline via `LoadMyAgencyInvitations`/`RespondAgencyInvitation`.
- [ ] T049 [US6] Create `lib/features/agency/presentation/bloc/agency_listings_bloc.dart` (+ `_state.dart`, paginated) + `agency_analytics_cubit.dart`.
- [ ] T050 [P] [US5] Create `lib/features/agency/presentation/widgets/agency_status_chip.dart` + `agency_member_tile.dart` (Phase 2 tokens).
- [ ] T051 [US3] Create `lib/features/agency/presentation/widgets/invite_member_sheet.dart` — phone + role; surfaces `user_not_found`/`already_member`.
- [ ] T052 [P] [US5] Create `lib/features/agency/presentation/widgets/agency_badge.dart` — name + logo, links to `/agency/:id`.
- [ ] T053 [US3] Create `lib/features/agency/presentation/widgets/publish_under_agency_field.dart` — selector over "personal" + the user's active agencies in {pending,approved}.
- [ ] T054 [US1] Replace the Phase-1 stub `lib/features/agency/presentation/pages/agency_home_page.dart` — "Create agency" when none; the management surface (links to members/listings/analytics/verify) when owner/member.
- [ ] T055 [US5] Create `lib/features/agency/presentation/pages/agency_profile_page.dart` — public `/agency/:id` (name/logo/contact + approved listings).
- [ ] T056 [US3] Create `lib/features/agency/presentation/pages/agency_members_page.dart` — roster + invite sheet + pending invitations + role/remove.
- [ ] T057 [US6] Create `lib/features/agency/presentation/pages/agency_listings_page.dart` (paginated) + `agency_analytics_page.dart` (member + listing-by-status counters).
- [ ] T058 [US1] Create `lib/features/agency/presentation/pages/agency_verification_page.dart` — doc upload + ID/registration fields + status banner + rejection reason.
- [ ] T059 [US1] Add the "My Agency" `ListTile(Icons.business_outlined, l10n.profile_agency_tile, → AppRoutes.agency)` to `lib/features/profile/presentation/pages/profile_page.dart` between the "My Favorites" tile (lines 139–145) and the "My Reports" tile (lines 147–153).
- [ ] T060 [US5] Add an OPTIONAL `agencyName`/`agencyLogoPath` (or `Widget? agencyBadge`) param to `lib/core/widgets/property_card.dart` and render it only when non-null — NO layout change when null (FR-023). Card sites pass the badge fields from `v_listings_public`.
- [ ] T061 [US5] Mount `AgencyBadge(...)` in `lib/features/listing_details/presentation/pages/listing_details_page.dart` only when the loaded listing's agency is `approved` (the Favorite/Share/Report CTAs UNCHANGED).
- [ ] T062 [US3] Host `PublishUnderAgencyField` in `lib/features/listing_form/presentation/widgets/step_basics.dart` (after property-type) and carry `agencyId` in `lib/features/listing_form/presentation/bloc/listing_form_bloc.dart` — load active memberships in `attachContext` (lines 106–112) + `draftListing.copyWith(agencyId:…)` (listing.dart lines 268–301).
- [ ] T063 Register the cubits/blocs with `@injectable`; regenerate `lib/core/di/injection.config.dart`.

**Checkpoint**: SC-001 (create), SC-002 (verification), SC-006 (invite+accept), SC-007 (publish under agency), SC-008 (badge) from `quickstart.md`.

---

## Phase 9 (Sub-Phase I) — Admin presentation + admin-home tile  [US2]

**Goal**: the `agencies.*`-gated verification queue with pagination, the decision flow with confirmation, the admin-home tile.

- [ ] T064 [US2] Create `lib/features/admin/agencies/presentation/bloc/agency_queue_bloc.dart` (+ `agency_queue_state.dart`) — `Opened`/`FilterChanged(status?)`/`LoadMore`/`Refresh` calling `LoadAgencyVerificationQueue` (cursor pagination, FR-007/SC-015).
- [ ] T065 [P] [US2] Create `lib/features/admin/agencies/presentation/widgets/agency_queue_card.dart` — agency name + owner + submitted-at.
- [ ] T066 [US2] Replace the Phase-1 stub `lib/features/admin/agencies/presentation/pages/agency_queue_page.dart` — `AppBar(l10n.agencies_queue_title)` + status filter + paginated `ListView`; tap → `agency_detail_page.dart`.
- [ ] T067 [P] [US2] Create `lib/features/admin/agencies/presentation/widgets/agency_decision_dialog.dart` — approve / reject (reason) / suspend (destructive confirm, FR-010) / reinstate.
- [ ] T068 [US2] Create `lib/features/admin/agencies/presentation/bloc/agency_moderation_cubit.dart` — `approve`/`reject`/`suspend`/`reinstate` via the admin use cases.
- [ ] T069 [US2] Create `lib/features/admin/agencies/presentation/pages/agency_detail_page.dart` — profile + decrypted ID/registration numbers + evidence docs + the 4 actions via `AgencyDecisionDialog`.
- [ ] T070 [US2] Add the Agencies tile to `lib/features/admin/presentation/pages/admin_home_page.dart`: `if (checker.has(PermissionKeys.agenciesView)) ListTile(Icons.business_outlined, l10n.admin_tile_agencies, → AppRoutes.adminAgencies)` (mirror the reports tile, lines 69–75).
- [ ] T071 Register the bloc/cubit with `@injectable`; regenerate `lib/core/di/injection.config.dart`.

**Checkpoint**: SC-003 (gating + queue + decrypted ID), SC-004 (approve/reject + audit), SC-005 (suspend hides profile/badge), SC-011 (unauthorized rejected) from `quickstart.md`.

---

## Phase 10 (Sub-Phase J) — Localization

**Goal**: all ~40 new strings localized in `ar` + `en`.

- [X] T072 Add the ~40 keys to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb` (create/profile/members/invite/verify/analytics/badge/admin-queue/decisions/tiles), per plan Sub-Phase J. Arabic copy Syrian-friendly. (The `profile_agency_tile` vs `admin_tile_agencies` key-naming asymmetry is INTENTIONAL — it mirrors the established Phase 18 `profile_reports_tile` + `admin_tile_reports` convention; keep it for cross-phase consistency rather than inventing a new symmetric scheme.)
- [X] T073 Run `flutter gen-l10n` to regenerate `lib/l10n/app_localizations*.dart`.

**Checkpoint**: no inline `Text('...')` literals in the two feature folders; all strings resolve via `AppLocalizations`.

---

## Polish & Cross-Cutting

- [ ] T074 **Device QA** (Infinix Note 8 + Pixel 8 Pro AVD): apply the 13 migrations (`…009` re-based first) + deploy the `moderate_agency` Edge Function, then walk the full `quickstart.md` recipe on-device + at the wire level. Confirm ALL 15 SCs (SC-001..SC-015), including the public/owner/member/admin/anon read matrix (SC-009), the admin-only Vault decrypt (SC-010), the dual-layer unauthorized-moderation rejection (SC-011), and the 4-combination theme×locale matrix (SC-013).
- [ ] T075 Run the constitution grep gates (SC-014): `pubspec.yaml` unchanged vs `main` (zero new deps); zero hardcoded role/permission branch in `lib/features/agency/` + `lib/features/admin/agencies/` (gating is `is_agency_admin` / `PermissionKeys.agencies*`); no `package:supabase_flutter` under any `domain/`/`presentation/`; no inline `Text('…')` literals; no Phase 19 migration adds a value to the `listings.status` CHECK or touches `lead_events`.
- [ ] T076 Verify each of the 8 `contracts/*.md` smoke-test blocks is exercised by a `quickstart.md` step (`phase19-agencies-table`, `phase19-agency-members-table`, `phase19-agency-verification-requests-table`, `phase19-agency-policies-and-v-agencies`, `phase19-agency-write-rpcs`, `phase19-moderate-agency-edge-function`, `phase19-submit-listing-agency-amendment`, `phase19-agency-ui-and-entry-points`); record any contract assertion not yet covered by the recipe (read-only audit — no contract is implementation, so no checkbox dependency).

---

## Dependencies & user-story completion order

- **US1 (create agency + submit verification)** is testable after Phases 2 (tables), 4 (create/verification RPCs + Vault), 5 (storage), 6 (repo/data), 8 (create/verify UI). MVP slice.
- **US4 (RLS isolation + Vault PII)** is verifiable after Phases 2 + 3 (+ 4 Vault) — purely backend; no UI needed.
- **US2 (admin verify/suspend)** is testable after Phases 2, 3, 5 (moderation), 7 (admin data), 9 (admin UI).
- **US3 (members + publish under agency)** is testable after Phases 2, 4 (member RPCs), 5 (submit_listing amendment), 6, 8.
- **US5 (public profile + badge)** is testable after Phases 3 (v_agencies + badge), 6, 8.
- **US6 (agency analytics)** is testable after Phases 6 (analytics query), 8 (analytics page).

Suggested **MVP** = US1 (create + verify) + US4 (isolation) + US2 (admin verify): Phases 1→2→3→4→5→6→7→8→9 deliver the create→verify→approve loop; US5 badge and US6 analytics layer on within the same phases.

---

# Multi-Agent Execution (for `/wave all --auto`)

> Phases 1–10 below = Sub-Phases A–J in `plan.md`. The orchestrator executes the Wave Plan directly without re-deriving it.

## Touch-Fan Table

Shared / contended files each phase modifies (the orchestrator warns sub-agents up front and merges least-touch-first):

- **Phase 1 (A)**: `lib/core/routing/app_router.dart`, `lib/core/routing/auth_redirect.dart` (+ new files under `lib/features/agency/domain/entities/` and the two stub pages — uncontended).
- **Phase 2 (B)**: `supabase/migrations/20260531120001_create_agencies_table.sql`, `…120002_create_agency_members_table.sql`, `…120003_create_agency_verification_requests_table.sql`, `…120004_enforce_listings_agency_fk.sql`, `supabase/docs/{agencies,agency_members,agency_verification_requests}.md` (CREATE).
- **Phase 3 (C)**: `supabase/migrations/20260531120005_create_agency_policies.sql`, `…120006_create_v_agencies_view.sql`, `…120011_create_agency_audit_triggers.sql`, `supabase/docs/*.md` (APPEND). `…120006` does a `CREATE OR REPLACE` of `v_listings_public` — the Phase 14 file `20260525120002` is **never edited in place**, so it is NOT a contended file.
- **Phase 4 (D)**: `supabase/migrations/20260531120007_create_agency_vault_helpers.sql`, `…120008_create_agency_write_rpcs.sql`.
- **Phase 5 (E)**: `supabase/migrations/20260531120009_amend_submit_listing_agency_check.sql`, `…120010_create_agency_moderation_rpcs.sql`, `…120012_phase19_advisor_hardening.sql`, `…120013_create_agency_storage.sql`, `supabase/functions/moderate_agency/index.ts`. `…120009` `CREATE OR REPLACE`s `submit_listing` — the Phase 11 file `20260522120004` is **never edited in place**, so it is NOT a contended file.
- **Phase 6 (F)**: `lib/core/di/injection.config.dart` (codegen) — all other files are new under `lib/features/agency/{domain,data}/`.
- **Phase 7 (G)**: `lib/core/di/injection.config.dart` (codegen) — all other files are new under `lib/features/admin/agencies/{domain,data}/`.
- **Phase 8 (H)**: `lib/features/profile/presentation/pages/profile_page.dart`, `lib/core/widgets/property_card.dart`, `lib/features/listing_details/presentation/pages/listing_details_page.dart`, `lib/features/listing_form/presentation/widgets/step_basics.dart`, `lib/features/listing_form/presentation/bloc/listing_form_bloc.dart`, `lib/core/di/injection.config.dart` (codegen) — all other files new under `lib/features/agency/presentation/`.
- **Phase 9 (I)**: `lib/features/admin/presentation/pages/admin_home_page.dart`, `lib/core/di/injection.config.dart` (codegen) — all other files new under `lib/features/admin/agencies/presentation/`.
- **Phase 10 (J)**: `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_localizations*.dart` (codegen).

> **Codegen note**: `injection.config.dart` is touched by Phases 6, 7, 8, 9 but is a generated file — the orchestrator regenerates it once after each wave rather than merging it. The only hand-edited shared-file overlaps are within `supabase/docs/*.md` (Phase 2 creates, Phase 3 appends — Wave 1 vs Wave 2, no concurrency) and `app_router.dart` (Phase 1 only). Phase 8's six existing-file edits and Phase 9's one edit are in disjoint feature folders (no H↔I overlap).

## Dependency Audit

Every declared dependency, with the specific file/symbol the dependent phase consumes (a dep that cannot name a consumer is false and is omitted):

- **Phase 3 → Phase 2**: T019/T020/T021 attach to / select from `public.agencies`/`agency_members`/`agency_verification_requests` (T012/T013/T014) and use `is_agency_member`/`is_agency_admin` (T013).
- **Phase 4 → Phase 2**: T024's `create_agency` INSERTs `public.agencies` + `agency_members`; the member RPCs UPDATE `agency_members`; `submit_agency_verification` INSERTs `agency_verification_requests` (relies on `ux_agency_open_verification`) — T012/T013/T014. T023/T024 call `is_agency_admin` (T013).
- **Phase 5 → Phase 2**: T026's `submit_listing` amendment EXISTS-checks `public.agency_members` + `public.agencies` (T012/T013); T027's `moderate_agency_internal` UPDATEs `public.agencies` + `agency_verification_requests` (T012/T014); T030's storage policies use `is_agency_admin` (T013).
- **Phase 6 → Phase 1**: T031/T034/T035 type against `Agency`/`AgencyStatus`/`AgencyMember`/`AgencyMemberRole`/`AgencyMemberStatus`/`AgencyVerificationRequest` at `lib/features/agency/domain/entities/*.dart` (T004–T009).
- **Phase 6 → Phase 3**: T035 selects `public.v_agencies` (T020) under the agency policies (T019) and reads the badge-augmented `v_listings_public` (T020).
- **Phase 6 → Phase 4**: T035's create/member/verification calls invoke `create_agency`/`invite_agency_member`/`respond_agency_invitation`/`set_agency_member_role`/`remove_agency_member`/`submit_agency_verification` (T024) + the Vault helpers (T023).
- **Phase 6 → Phase 5**: T035's verification-document upload targets the `agency-documents` bucket created in T030.
- **Phase 7 → Phase 1**: T038/T040 use `Agency`/`AgencyStatus` at `lib/features/agency/domain/entities/{agency,agency_status}.dart` (T004/T007).
- **Phase 7 → Phase 3**: T042 reads `public.v_agencies` (T020) + the `agency_verification_requests` `agencies.view` policy (T019).
- **Phase 7 → Phase 4**: T042 calls `public.app_vault_secret_for_agency(uuid,text)` (T023) for the admin-decrypted ID fields.
- **Phase 7 → Phase 5**: T042's `approve`/`reject`/`suspend`/`reinstate` invoke the `moderate_agency` Edge Function `supabase/functions/moderate_agency/index.ts` (T028).
- **Phase 8 → Phase 1**: T054/T059 are registered at / push `AppRoutes.agency` (T001/T003); T053/T062 use the agency enums/entities (T004–T009).
- **Phase 8 → Phase 6**: T045–T058 inject `CreateAgency`/`LoadMyAgency`/`InviteAgencyMember`/`RespondAgencyInvitation`/`SubmitAgencyVerification`/`LoadAgencyListings`/`LoadAgencyAnalytics`/… at `lib/features/agency/domain/usecases/*.dart` (T032/T033) + the repo (T031); pages render `Agency`/`AgencyMember`.
- **Phase 8 → Phase 10**: T051/T054/T055/T058/T059/T060/T062 consume generated getters (`profile_agency_tile`, `agency_create_title`, `agency_verified_badge`, `listing_publish_under_agency_label`, …) from `lib/l10n/app_localizations.dart` (T072/T073).
- **Phase 9 → Phase 1**: T066 is registered at `AppRoutes.adminAgencies` (T003) guarded by `requireAgenciesManageRedirect` (T002); T070's tile pushes `AppRoutes.adminAgencies` (T001).
- **Phase 9 → Phase 7**: T064/T068 inject `LoadAgencyVerificationQueue`/`ApproveAgency`/`RejectAgency`/`SuspendAgency`/`ReinstateAgency` at `lib/features/admin/agencies/domain/usecases/*.dart` (T040); pages render `AgencyVerificationItem` (T038).
- **Phase 9 → Phase 10**: T066/T067/T070 consume generated getters (`admin_tile_agencies`, `agencies_queue_title`, `agency_action_*`, `agency_suspend_confirm_*`) from `lib/l10n/app_localizations.dart` (T072/T073).

Phases 1, 2, and 10 declare **no** in-spec predecessor (pure roots). **Zero** declared deps lack a named consumer (17 edges).

## Wave Plan

Topological sort, ≤4 phases per wave (no wave exceeds 3):

- **Wave 1**: Phase 1, Phase 2, Phase 10 — no unmet deps (A bootstrap, B tables, J localization are all roots).
- **Wave 2**: Phase 3, Phase 4, Phase 5 — all deps (Phase 2) satisfied by Wave 1. (Phase 5 runs the R-143 `submit_listing` integration check + reads B's tables for the storage/membership predicates.)
- **Wave 3**: Phase 6, Phase 7 — deps (Phases 1, 3, 4, 5) satisfied by Waves 1–2.
- **Wave 4**: Phase 8, Phase 9 — deps (Phases 1, 6, 10 / Phases 1, 7, 10) satisfied by Waves 1–3.
- **Polish**: T074–T076 run after Wave 4 merges (manual device QA + grep gates + contract-coverage audit).

## Model Routing per Phase

Per the heuristic (Opus for atomic transactions / invariants / state machines / RLS / Vault / concurrency; Sonnet for scaffolding / DAO CRUD / widgets / l10n / docs):

- **Phase 1 (A)**: Sonnet (routing constants + redirect helper + plain enums/entities + stub pages).
- **Phase 2 (B)**: Opus (RLS-enabled schema + composite-PK + FK-over-existing-data + the SECURITY DEFINER `is_agency_admin`/`is_agency_member` predicates — security-load-bearing).
- **Phase 3 (C)**: Opus (RLS policies + the SECURITY DEFINER `v_agencies` definer-scoping invariant + the audit triggers — RLS/invariants).
- **Phase 4 (D)**: Opus (SECURITY DEFINER write RPCs + un-forgeable owner binding + per-agency admin gates + Vault PII idempotency — security/invariants).
- **Phase 5 (E)**: Opus (the atomic `moderate_agency_internal` state machine + the dual-layer Edge Function + the `submit_listing` integration check + the storage RLS — atomic/state-machine/RLS).
- **Phase 6 (F)**: Sonnet (repository + datasource + thin use cases + DTO mapping + error mapping — Dart data-layer scaffolding).
- **Phase 7 (G)**: Sonnet (admin data layer + Edge-Function invoke + Vault-decrypt read — scaffolding).
- **Phase 8 (H)**: Sonnet (cubits/blocs + pages + widgets + the badge/publish-under-agency entry wiring — UI).
- **Phase 9 (I)**: Sonnet (admin queue + decision UI — UI).
- **Phase 10 (J)**: Sonnet (ARB localization + codegen).
- **Polish**: Sonnet (manual device-QA walk + grep gates; device QA is human-run on the Infinix Note 8).

Compact form: `Phase 1: Sonnet (routing + scaffolding). Phase 2: Opus (RLS schema + definer predicates). Phase 3: Opus (RLS policies + definer view + audit). Phase 4: Opus (SECURITY DEFINER write RPCs + Vault). Phase 5: Opus (atomic moderate_agency + submit_listing gate + storage RLS). Phase 6: Sonnet (agency data layer). Phase 7: Sonnet (admin data layer). Phase 8: Sonnet (self-service UI). Phase 9: Sonnet (admin UI). Phase 10: Sonnet (l10n).`
