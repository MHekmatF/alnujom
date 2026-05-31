# Implementation Plan: Agencies

**Branch**: `019-agencies` | **Date**: 2026-05-30 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/019-agencies/spec.md`

## Summary

Phase 19 ships **agencies as multi-user publishing entities** — the first consumer of the three `agencies.*` permission keys Phase 6 seeded onto `admin` + `super_admin` (`supabase/migrations/20260515120002_create_permissions.sql:43-45`) and the first to give the long-reserved `listings.agency_id` column (`supabase/migrations/20260519120002_create_listings.sql:7`, "R-17 agency_id has no FK in Phase 10") a real foreign key. The plan delivers: (a) three new Supabase tables — `public.agencies` (a brokerage owned by exactly one approved publisher, lifecycle `agency_status` ∈ `pending`/`approved`/`rejected`/`suspended`, UNIQUE `owner_user_id` per Q3=A), `public.agency_members` (the roster: per-agency `member_role` ∈ {`admin`,`agent`} + membership `status` ∈ {`pending`,`active`,`removed`}, PK `(agency_id,user_id)`), and `public.agency_verification_requests` (structurally mirroring the Phase 5 `account_approval_requests` table `supabase/migrations/20260510120001`, with a `decision` ∈ {`pending`,`approved`,`rejected`} and Vault-stored identity material); (b) the `listings.agency_id` FK enforced with `ON DELETE SET NULL` (R-144); (c) agency creation via a `create_agency(...)` SECURITY DEFINER RPC binding `owner_user_id = auth.uid()`, requiring `publisher_status='approved' AND account_status='approved'`, enforcing the one-agency-per-owner UNIQUE, seeding the agency `pending` and the owner as the first `agency_members` row (`admin`/`active`); (d) membership by **invite + in-app accept** (Q2=B) — `invite_agency_member(p_agency_id, p_phone, p_role)` resolves an already-registered account by phone (no match → `user_not_found`), creates a `pending` roster row, and `respond_agency_invitation(p_agency_id, p_accept)` lets the invitee (only) flip it to `active` or `removed`; member management (`invite`/`set_role`/`remove`) is authorized by the caller's own `member_role='admin'` row for THAT agency (R-140), never the inert global `agency_admin` role; (e) agency verification — `submit_agency_verification(...)` (owner/admin member) writes an `agency_verification_requests` row with the ID-document number + commercial-registration number stored via **Supabase Vault per ADR-0001** (admin-decrypt-only `app_vault_secret_for_agency`, mirroring the Phase 5 `app_vault_secret_for_user` helper `supabase/migrations/20260510120004`), plus document files in a private `agency-documents` storage bucket; an admin holding `agencies.approve` decides via a privileged path mirroring Phase 12 exactly — a `moderate_agency` Edge Function (`supabase/functions/moderate_agency/index.ts`, copying `approve_listing/index.ts`'s `parseJwtSub` → `jwtClient.rpc('current_user_has_permission')` → `adminClient.rpc('moderate_agency_internal')` skeleton) that gates per-action and invokes the service-role-only `moderate_agency_internal(p_agency_id, p_actor_user_id, p_action, p_reason_json)` RPC (reusing the Phase 12 `set_config('app.current_user_id')` GUC wrapper `supabase/migrations/20260523120005`); (f) the four lifecycle actions — `approve`/`reject` (gate `agencies.approve`), `suspend`/`reinstate` (gate `agencies.suspend`) — each audit-logged via the Phase 4 `log_audit()` trigger fn; (g) **soft-gate publishing** (Q1=A) — `submit_listing` (`supabase/migrations/20260522120004`, confirmed to NOT read `agency_id` today) is amended so that when a listing carries `agency_id`, the publisher MUST be an `active` member of that agency whose status ∈ {`pending`,`approved`}; the existing per-user publish gate (`publisher_status='approved'`, the `listings_insert_owner`/`listings_update_owner` RLS) is UNCHANGED — agency approval is NOT a second publish gate; (h) the verified-agency badge — `v_listings_public` (`supabase/migrations/20260525120002`) gains an additive `LEFT JOIN public.agencies … AND a.status='approved'` projecting `agency_id`/`agency_name`/`agency_logo_path`, and `PropertyCard` (`lib/core/widgets/property_card.dart`) + the Phase 13 `listing_details_page.dart` render the badge only for `approved` agencies; (i) a public `v_agencies` SECURITY DEFINER view (the Phase 18 `20260530120010` definer-scoping pattern) with an explicit `WHERE (a.status='approved' OR owner/active-member OR agencies.view)` so the public sees only approved agencies while an owner/member sees their own `pending` agency; (j) the agency frontend at `lib/features/agency/` (self-service: create/profile/members/listings/analytics/verification + pending-invitations) and `lib/features/admin/agencies/` (verification queue + decision flow), following the Clean-Architecture shape of `lib/features/admin/account_approvals/` (the closest approve/reject-queue precedent) and `lib/features/admin/listing_review/`; (k) routing — `/agency*` self-service routes (auth-gated like `/favorites`) + `/agency/:id` public profile + `/admin/agencies` gated by a new `requireAgenciesManageRedirect` (mirroring `requireReportsManageRedirect`); plus a "My Agency" Profile tile between "My Favorites" (`profile_page.dart:139-145`) and "My Reports" (`:147-153`); (l) ARB-driven localization for every new string. Phase 19 adds ZERO new pubspec dependencies (FR-037), ZERO new value to the listings status enum (FR-040), and makes ZERO change to `lead_events`. Principles I, III, IV, VII, and VIII are the load-bearing gates.

**Technical approach**: Agencies follow the same Clean Architecture layering as Phases 12–18 (`presentation/bloc` → `domain/usecases` → `domain/repositories` → `data/repositories` → `data/datasources` → `core/network`). Five security boundaries are load-bearing. First, the **public-vs-member-vs-admin read boundary** (Principle III + FR-029/FR-032): `v_agencies` is a SECURITY DEFINER view (the Phase 18 `20260530120010_fix_v_reports_definer_scoping.sql` precedent) with an explicit `WHERE (a.status='approved' OR a.owner_user_id = auth.uid() OR EXISTS(active membership) OR public.current_user_has_permission('agencies.view'))`, so anonymous/other users see only `approved` agencies while an owner/member sees their own at any status — the definer context is required because an invoker view INNER-JOINing or filtering would hide a member's own `pending` agency (the exact Phase 18 gotcha). Second, the **un-forgeable creation/membership boundary** (FR-039): `public.agencies`, `public.agency_members`, and `public.agency_verification_requests` grant NO client INSERT/UPDATE/DELETE (REVOKE-d, the Phase 18 `reports` precedent); creation flows through `create_agency` (SECURITY DEFINER, `owner_user_id := auth.uid()`), membership through `invite_agency_member`/`respond_agency_invitation`/`set_agency_member_role`/`remove_agency_member` (each binding `auth.uid()` and self-gating on the per-agency `member_role='admin'` row, or on being the invitee for accept/decline), and verification through `submit_agency_verification` — so no client can forge an owner, add itself to an agency, or fabricate a verification decision. Third, the **admin-only PII boundary** (ADR-0001 + Principle VIII + FR-005/FR-031): the ID-document number and commercial-registration number are stored via Supabase Vault (`app_vault_set_agency_secret`, mirroring `app_vault_set_secret_for_self`), never as plaintext columns and never projected by any view; only an `agencies.view`/`agencies.approve` holder can decrypt them via `app_vault_secret_for_agency` (the `current_user_is_admin()`-gated `app_vault_secret_for_user` precedent). Fourth, the **checks-at-both-ends moderation boundary** (Principle III + VII + FR-008/FR-039): the `moderate_agency` Edge Function rejects callers lacking the per-action permission (`agencies.approve` for approve/reject, `agencies.suspend` for suspend/reinstate) via the same `parseJwtSub → jwtClient.rpc('current_user_has_permission')` gate `approve_listing/index.ts` uses, AND `moderate_agency_internal` is `GRANT EXECUTE … TO service_role` only — so even a bypassed front-end cannot transition an agency. The internal RPC reuses the Phase 12 `set_config('app.current_user_id', …, true)` GUC trick so the agency audit trigger attributes the actor inside the one transaction. Fifth, the **soft-gate publish boundary** (Q1=A + FR-020): `submit_listing` is amended with an `IF v_listing.agency_id IS NOT NULL THEN … EXISTS(active membership of an agency in {pending,approved}) … END IF` check (the one place Phase 19 touches a Phase 10 RPC — a load-bearing integration check called out in R-143, like Phase 18's R-124); the existing per-user publish RLS is untouched. The badge is a pure presentation add over `v_listings_public` data that newly carries the approved-agency fields. The self-service UI mirrors the Phase 17/18 authenticated-route pattern; the admin verification queue mirrors `lib/features/admin/account_approvals/` (the approve/reject queue + cubit + usecases) and paginates via the Phase 13 cursor convention.

## Technical Context

**Language/Version**: Dart 3.9+ / Flutter 3.35.2 (existing); PostgreSQL 15 (Supabase) / PL/pgSQL; one Deno/TypeScript Edge Function (`moderate_agency`) mirroring the Phase 12 `approve_listing` runtime.

**Primary Dependencies**: NONE added in Phase 19 (FR-037). Agencies are built entirely from the inherited stack already in `pubspec.yaml`: `flutter`, `flutter_localizations`, `supabase_flutter`, `flutter_bloc`, `go_router`, `get_it`, `injectable`, `intl`, `cached_network_image`, `equatable`. The Edge Function reuses the `@supabase/supabase-js` import already used by `supabase/functions/approve_listing/index.ts`. Supabase Vault + Storage are already enabled (Phase 4 / Phase 11) — no new extension.

**Storage**: Supabase Postgres adds THREE new tables — `public.agencies`, `public.agency_members`, `public.agency_verification_requests` — under `supabase/migrations/`. `agencies.owner_user_id` references `auth.users(id)` `ON DELETE CASCADE` (UNIQUE — one agency per owner, Q3=A); `agency_members.agency_id` and `agency_verification_requests.agency_id` reference `public.agencies(id)` `ON DELETE CASCADE` (so deleting an owner cascades the whole agency, R-144); `agency_members.user_id`/`invited_by` and `agency_verification_requests.reviewed_by` reference `auth.users(id)` (`ON DELETE CASCADE` / `SET NULL`); the long-reserved `listings.agency_id` gains a FK to `public.agencies(id)` `ON DELETE SET NULL` (R-144 — a removed agency leaves its listings intact, losing only the badge). A new `agency_status` native enum (`pending`/`approved`/`rejected`/`suspended`) is created (NOT in `init_enums.sql`); `member_role`/membership `status`/verification `decision` use TEXT CHECK constraints (R-137). Phase 19 adds the agency-scoped Vault helpers (`app_vault_set_agency_secret`, `app_vault_secret_for_agency`), seven write RPCs (`create_agency`, `invite_agency_member`, `respond_agency_invitation`, `set_agency_member_role`, `remove_agency_member`, `submit_agency_verification`, `moderate_agency_internal`), one SECURITY DEFINER view (`v_agencies`), an additive amendment to `v_listings_public` (badge fields), an amendment to `submit_listing` (agency-membership validation), three `log_audit()` triggers, the RLS policies, and two Storage buckets (`agency-assets` public, `agency-documents` private). It makes ZERO change to `public.lead_events` and ZERO change to the `public.listings` status CHECK.

**Testing**: Per project convention (memory `feedback_no_new_tests.md`), no new automated tests are added in Phase 19. Existing tests remain. Manual UI verification on the reference Infinix Note 8 + Pixel 8 Pro AVD (memories `user_test_device.md` + `feedback_avd_acceptable_qa.md`) is the gate; `quickstart.md` captures the recipe — including the wire-level public/owner/member/admin/anon read-matrix capture (SC-009), the admin-only Vault-decrypt check (SC-010), the unauthorized-moderation rejection at both the Edge-Function and RPC layers (SC-011), and the publish-membership-validation check (SC-007).

**Target Platform**: Android only (Constitution Principle XI). Reference device: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10/11); Pixel 8 Pro emulator (Android 14, 412 dp width) for secondary checks.

**Project Type**: Mobile app (Flutter) + Supabase backend — existing layout per `lib/features/<feature>/{presentation,domain,data}/` and `supabase/{migrations,functions,docs}/`.

**Performance Goals**:

- Agency creation → localized confirmation within ~1 s after the RPC returns; agency + owner-member rows written within 2 s (SC-001).
- Admin verification queue + public agency directory + agency roster + agency Analytics all paginate / bound their queries (SC-015) — cursor query on indexed columns.
- Agency approval → public profile + verified badge appear within one refresh of the public surfaces (SC-004/SC-008); suspension removes them within one refresh (SC-005), with no code change.

**Constraints**:

- Public reads expose ONLY `approved` agencies' public profile fields + their approved listings; member rosters + verification material are member/admin-only; the ID-document/registration numbers are admin-decrypt-only and in NO client-readable view (FR-005/FR-029/FR-031/FR-032 + SC-009/SC-010). Enforced by RLS on all three tables, the SECURITY DEFINER `v_agencies` WHERE, and the Vault helpers.
- An agency MUST NOT be creatable with a forged `owner_user_id`, nor a roster mutated, nor a verification decided, by an unauthorized caller (FR-001/FR-016/FR-039 + SC-011/SC-012). Enforced by NO client INSERT/UPDATE/DELETE on the three tables, the SECURITY DEFINER write RPCs binding `auth.uid()`, the per-agency `member_role='admin'` self-gate, and the `moderate_agency` Edge-Function permission gate + service-role-only `moderate_agency_internal`.
- Publishing under an agency reuses the EXISTING per-user gate (FR-020, Q1=A) — agency approval is NOT a second publish gate; the ONLY new publish-path logic is the `submit_listing` membership validation (R-143 integration check). NO new listings status value (FR-040).
- Agency name is unique among `approved` agencies only (Q2-clarify + FR-025/FR-008): a partial unique index `WHERE status='approved'` + an approval-time collision check; duplicate `pending` names may coexist.
- Suspension blocks new agency publishing + hides the public profile/badge but does NOT mass-mutate the agency's listings (Q5 + FR-011 + SC-005).
- The admin surface MUST be gated by the data-driven `agencies.view`/`agencies.approve`/`agencies.suspend` permissions (frontend `PermissionChecker` + backend RLS/Edge-Function check); agency self-service MUST be gated by the per-agency `member_role` row — NEVER a hardcoded role branch (Principle VII + FR-038 + SC-014).
- Constitution IX-clean: no `package:supabase_flutter` import outside `lib/features/agency/data/` and `lib/features/admin/agencies/data/`. The `Agency`, `AgencyStatus`, `AgencyMember`, `AgencyMemberRole`, `AgencyMemberStatus`, `AgencyVerificationRequest` types live in `domain/` and import zero Supabase types.
- Constitution V (Arabic-first) + VI (design tokens): all new strings flow through ARB (`ar` + `en`); every new widget reads Phase 2 tokens — no inline hex/font/padding.
- The badge add MUST be surgical (FR-023): `PropertyCard` gains an OPTIONAL `agencyBadge` parameter and `listing_details_page.dart` mounts a badge widget only when the agency is `approved`; the Phase 13/17/18 CTAs (Favorite toggle, Share stub, Report CTA) MUST remain untouched.

**Scale/Scope**:

- 10 sub-phases (A–J) organized into 4 waves with parallel execution where the dependency graph permits.
- 13 new Supabase migrations under `supabase/migrations/` (timestamp prefix `20260531`, continuing after Phase 18's `20260530120012`): 3 tables (`…001`/`…002`/`…003`), 1 listings FK (`…004`), 1 policies + name-unique index (`…005`), 1 view + badge amendment (`…006`), 1 vault helpers (`…007`), 1 write RPCs (`…008`), 1 submit_listing amendment (`…009`), 1 moderation RPCs (`…010`), 1 audit triggers (`…011`), 1 advisor-hardening (`…012`), 1 storage buckets + policies (`…013`). Plus 1 new Edge Function `supabase/functions/moderate_agency/index.ts`. The IMPLEMENTATION_PLAN's logical names `0029`/`0030`/`0031` map to `…001`/`…002`/`…003` under the repo's timestamp convention.
- 2 Flutter feature areas: a new `lib/features/agency/` (self-service) and a new `lib/features/admin/agencies/` (verification). ~45 new Dart files. 6 existing files patched (`app_router.dart`, `auth_redirect.dart`, `profile_page.dart`, `admin_home_page.dart`, `property_card.dart`, `listing_details_page.dart`) + 2 listing-form files (`step_basics.dart`, `listing_form_bloc.dart`). ZERO new pubspec dependencies.
- ~40 new bilingual ARB keys (create/profile/members/invite/verify/analytics/badge/admin-queue/tiles) — final breakdown in Sub-Phase J.
- 19 plan-time research decisions (R-135 through R-153) resolved in `research.md`.
- 8 contract files in `contracts/`.

---

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `specs/019-agencies/spec.md` exists with 6 user stories, 41 FRs (FR-001..FR-041), 15 SCs, 7 clarifications resolved (3 in `/speckit-specify`: Q1 soft publish-gate, Q2 invite+accept, Q3 one-agency-per-approved-publisher; 4 in `/speckit-clarify`: member-management authorization = membership row, name unique-among-approved, owner-delete cascade, Vault = ID + registration numbers). This plan + data-model + contracts + quickstart land before any implementation. |
| II. Source-Controlled Backend | **Pass** | All backend artifacts (3 tables, 1 FK migration, 1 policies file, 1 view + badge amendment, 1 vault-helpers, 7 RPCs across 3 migrations, 1 submit_listing amendment, 3 audit triggers, 1 advisor-hardening, 1 storage migration with the `agency-assets` + `agency-documents` buckets + policies — **13 migrations `…001`–`…013`** — and 1 Edge Function) are checked in under `supabase/migrations/` + `supabase/functions/`; per-table docs land at `supabase/docs/agencies.md` + `agency_members.md` + `agency_verification_requests.md`. The Supabase MCP `apply_migration` applies them; the files are the source of truth. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | RLS enabled on all three new tables. Reads via the SECURITY DEFINER `v_agencies` view (public-approved OR owner/member OR `agencies.view`); no client INSERT/UPDATE/DELETE on any of the three tables (REVOKE-d). Creation/membership/verification via SECURITY DEFINER RPCs binding `auth.uid()`; moderation gated at BOTH the `moderate_agency` Edge Function (per-action `current_user_has_permission`) AND the service-role-only `moderate_agency_internal` RPC (Principle "checks at both ends"). ID-document/registration numbers Vault-stored, admin-decrypt-only. No service-role key on the client. All RPCs use `SET search_path`. |
| IV. Clean Architecture Flutter | **Pass** | `lib/features/agency/` and `lib/features/admin/agencies/` each use the standard 3 layers. Business rules (create-eligibility display, invite/accept flow, publish-under-agency selection, the four-action verification flow) live in `domain/` use cases + cubits/blocs. The admin verification queue mirrors the Phase 5 `lib/features/admin/account_approvals/` structure (`account_approvals_cubit.dart` → queue page + approve/reject usecases). |
| V. Arabic-First Localization | **Pass** | ~40 new strings land in BOTH `app_ar.arb` AND `app_en.arb` in Sub-Phase J. No inline `Text('...')` literals (grep gate in quickstart). Arabic copy is Syrian-friendly (e.g., "إنشاء مكتب" for Create agency, "بانتظار التوثيق" for Pending verification). |
| VI. Theme System & Design Tokens | **Pass** | The create/profile/members/verify pages, member tiles, invite sheet, verified badge, status chips, analytics counters, and the admin queue + decision dialogs all read `Theme.of(context).colorScheme` + `AppSpacing` + `AppRadii` + `AppTextStyles`. No inline hex/raw-font/ad-hoc padding. The Profile + admin tiles match existing token usage. |
| VII. Dynamic Roles & Permissions | **Pass** | The admin surface is gated by the data-driven `agencies.view`/`approve`/`suspend` permissions (`PermissionKeys.agenciesView/agenciesApprove/agenciesSuspend`) via `PermissionChecker.has(...)`/`any(...)` (frontend tile + route redirect) AND `current_user_has_permission(...)` (Edge Function + RLS). Agency self-service is gated by the per-agency `member_role='admin'` row, NOT a hardcoded role branch — verified by SC-014's grep gate. Every agency status change + roster change writes an `audit_logs` row via `log_audit()` (Principle VII audit mandate). |
| VIII. Approval Workflow & Publisher Identity | **Pass** | An agency becomes public + verified only after an `agencies.approve` admin approves it; rejection carries a reviewer reason surfaced to the owner (FR-009). The agency owner's private identity material (ID-document + registration numbers) is Vault-stored and decryptable ONLY by an `agencies.view` holder via `app_vault_secret_for_agency` (ADR-0001) — never a plaintext column, never in any client-readable view, never exposed to members or the public. Publishing still requires the individual's existing account+publisher approval (the soft gate preserves Principle VIII's per-user approval). |
| IX. Future Backend Portability | **Pass** | `Agency`, `AgencyStatus`, `AgencyMember`, `AgencyMemberRole`, `AgencyMemberStatus`, `AgencyVerificationRequest`, and the repository interfaces live in `domain/` and import zero Supabase types. Concrete Supabase access (RPC calls, view reads, the Edge-Function invocation, storage uploads) lives in `data/datasources/`. A grep gate in quickstart verifies no Supabase import under `domain/` or `presentation/`. |
| X. Testable AI Workflow | **Pass** | Every Phase 2 task (tasks.md, forthcoming) carries acceptance criteria derived from the FRs + SCs. `quickstart.md` captures one verification step per SC, including the wire-level read-matrix capture (SC-009), the admin-only Vault-decrypt check (SC-010), the dual-layer unauthorized-moderation rejection (SC-011), and the publish-membership-validation check (SC-007). The `/wave` orchestrator uses the Touch-fan notes below for conflict-free merge order. |
| XI. Android-First MVP | **Pass** | Zero new dependencies; zero new platform code. No iOS/Web/desktop. The agency pages are pure Flutter Material; the backend is standard Postgres + Vault + Storage + one Deno Edge Function matching the existing Phase 12 runtime. No Android manifest change. |
| XII. No Hidden Product Decisions | **Pass** | All 7 clarifications are recorded in `spec.md`'s Clarifications section with rationale. The 19 plan-time decisions (R-135..R-153) are recorded in `research.md`, including the items the spec resolved by documented default (member-management authorization model, suspension semantics, Vault field list, FK behaviors). Forward-stated deferrals (agency reporting, promoted/paid tier, ownership transfer, push notification of invites → Phase 22, cross-member inquiry inbox) are explicit in `spec.md` Assumptions + this plan. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

---

## Project Structure

### Documentation (this feature)

```text
specs/019-agencies/
├── plan.md                     # This file (/speckit-plan output)
├── spec.md                     # /speckit-specify + /speckit-clarify output (committed)
├── research.md                 # Phase 0 output (R-135..R-153)
├── data-model.md               # Phase 1 output (full SQL migration bodies + Dart entities + FR/SC verification map)
├── quickstart.md               # Phase 1 output (end-to-end manual recipe)
├── contracts/
│   ├── phase19-agencies-table.md
│   ├── phase19-agency-members-table.md
│   ├── phase19-agency-verification-requests-table.md
│   ├── phase19-agency-policies-and-v-agencies.md
│   ├── phase19-agency-write-rpcs.md
│   ├── phase19-moderate-agency-edge-function.md
│   ├── phase19-submit-listing-agency-amendment.md
│   └── phase19-agency-ui-and-entry-points.md
└── checklists/
    └── requirements.md         # /speckit-specify quality checklist (committed)
```

### Source Code (repository root)

```text
H:\alnujom-project\
├── lib/
│   ├── core/
│   │   ├── routing/
│   │   │   ├── app_router.dart                                       # UPDATE — add AppRoutes.agency*/adminAgencies (+ Names) + GoRoutes
│   │   │   └── auth_redirect.dart                                    # UPDATE — add requireAgenciesManageRedirect (mirrors requireReportsManageRedirect:129-138)
│   │   └── widgets/
│   │       └── property_card.dart                                    # UPDATE — optional agencyBadge param (no reflow when null)
│   ├── features/
│   │   ├── agency/                                                   # CREATE — self-service feature
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   └── supabase_agency_datasource.dart               # CREATE (create_agency, member RPCs, submit_verification, v_agencies reads, storage upload)
│   │   │   │   ├── dtos/
│   │   │   │   │   ├── agency_dto.dart                               # CREATE (v_agencies row shape)
│   │   │   │   │   └── agency_member_dto.dart                        # CREATE
│   │   │   │   └── repositories/
│   │   │   │       └── agency_repository_impl.dart                   # CREATE
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   ├── agency.dart                                   # CREATE (Agency entity)
│   │   │   │   │   ├── agency_status.dart                            # CREATE (enum pending/approved/rejected/suspended)
│   │   │   │   │   ├── agency_member.dart                            # CREATE
│   │   │   │   │   ├── agency_member_role.dart                       # CREATE (enum admin/agent)
│   │   │   │   │   ├── agency_member_status.dart                     # CREATE (enum pending/active/removed)
│   │   │   │   │   └── agency_verification_request.dart              # CREATE (+ decision enum)
│   │   │   │   ├── repositories/
│   │   │   │   │   └── agency_repository.dart                        # CREATE
│   │   │   │   └── usecases/
│   │   │   │       ├── create_agency.dart                            # CREATE
│   │   │   │       ├── load_my_agency.dart                           # CREATE
│   │   │   │       ├── update_agency_profile.dart                    # CREATE
│   │   │   │       ├── submit_agency_verification.dart               # CREATE
│   │   │   │       ├── load_agency_members.dart                      # CREATE
│   │   │   │       ├── invite_agency_member.dart                     # CREATE
│   │   │   │       ├── respond_agency_invitation.dart                # CREATE
│   │   │   │       ├── set_agency_member_role.dart                   # CREATE
│   │   │   │       ├── remove_agency_member.dart                     # CREATE
│   │   │   │       ├── load_my_agency_invitations.dart               # CREATE
│   │   │   │       ├── load_agency_listings.dart                     # CREATE
│   │   │   │       └── load_agency_analytics.dart                    # CREATE
│   │   │   └── presentation/
│   │   │       ├── bloc/  (or cubit/)
│   │   │       │   ├── agency_home_cubit.dart                        # CREATE (my-agency state: none/owner/member)
│   │   │       │   ├── agency_members_bloc.dart                      # CREATE (+ _state.dart)
│   │   │       │   ├── agency_verification_cubit.dart                # CREATE
│   │   │       │   ├── agency_invitations_cubit.dart                 # CREATE (pending invites + accept/decline)
│   │   │       │   ├── agency_listings_bloc.dart                     # CREATE (paginated)
│   │   │       │   └── agency_analytics_cubit.dart                   # CREATE
│   │   │       ├── pages/
│   │   │       │   ├── agency_home_page.dart                         # CREATE (stub in A; fills in H) — create OR manage
│   │   │       │   ├── agency_profile_page.dart                      # CREATE (public /agency/:id)
│   │   │       │   ├── agency_members_page.dart                      # CREATE
│   │   │       │   ├── agency_listings_page.dart                     # CREATE
│   │   │       │   ├── agency_analytics_page.dart                    # CREATE
│   │   │       │   └── agency_verification_page.dart                 # CREATE
│   │   │       └── widgets/
│   │   │           ├── agency_badge.dart                             # CREATE (verified badge — used by card/details)
│   │   │           ├── agency_status_chip.dart                       # CREATE
│   │   │           ├── agency_member_tile.dart                       # CREATE
│   │   │           ├── invite_member_sheet.dart                      # CREATE (phone + role)
│   │   │           └── publish_under_agency_field.dart              # CREATE (listing-form selector)
│   │   ├── admin/
│   │   │   ├── agencies/                                             # CREATE — admin verification feature
│   │   │   │   ├── data/
│   │   │   │   │   ├── datasources/
│   │   │   │   │   │   └── supabase_agencies_admin_datasource.dart   # CREATE (queue read + moderate_agency Edge Fn call + vault decrypt RPC)
│   │   │   │   │   ├── dtos/
│   │   │   │   │   │   └── agency_verification_item_dto.dart         # CREATE
│   │   │   │   │   └── repositories/
│   │   │   │   │       └── agencies_admin_repository_impl.dart       # CREATE
│   │   │   │   ├── domain/
│   │   │   │   │   ├── entities/
│   │   │   │   │   │   └── agency_verification_item.dart             # CREATE (queue row + decrypted id fields, admin-only)
│   │   │   │   │   ├── repositories/
│   │   │   │   │   │   └── agencies_admin_repository.dart            # CREATE
│   │   │   │   │   └── usecases/
│   │   │   │   │       ├── load_agency_verification_queue.dart       # CREATE
│   │   │   │   │       ├── approve_agency.dart                       # CREATE
│   │   │   │   │       ├── reject_agency.dart                        # CREATE
│   │   │   │   │       ├── suspend_agency.dart                       # CREATE
│   │   │   │   │       └── reinstate_agency.dart                     # CREATE
│   │   │   │   └── presentation/
│   │   │   │       ├── bloc/
│   │   │   │       │   ├── agency_queue_bloc.dart                    # CREATE (+ _state.dart, filters + pagination)
│   │   │   │       │   └── agency_moderation_cubit.dart              # CREATE
│   │   │   │       ├── pages/
│   │   │   │       │   ├── agency_queue_page.dart                    # CREATE (stub in A; fills in I)
│   │   │   │       │   └── agency_detail_page.dart                   # CREATE (review + decide)
│   │   │   │       └── widgets/
│   │   │   │           ├── agency_queue_card.dart                    # CREATE
│   │   │   │           └── agency_decision_dialog.dart               # CREATE (approve/reject/suspend/reinstate + confirm)
│   │   │   └── presentation/pages/
│   │   │       └── admin_home_page.dart                              # UPDATE — add Agencies tile (agencies.view)
│   │   ├── listing_form/
│   │   │   └── presentation/
│   │   │       ├── widgets/
│   │   │       │   └── step_basics.dart                              # UPDATE — host PublishUnderAgencyField
│   │   │       └── bloc/
│   │   │           └── listing_form_bloc.dart                        # UPDATE — carry agencyId + load memberships in attachContext
│   │   ├── listing_details/
│   │   │   └── presentation/pages/
│   │   │       └── listing_details_page.dart                         # UPDATE — render AgencyBadge for approved agencies
│   │   └── profile/
│   │       └── presentation/pages/
│   │           └── profile_page.dart                                 # UPDATE — add "My Agency" ListTile (between favorites:145 and reports:147)
│   └── l10n/
│       ├── app_ar.arb                                                # UPDATE — add ~40 Arabic keys
│       └── app_en.arb                                                # UPDATE — add same ~40 English keys
└── supabase/
    ├── migrations/
    │   ├── 20260531120001_create_agencies_table.sql                 # CREATE (agency_status enum + table + indices + updated_at trigger + RLS enable)
    │   ├── 20260531120002_create_agency_members_table.sql           # CREATE
    │   ├── 20260531120003_create_agency_verification_requests_table.sql  # CREATE
    │   ├── 20260531120004_enforce_listings_agency_fk.sql            # CREATE (FK + ON DELETE SET NULL)
    │   ├── 20260531120005_create_agency_policies.sql                # CREATE (RLS + REVOKE + name-among-approved unique index)
    │   ├── 20260531120006_create_v_agencies_view.sql                # CREATE (definer view + v_listings_public badge amendment)
    │   ├── 20260531120007_create_agency_vault_helpers.sql           # CREATE (app_vault_set_agency_secret + app_vault_secret_for_agency)
    │   ├── 20260531120008_create_agency_write_rpcs.sql              # CREATE (create_agency + member RPCs + submit_agency_verification)
    │   ├── 20260531120009_amend_submit_listing_agency_check.sql     # CREATE (agency-membership validation — R-143 integration check)
    │   ├── 20260531120010_create_agency_moderation_rpcs.sql         # CREATE (moderate_agency_internal, service-role only)
    │   ├── 20260531120011_create_agency_audit_triggers.sql          # CREATE (log_audit on agencies.status + agency_members + verification decision)
    │   ├── 20260531120012_phase19_advisor_hardening.sql             # CREATE
    │   └── 20260531120013_create_agency_storage.sql                 # CREATE (agency-assets public + agency-documents private buckets + policies)
    ├── functions/
    │   └── moderate_agency/
    │       └── index.ts                                             # CREATE (mirrors approve_listing/index.ts; per-action permission gate)
    └── docs/
        ├── agencies.md                                              # CREATE
        ├── agency_members.md                                        # CREATE
        └── agency_verification_requests.md                          # CREATE
```

**Structure Decision**: Phase 19 adds two new feature folders — `lib/features/agency/` (self-service: create, profile, members, listings, analytics, verification, pending-invitations, plus the publish-under-agency field + the verified badge) and `lib/features/admin/agencies/` (verification queue + decision flow), the latter sitting beside the Phase 5 `lib/features/admin/account_approvals/` and the Phase 12 `lib/features/admin/listing_review/` and mirroring their `data/{datasources,dtos,repositories}` + `domain/{entities,repositories,usecases}` + `presentation/{bloc,pages,widgets}` shape. The shared agency value objects (`AgencyStatus`, `AgencyMemberRole`, `AgencyMemberStatus`) and the `Agency`/`AgencyMember` entities live in `lib/features/agency/domain/entities/` and are imported by the admin feature (domain→domain value-object reuse; no Supabase coupling). Six existing files receive minimal entry-point patches (`app_router.dart` routes, `auth_redirect.dart` one redirect helper, `profile_page.dart` one tile, `admin_home_page.dart` one tile, `property_card.dart` one optional badge param, `listing_details_page.dart` one badge mount) plus the two listing-form files (`step_basics.dart` hosts the publish-under-agency selector, `listing_form_bloc.dart` carries `agencyId`). Thirteen new Supabase migrations land under `supabase/migrations/` (timestamp prefix `20260531`, continuing after Phase 18's `20260530120012`; the 13th, `…013`, creates the two Storage buckets + their policies). One Edge Function (`moderate_agency`) joins the existing `approve_listing`/`reject_listing`/`resolve_report` set. ZERO new pubspec dependencies.

---

## Phase Dependencies

> **User-mandated discipline (per /speckit-plan invocation)**: Every "Sub-Phase B depends on Sub-Phase A" line below names the specific file path OR exported symbol that B consumes from A. Lines like "easier in sequence" or "uses concepts from" are FORBIDDEN. The self-audit table at the end counts undeclared-consumer deps (target: zero).

### Sub-Phase A — Bootstrap: routes + redirect helper + shared domain enums/entities + stub pages

**Scope**:

1. `lib/core/routing/app_router.dart`: add `AppRoutes.agency = '/agency'`, `AppRoutes.agencyMembers='/agency/members'`, `AppRoutes.agencyListings='/agency/listings'`, `AppRoutes.agencyAnalytics='/agency/analytics'`, `AppRoutes.agencyVerify='/agency/verify'`, `AppRoutes.agencyProfile='/agency/:id'`, `AppRoutes.adminAgencies='/admin/agencies'` (+ matching `AppRouteNames`). Register the `/agency*` self-service routes with the authenticated redirect `authBloc.state is Unauthenticated ? AppRoutes.login : null` (the exact pattern the `/favorites` route uses at `app_router.dart:480-487` and `/reports` at `:489-497`), the public `/agency/:id` with no redirect, and a child `GoRoute(path:'agencies', name:AppRouteNames.adminAgencies, redirect: requireAgenciesManageRedirect, builder: … AgencyQueuePage())` under the existing `/admin` route (alongside `reports` at `:354-359`).
2. `lib/core/routing/auth_redirect.dart`: add `String? requireAgenciesManageRedirect(BuildContext, GoRouterState)` returning `'/admin?denied=agencies'` when `!getIt<PermissionChecker>().any([PermissionKeys.agenciesView, PermissionKeys.agenciesApprove, PermissionKeys.agenciesSuspend])` (mirrors `requireListingReviewRedirect` at `:112-124` which uses `.any([...])`).
3. Create the shared domain enums/entities under `lib/features/agency/domain/entities/`: `agency_status.dart` (`enum AgencyStatus { pending, approved, rejected, suspended }` + `wireValue`/`fromWire`), `agency_member_role.dart` (`{ admin, agent }`), `agency_member_status.dart` (`{ pending, active, removed }` + `isActive`), `agency.dart` (the `Agency` entity, `Equatable`, with the public-profile + status fields the v_agencies projection carries), `agency_member.dart`, and `agency_verification_request.dart` (+ a `VerificationDecision` enum).
4. Create stub `lib/features/agency/presentation/pages/agency_home_page.dart` and stub `lib/features/admin/agencies/presentation/pages/agency_queue_page.dart` (empty `Scaffold` + `AppBar`) so both routes resolve end-to-end before H/I fill them.

**In-spec deps**: none.

**Cross-phase deps**:

- A's `/agency*` redirects read `authBloc.state is Unauthenticated` where `Unauthenticated` is defined in `lib/features/auth/presentation/bloc/auth_state.dart` (Phase 5) — the exact pattern `app_router.dart:480-487` uses for `/favorites`.
- A's `requireAgenciesManageRedirect` consumes `PermissionKeys.agenciesView`/`agenciesApprove`/`agenciesSuspend` (`lib/core/security/permission_keys.dart:33-36`, Phase 6) and `getIt<PermissionChecker>().any(...)` (`lib/core/security/permission_checker.dart:42`, Phase 6).

**Touch fan**: `lib/core/routing/app_router.dart`, `lib/core/routing/auth_redirect.dart`, `lib/features/agency/domain/entities/agency_status.dart` (CREATE), `…/agency_member_role.dart` (CREATE), `…/agency_member_status.dart` (CREATE), `…/agency.dart` (CREATE), `…/agency_member.dart` (CREATE), `…/agency_verification_request.dart` (CREATE), `lib/features/agency/presentation/pages/agency_home_page.dart` (CREATE stub), `lib/features/admin/agencies/presentation/pages/agency_queue_page.dart` (CREATE stub).

---

### Sub-Phase B — Backend schema: 3 tables + `agency_status` enum + listings FK

**Scope**:

1. Migration `…001_create_agencies_table.sql`: `CREATE TYPE agency_status AS ENUM ('pending','approved','rejected','suspended')`; `public.agencies` per FR-024/FR-025 (`id` PK, `owner_user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE`, `name TEXT NOT NULL`, `description`, `phone`, `whatsapp`, `address`, `logo_path`, `cover_path`, `status agency_status NOT NULL DEFAULT 'pending'`, `created_at`, `updated_at`); the `set_updated_at()` BEFORE-UPDATE trigger (Phase 4 fn); indices `idx_agencies_status (status)`; `ENABLE ROW LEVEL SECURITY`.
2. Migration `…002_create_agency_members_table.sql`: `public.agency_members` per FR-026 (`agency_id UUID NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE`, `user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`, `member_role TEXT NOT NULL CHECK (member_role IN ('admin','agent'))`, `status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','active','removed'))`, `invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL`, `joined_at`, `created_at`, `updated_at`, PK `(agency_id,user_id)`); indices `idx_agency_members_user (user_id, status)`; `ENABLE ROW LEVEL SECURITY`.
3. Migration `…003_create_agency_verification_requests_table.sql`: `public.agency_verification_requests` per FR-027 (mirrors `account_approval_requests`: `id` PK, `agency_id UUID NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE`, `decision TEXT NOT NULL DEFAULT 'pending' CHECK (decision IN ('pending','approved','rejected'))`, `decision_reason TEXT`, `evidence_urls JSONB`, `submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL`, `submitted_at`, `reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL`, `reviewed_at`, the rejection-reason + reviewed-when-decided CHECK constraints from the account-approval template, `created_at`, `updated_at`); the `set_updated_at()` trigger; partial unique index `ux_agency_open_verification ON (agency_id) WHERE decision='pending'` (one open request per agency); `ENABLE ROW LEVEL SECURITY`. (The ID-document + registration numbers are NOT columns here — they go to Vault in Sub-Phase D.)
4. Migration `…004_enforce_listings_agency_fk.sql`: `ALTER TABLE public.listings ADD CONSTRAINT fk_listings_agency FOREIGN KEY (agency_id) REFERENCES public.agencies(id) ON DELETE SET NULL` (R-144). All existing listings have `agency_id = NULL` so the constraint validates instantly.
5. Create `supabase/docs/agencies.md` + `agency_members.md` + `agency_verification_requests.md` documenting columns, FK delete behaviors (R-144), the name-unique-among-approved rule (forward-stated, enforced in C), and the forward-stated RLS posture (populated by C).

**In-spec deps**: none.

**Cross-phase deps**:

- B's `agencies.owner_user_id`, `agency_members.user_id`/`invited_by`, `agency_verification_requests.*_by` reference `auth.users(id)` (Phase 1 Supabase baseline).
- B's `…004` FK targets the `agency_id` column on `public.listings` defined in `supabase/migrations/20260519120002_create_listings.sql:7` (Phase 10).
- B's `set_updated_at()` BEFORE-UPDATE trigger reuses the Phase 4 function (the same one `account_approval_requests` attaches at `20260510120001:50-54`).

**Touch fan**: `supabase/migrations/20260531120001_create_agencies_table.sql` (CREATE), `…002_create_agency_members_table.sql` (CREATE), `…003_create_agency_verification_requests_table.sql` (CREATE), `…004_enforce_listings_agency_fk.sql` (CREATE), `supabase/docs/agencies.md` (CREATE), `agency_members.md` (CREATE), `agency_verification_requests.md` (CREATE).

---

### Sub-Phase C — Backend policies + `v_agencies` view + `v_listings_public` badge amendment + audit triggers

**Scope**:

1. Migration `…005_create_agency_policies.sql`:
   - `agencies` SELECT policy `agencies_select_public_or_member_or_admin`: `USING (status='approved' OR owner_user_id = auth.uid() OR EXISTS(SELECT 1 FROM public.agency_members m WHERE m.agency_id = agencies.id AND m.user_id = auth.uid() AND m.status='active') OR public.current_user_has_permission('agencies.view'))` — and a parallel `TO anon` SELECT policy restricted to `status='approved'` (public marketplace, FR-032). `REVOKE INSERT, UPDATE, DELETE ON public.agencies FROM authenticated, anon` (writes via RPCs only).
   - `agency_members` SELECT policy: `USING (user_id = auth.uid() OR EXISTS(active membership of the same agency by the caller) OR public.current_user_has_permission('agencies.view'))` (the invitee reads their own pending row; active members read the roster; admins read all). `REVOKE INSERT, UPDATE, DELETE … FROM authenticated, anon`.
   - `agency_verification_requests` SELECT policy: `USING (EXISTS(admin membership of that agency by the caller) OR public.current_user_has_permission('agencies.view'))`. `REVOKE INSERT, UPDATE, DELETE … FROM authenticated, anon`.
   - Name-unique-among-approved (Q2-clarify, FR-025): `CREATE UNIQUE INDEX ux_agencies_name_approved ON public.agencies (lower(name)) WHERE status='approved'`.
2. Migration `…006_create_v_agencies_view.sql`:
   - `CREATE VIEW public.v_agencies AS SELECT a.id, a.owner_user_id, a.name, a.description, a.phone, a.whatsapp, a.address, a.logo_path, a.cover_path, a.status, a.created_at FROM public.agencies a WHERE a.status='approved' OR a.owner_user_id = auth.uid() OR EXISTS(active membership) OR public.current_user_has_permission('agencies.view')` — SECURITY DEFINER (the Phase 18 `20260530120010_fix_v_reports_definer_scoping.sql` precedent) so a member's own `pending` agency stays visible. `REVOKE ALL ON public.v_agencies FROM anon` is NOT applied — anon may read approved rows (the WHERE already restricts anon to `status='approved'` because `auth.uid()` is null and the membership/permission predicates are false). `GRANT SELECT ON public.v_agencies TO anon, authenticated`. NEVER projects Vault fields.
   - **Badge amendment**: `CREATE OR REPLACE VIEW public.v_listings_public AS … LEFT JOIN public.agencies ag ON ag.id = l.agency_id AND ag.status='approved' …` adding `ag.id AS agency_id, ag.name AS agency_name, ag.logo_path AS agency_logo_path` to the existing projection (`20260525120002_create_v_listings_public.sql` skeleton, additive only — the `WHERE l.status='approved'` and the price/main-image LATERAL joins are unchanged) so the badge data ships with the card query (FR-022).
3. Migration `…011_create_agency_audit_triggers.sql` (authored in C's scope but numbered after the RPCs for apply-order clarity):
   - `trg_agencies_audit_status AFTER UPDATE OF status ON public.agencies … WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION log_audit('agency.status_changed','status','id')`.
   - `trg_agency_members_audit AFTER INSERT OR UPDATE OF member_role,status OR DELETE ON public.agency_members … EXECUTE FUNCTION log_audit('agency_member.changed','member_role,status','agency_id')` (the §6.4 "Member adds / removes" audit).
   - `trg_agency_verification_audit AFTER UPDATE OF decision … EXECUTE FUNCTION log_audit('agency_verification.decided','decision,decision_reason,reviewed_by','id')` — reusing the Phase 4 `log_audit()` (`20260506120004`), actor from the `app.current_user_id` GUC set by `moderate_agency_internal` (E).
4. Update the three `supabase/docs/*.md` with the full RLS matrix + the `v_agencies` scoping contract + the audit-trigger note.

**In-spec deps**:

- C depends on Sub-Phase B — the `public.agencies`, `public.agency_members`, `public.agency_verification_requests` tables defined in `…001`/`…002`/`…003` MUST exist before C's policies attach, before `v_agencies` selects from `agencies`, before the badge join references `public.agencies`, and before the audit triggers attach.

**Cross-phase deps**:

- C's policies + `v_agencies` call `public.current_user_has_permission(perm_key text)` (Phase 6, `supabase/migrations/20260515120005_create_permission_predicate.sql`) — the same predicate the Phase 12/18 policies use.
- C's badge amendment edits `public.v_listings_public` (`supabase/migrations/20260525120002_create_v_listings_public.sql`, Phase 14) additively (LEFT JOIN — existing consumers unaffected).
- C's audit triggers consume the `log_audit()` trigger function from `supabase/migrations/20260506120004_create_audit_logs.sql` (Phase 4).

**Touch fan**: `supabase/migrations/20260531120005_create_agency_policies.sql` (CREATE), `…006_create_v_agencies_view.sql` (CREATE), `…011_create_agency_audit_triggers.sql` (CREATE), `supabase/docs/agencies.md` (UPDATE), `agency_members.md` (UPDATE), `agency_verification_requests.md` (UPDATE).

---

### Sub-Phase D — Backend write path: Vault helpers + create/member/verification RPCs

**Scope**:

1. Migration `…007_create_agency_vault_helpers.sql`: `public.app_vault_set_agency_secret(p_agency_id uuid, field_name text, p_value text)` (SECURITY DEFINER, self-gates that the caller is an `admin` member of `p_agency_id`, field allowlist `('id_document_number','commercial_registration_number')`, `secret_name := format('pii.agency.%s.%s', p_agency_id, field_name)`, `PERFORM vault.create_secret(p_value, secret_name, 'AlNujom agency PII')`) and `public.app_vault_secret_for_agency(p_agency_id uuid, field_name text) RETURNS TEXT` (SECURITY DEFINER, returns NULL unless `current_user_has_permission('agencies.view')`/`agencies.approve`, then `app_vault_secret(format('pii.agency.%s.%s', p_agency_id, field_name))`) — mirroring `app_vault_set_secret_for_self` / `app_vault_secret_for_user` (`20260510120004`).
2. Migration `…008_create_agency_write_rpcs.sql`:
   - `public.create_agency(p_name text, p_description text, p_phone text, p_whatsapp text, p_address text) RETURNS uuid` SECURITY DEFINER: `auth_required`; require `EXISTS(profiles WHERE user_id=auth.uid() AND publisher_status='approved' AND account_status='approved')` else `not_a_publisher`; require NOT `EXISTS(agencies WHERE owner_user_id=auth.uid())` else `already_owns_agency` (the UNIQUE is the race backstop); `INSERT INTO agencies(owner_user_id,name,…,status) VALUES (auth.uid(),…, 'pending') RETURNING id`; `INSERT INTO agency_members(agency_id,user_id,member_role,status,joined_at) VALUES (v_id, auth.uid(), 'admin','active', now())`. Granted to `authenticated`.
   - `public.invite_agency_member(p_agency_id uuid, p_phone text, p_role text) RETURNS uuid` SECURITY DEFINER: require the caller is an `admin` member of `p_agency_id` (`is_agency_admin(p_agency_id)` helper) else `permission_denied`; resolve `p_phone` → an existing `profiles.user_id` else `user_not_found`; `INSERT INTO agency_members(agency_id,user_id,member_role,status,invited_by) VALUES (…, 'pending', auth.uid()) ON CONFLICT (agency_id,user_id) DO NOTHING` returning the row (idempotent — `already_member`/`already_invited` surfaced by the no-op).
   - `public.respond_agency_invitation(p_agency_id uuid, p_accept boolean) RETURNS void` SECURITY DEFINER: `UPDATE agency_members SET status = CASE WHEN p_accept THEN 'active' ELSE 'removed' END, joined_at = CASE WHEN p_accept THEN now() END WHERE agency_id=p_agency_id AND user_id=auth.uid() AND status='pending'` (invitee-only — bound to `auth.uid()`).
   - `public.set_agency_member_role(p_agency_id uuid, p_user_id uuid, p_role text)` + `public.remove_agency_member(p_agency_id uuid, p_user_id uuid)` SECURITY DEFINER: require caller `admin` member of `p_agency_id`; forbid demoting/removing the owner (`p_user_id <> agencies.owner_user_id`).
   - `public.submit_agency_verification(p_agency_id uuid, p_id_document_number text, p_registration_number text, p_evidence_urls jsonb) RETURNS uuid` SECURITY DEFINER: require caller `admin` member; `INSERT INTO agency_verification_requests(agency_id, evidence_urls, submitted_by, decision) VALUES (p_agency_id, p_evidence_urls, auth.uid(), 'pending') RETURNING id` (the `ux_agency_open_verification` index blocks a second open request); then `PERFORM app_vault_set_agency_secret(p_agency_id,'id_document_number',p_id_document_number)` + same for `commercial_registration_number`.
   - Grants: all six → `authenticated` (each self-gates); `REVOKE ALL FROM PUBLIC`.

**In-spec deps**:

- D depends on Sub-Phase B — `create_agency` INSERTs `public.agencies` + `public.agency_members` (`…001`/`…002`); the member RPCs UPDATE `public.agency_members` (`…002`); `submit_agency_verification` INSERTs `public.agency_verification_requests` (`…003`) and relies on its `ux_agency_open_verification` index.

**Cross-phase deps**:

- D's `create_agency` reads `public.profiles.publisher_status`/`account_status` (Phase 5, `20260506120002`).
- D's Vault helpers call `vault.create_secret(...)` + the Phase 4 `app_vault_secret(...)` read helper (`20260510120004` / Phase 4 Vault scaffolding), and `public.current_user_has_permission(...)` (Phase 6).
- D's `invite_agency_member` resolves a phone against `public.profiles.phone` (Phase 5).

**Touch fan**: `supabase/migrations/20260531120007_create_agency_vault_helpers.sql` (CREATE), `…008_create_agency_write_rpcs.sql` (CREATE).

---

### Sub-Phase E — Backend moderation: `moderate_agency_internal` RPC + Edge Function + `submit_listing` amendment + advisor hardening

**Scope**:

1. Migration `…010_create_agency_moderation_rpcs.sql`: `public.moderate_agency_internal(p_agency_id uuid, p_actor_user_id uuid, p_action text, p_reason_json text DEFAULT NULL) RETURNS TABLE(agency_id uuid, status text)` SECURITY DEFINER `SET search_path = public, pg_temp` (the Phase 12 `20260523120005` wrapper). Body, one transaction: `PERFORM set_config('app.current_user_id', p_actor_user_id::text, true)`; validate `p_action ∈ ('approve','reject','suspend','reinstate')`; look up the agency (`agency_not_found`); guard the transition (`approve`/`reject` require current `status='pending'`; `suspend` requires `'approved'`; `reinstate` requires `'suspended'`) else `invalid_transition`; for `approve` → also reject with `name_taken` if another `approved` agency holds `lower(name)` (FR-008/FR-025); `UPDATE public.agencies SET status = CASE … END WHERE id=p_agency_id` (the `trg_agencies_audit_status` trigger fires); for `approve`/`reject` also `UPDATE public.agency_verification_requests SET decision=…, decision_reason = (p_reason_json::jsonb->>'detail'), reviewed_by=p_actor_user_id, reviewed_at=now() WHERE agency_id=p_agency_id AND decision='pending'` (the `trg_agency_verification_audit` trigger fires); `RETURN QUERY SELECT p_agency_id, <new status>`. Grant: `REVOKE ALL … FROM PUBLIC, anon, authenticated; GRANT EXECUTE … TO service_role` (exactly like `approve_listing_internal`).
2. Edge Function `supabase/functions/moderate_agency/index.ts` — a near-copy of `approve_listing/index.ts`: reuse `json()`, `UUID_RE`, `log()`, `parseJwtSub`; validate `{ agency_id, action ∈ {approve,reject,suspend,reinstate}, reason?: {preset, detail} }` (reject requires a reason, the `reject_listing` preset+detail pattern); `parseJwtSub` → build `jwtClient` → gate per-action: `current_user_has_permission('agencies.approve')` for `approve`/`reject`, `current_user_has_permission('agencies.suspend')` for `suspend`/`reinstate` → 403 on false; `adminClient.rpc('moderate_agency_internal', { p_agency_id, p_actor_user_id: jwtSub, p_action: action, p_reason_json: reason ? JSON.stringify(reason) : null })`; map `agency_not_found`→404, `invalid_transition`/`name_taken`→409, success→200.
3. Migration `…009_amend_submit_listing_agency_check.sql` — **R-143 load-bearing integration check**: `CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id uuid)` re-asserting the Phase 11 body verbatim PLUS, after the existing required-field validation and BEFORE the `UPDATE … status='pending_review'`, insert: `IF v_listing.agency_id IS NOT NULL THEN IF NOT EXISTS (SELECT 1 FROM public.agency_members m JOIN public.agencies a ON a.id=m.agency_id WHERE m.agency_id=v_listing.agency_id AND m.user_id=auth.uid() AND m.status='active' AND a.status IN ('pending','approved')) THEN RAISE EXCEPTION 'not_an_agency_member' USING ERRCODE='42501'; END IF; END IF;`. (Sub-Phase E's FIRST task is to read `20260522120004_amend_submit_listing_rpc_for_media_minimum.sql` and re-base this amendment on the latest body so no existing validation is dropped.)
4. Migration `…012_phase19_advisor_hardening.sql`: safety-net `ALTER FUNCTION … SET search_path` for all Phase 19 functions + re-assert grants (write RPCs + vault helpers → `authenticated`; `moderate_agency_internal` → `service_role`) + re-assert `REVOKE INSERT,UPDATE,DELETE ON public.agencies, public.agency_members, public.agency_verification_requests FROM authenticated, anon` + `GRANT SELECT ON public.v_agencies TO anon, authenticated`, matching the Phase 18 `20260530120008`/`…011` advisor-hardening pattern.
5. Migration `…013_create_agency_storage.sql`: create the `agency-assets` (public, `image/jpeg`, 5 MB) + `agency-documents` (private) Storage buckets + their policies — public read of approved-agency logos, agency-admin write via the `^[uuid]/.+$` path-shape + `is_agency_admin` predicate, and owner/`agencies.view` read of the private verification documents — mirroring `20260522120003` (full SQL in `data-model.md §1.13`). Depends on B's `public.agencies`/`public.agency_members` for the ownership predicates.

**In-spec deps**:

- E depends on Sub-Phase B — `moderate_agency_internal` UPDATEs `public.agencies` (`…001`) + `public.agency_verification_requests` (`…003`); the `submit_listing` amendment EXISTS-checks `public.agency_members` (`…002`) + `public.agencies` (`…001`).

**Cross-phase deps**:

- E's `moderate_agency_internal` reuses the `set_config('app.current_user_id', …, true)` GUC pattern from `supabase/migrations/20260523120005_approve_reject_atomic_wrappers.sql` (Phase 12) so the `trg_agencies_audit_status` + `trg_agency_verification_audit` triggers (Sub-Phase C) attribute the actor.
- E's Edge Function copies the `parseJwtSub` + `current_user_has_permission` gate + `adminClient.rpc(...internal)` structure from `supabase/functions/approve_listing/index.ts` (Phase 12).
- E's `submit_listing` amendment re-bases the existing `public.submit_listing(uuid)` body from `supabase/migrations/20260522120004_amend_submit_listing_rpc_for_media_minimum.sql` (Phase 10/11) and reads `public.agency_members`/`public.agencies` (B).

**Touch fan**: `supabase/migrations/20260531120009_amend_submit_listing_agency_check.sql` (CREATE), `…010_create_agency_moderation_rpcs.sql` (CREATE), `…012_phase19_advisor_hardening.sql` (CREATE), `…013_create_agency_storage.sql` (CREATE), `supabase/functions/moderate_agency/index.ts` (CREATE).

> **Integration risk (R-143)**: `submit_listing` is the ONLY existing Phase 10/11 RPC Phase 19 touches. The amendment MUST be a `CREATE OR REPLACE` that preserves every existing validation (profile-approval, ≥1 price, ≥1 image, residential rules) and only adds the agency-membership branch. The executor reads `20260522120004` first and re-bases — exactly the discipline Phase 18's R-124 applied to the listing-transition guard.

---

### Sub-Phase F — Agency self-service domain + data layer

**Scope**:

1. `lib/features/agency/domain/repositories/agency_repository.dart` — abstract interface returning `Result<T, Failure>`: `createAgency(...)`, `loadMyAgency()`, `updateProfile(...)`, `submitVerification(...)`, `loadMembers(agencyId)`, `inviteMember(agencyId, phone, role)`, `respondInvitation(agencyId, accept)`, `setMemberRole(...)`, `removeMember(...)`, `loadMyInvitations()`, `loadAgencyListings(agencyId, {cursor})`, `loadAnalytics(agencyId)`.
2. The 12 use cases at `lib/features/agency/domain/usecases/` (one per repository method, `@injectable`).
3. `lib/features/agency/data/dtos/agency_dto.dart` + `agency_member_dto.dart` (mirror the `v_agencies` + `agency_members` row shapes; `fromJson` + `toEntity()` mapping wire strings → `AgencyStatus`/`AgencyMemberRole`/`AgencyMemberStatus`).
4. `lib/features/agency/data/datasources/supabase_agency_datasource.dart`: `createAgency` → `rpc('create_agency', …)`; member ops → `rpc('invite_agency_member'/'respond_agency_invitation'/'set_agency_member_role'/'remove_agency_member', …)`; `submitVerification` → upload doc files to the `agency-documents` bucket then `rpc('submit_agency_verification', …)`; `loadMyAgency`/`loadMembers`/`loadMyInvitations`/`loadAgencyListings` → `from('v_agencies'/'agency_members'/'v_listings_public').select()…`; `loadAnalytics` → bounded count queries.
5. `lib/features/agency/data/repositories/agency_repository_impl.dart` mapping RPC errors (`not_a_publisher`, `already_owns_agency`, `user_not_found`, `permission_denied`, …) to `Failure`s.
6. Register the use cases + repository + datasource with `@injectable`/`@LazySingleton(as: AgencyRepository)`; regenerate `lib/core/di/injection.config.dart`.

**In-spec deps**:

- F depends on Sub-Phase A — the datasource/usecases type against `AgencyStatus`/`AgencyMemberRole`/`AgencyMemberStatus` + `Agency`/`AgencyMember` at `lib/features/agency/domain/entities/*.dart` (A).
- F depends on Sub-Phase C — `supabase_agency_datasource.dart` issues `select()` against `public.v_agencies` (`…006`) and `public.agency_members` gated by the policies in `…005` (C); `loadAgencyListings` reads the badge-augmented `v_listings_public` (`…006`).
- F depends on Sub-Phase D — `createAgency`/member ops/`submitVerification` invoke `public.create_agency` / `invite_agency_member` / `respond_agency_invitation` / `set_agency_member_role` / `remove_agency_member` / `submit_agency_verification` defined in `…007`/`…008` (D).

**Cross-phase deps**:

- F imports `package:alnujom/core/errors/result.dart` (`Result<T>`/`Success`/`FailureResult`, Phase 1) + `failure.dart` (Phase 1).
- F's storage upload uses the `agency-documents` private bucket (created by E's `…012`-adjacent storage migration — see note) via the `supabase_flutter` storage client.

**Touch fan**: `lib/features/agency/domain/repositories/agency_repository.dart` (CREATE), `lib/features/agency/domain/usecases/*.dart` (12 CREATE), `lib/features/agency/data/dtos/agency_dto.dart` (CREATE), `agency_member_dto.dart` (CREATE), `lib/features/agency/data/datasources/supabase_agency_datasource.dart` (CREATE), `lib/features/agency/data/repositories/agency_repository_impl.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase G — Admin agencies domain + data layer

**Scope**:

1. `lib/features/admin/agencies/domain/entities/agency_verification_item.dart` — the queue row (the `Agency` profile fields + the submitted `evidence_urls` + the admin-decrypted `idDocumentNumber`/`registrationNumber`, visible only to `agencies.view` holders).
2. `lib/features/admin/agencies/domain/repositories/agencies_admin_repository.dart`: `loadQueue({AgencyStatus? status, String? cursor})`, `loadDetail(agencyId)` (with decrypted Vault fields), `approve(agencyId)`, `reject(agencyId, reason)`, `suspend(agencyId, reason)`, `reinstate(agencyId)` — all `Result<T, Failure>`.
3. The 5 use cases at `lib/features/admin/agencies/domain/usecases/` (`load_agency_verification_queue`, `approve_agency`, `reject_agency`, `suspend_agency`, `reinstate_agency`).
4. `lib/features/admin/agencies/data/dtos/agency_verification_item_dto.dart` + `lib/features/admin/agencies/data/datasources/supabase_agencies_admin_datasource.dart`: `loadQueue`/`loadDetail` → `from('v_agencies').select()` + `from('agency_verification_requests').select()` + `rpc('app_vault_secret_for_agency', …)` for the decrypted id fields; `approve`/`reject`/`suspend`/`reinstate` → `functions.invoke('moderate_agency', body: {agency_id, action, reason?})`.
5. `lib/features/admin/agencies/data/repositories/agencies_admin_repository_impl.dart`.
6. Register with `@injectable`/`@LazySingleton`; regenerate DI config.

**In-spec deps**:

- G depends on Sub-Phase A — `AgencyStatus` + the `Agency` entity (`lib/features/agency/domain/entities/agency_status.dart`, `agency.dart`) are the filter + projection types on `loadQueue`/`loadDetail`/`AgencyVerificationItem`.
- G depends on Sub-Phase C — `supabase_agencies_admin_datasource.dart` reads `public.v_agencies` (`…006`) + `public.agency_verification_requests` gated by the `agencies.view` policy in `…005` (C).
- G depends on Sub-Phase E — `approve`/`reject`/`suspend`/`reinstate` invoke the `moderate_agency` Edge Function at `supabase/functions/moderate_agency/index.ts`, and `loadDetail` calls `public.app_vault_secret_for_agency(...)` defined in `…007` (D) — **G also depends on Sub-Phase D for the vault-read RPC**.

**Cross-phase deps**:

- G imports `package:alnujom/core/errors/result.dart` + `failure.dart` (Phase 1).
- G's `functions.invoke('moderate_agency', …)` uses the `supabase_flutter` functions client the same way Phase 12's admin datasource invokes `approve_listing`/`reject_listing`.

**Touch fan**: `lib/features/admin/agencies/domain/entities/agency_verification_item.dart` (CREATE), `lib/features/admin/agencies/domain/repositories/agencies_admin_repository.dart` (CREATE), `lib/features/admin/agencies/domain/usecases/*.dart` (5 CREATE), `lib/features/admin/agencies/data/dtos/agency_verification_item_dto.dart` (CREATE), `lib/features/admin/agencies/data/datasources/supabase_agencies_admin_datasource.dart` (CREATE), `lib/features/admin/agencies/data/repositories/agencies_admin_repository_impl.dart` (CREATE), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase H — Agency self-service presentation + entry wiring (Profile tile, pages, invitations, badge, publish-under-agency)

**Scope**:

1. Cubits/blocs (`@injectable`): `agency_home_cubit.dart` (none/owner/member state), `agency_members_bloc.dart` (+ `_state`), `agency_verification_cubit.dart`, `agency_invitations_cubit.dart` (pending invites + accept/decline), `agency_listings_bloc.dart` (paginated), `agency_analytics_cubit.dart`.
2. Pages: `agency_home_page.dart` (replaces A's stub — shows "Create agency" when none, the management surface when owner/member), `agency_profile_page.dart` (public `/agency/:id`), `agency_members_page.dart`, `agency_listings_page.dart`, `agency_analytics_page.dart`, `agency_verification_page.dart` (doc upload + ID/registration fields + status banner).
3. Widgets: `agency_status_chip.dart`, `agency_member_tile.dart`, `invite_member_sheet.dart` (phone + role), `agency_badge.dart` (name + logo, links to `/agency/:id`), `publish_under_agency_field.dart` (the listing-form selector).
4. **H1 — Profile "My Agency" tile**: `lib/features/profile/presentation/pages/profile_page.dart` — insert a `ListTile(leading: Icon(Icons.business_outlined), title: Text(l10n.profile_agency_tile), trailing: Icon(Icons.chevron_right), onTap: () => context.push(AppRoutes.agency))` immediately after the "My Favorites" `ListTile` (`:139-145`) and before the "My Reports" tile (`:147-153`).
5. **H2 — Listing card badge**: `lib/core/widgets/property_card.dart` — add an OPTIONAL `Widget? agencyBadge` (or `String? agencyName`/`agencyLogoPath`) parameter; render it in the existing card body only when non-null (no layout change when null, FR-023). The home/search card sites pass the `agency_name`/`agency_logo_path` from the badge-augmented `v_listings_public`.
6. **H3 — Details badge**: `lib/features/listing_details/presentation/pages/listing_details_page.dart` — mount `AgencyBadge(...)` in the title/contact region only when the loaded listing's agency is `approved` (the details datasource already selects `agency_id`; the agency name/logo come from `v_agencies` or the augmented details query).
7. **H4 — Publish under agency**: `lib/features/listing_form/presentation/widgets/step_basics.dart` — host `PublishUnderAgencyField` (a selector over "personal" + the user's active agencies in {pending,approved}) after the property-type field; `lib/features/listing_form/presentation/bloc/listing_form_bloc.dart` — load the user's active memberships in `attachContext` (`:106-112`) and carry the chosen `agencyId` into `draftListing` via `copyWith(agencyId: …)` (`listing.dart:268-301`) so the draft INSERT/UPDATE persists it; the server-side validation is E's `submit_listing` amendment.
8. Register the cubits/blocs; regenerate DI config.

**In-spec deps**:

- H depends on Sub-Phase A — `AgencyHomePage` is registered at `AppRoutes.agency` (constant in `app_router.dart` by A); the Profile tile (`AppRoutes.agency`), the `/agency/:id` profile route, and the agency enums/entities come from A.
- H depends on Sub-Phase F — the cubits inject `CreateAgency`/`LoadMyAgency`/`InviteAgencyMember`/`RespondAgencyInvitation`/`SubmitAgencyVerification`/`LoadAgencyListings`/`LoadAgencyAnalytics` (+ the rest) at `lib/features/agency/domain/usecases/*.dart` (F); pages render `Agency`/`AgencyMember` entities.
- H depends on Sub-Phase J — the create/profile/members/invite/verify/analytics/badge strings + `profile_agency_tile` are generated from the ARB keys by J.

**Cross-phase deps**:

- H1 imports `package:alnujom/core/routing/app_router.dart` for `AppRoutes.agency` — already imported in `profile_page.dart`.
- H2/H3 read the badge fields the augmented `v_listings_public`/`v_agencies` provide (C); `property_card.dart` (`lib/core/widgets/property_card.dart:17-134`) gains the optional param.
- H4 uses `ListingFormBloc.attachContext` (`listing_form_bloc.dart:106-112`) + `Listing.copyWith(agencyId:…)` (`listing.dart:268-301`) + the `ListingFormStep.basics` step (`listing_form_state.dart:42-50`) — all Phase 10 symbols.

**Touch fan**: `lib/features/agency/presentation/bloc/*.dart` (CREATE), `lib/features/agency/presentation/pages/*.dart` (CREATE; `agency_home_page.dart` UPDATE-from-stub), `lib/features/agency/presentation/widgets/*.dart` (CREATE), `lib/features/profile/presentation/pages/profile_page.dart` (UPDATE — My Agency tile), `lib/core/widgets/property_card.dart` (UPDATE — optional badge), `lib/features/listing_details/presentation/pages/listing_details_page.dart` (UPDATE — badge mount), `lib/features/listing_form/presentation/widgets/step_basics.dart` (UPDATE — publish-under-agency field), `lib/features/listing_form/presentation/bloc/listing_form_bloc.dart` (UPDATE — carry agencyId), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase I — Admin presentation (verification queue + decision flow + admin-home tile)

**Scope**:

1. `agency_queue_bloc.dart` (+ `_state`): `AgencyQueueOpened`/`FilterChanged(status?)`/`LoadMore`/`Refresh`; calls `LoadAgencyVerificationQueue` with cursor pagination (FR-007/SC-015).
2. `agency_queue_page.dart` replaces A's stub: `AppBar` (title `l10n.agencies_queue_title`) + status filter + paginated `ListView` of `AgencyQueueCard`s (agency name, owner, submitted-at); tapping a card → `agency_detail_page.dart`.
3. `agency_detail_page.dart` + `agency_moderation_cubit.dart` — show the agency profile + the decrypted ID/registration numbers (admin-only) + evidence docs, and the four actions opening `agency_decision_dialog.dart` (reject requires a reason; suspend requires the destructive confirmation per FR-010); on confirm calls `ApproveAgency`/`RejectAgency`/`SuspendAgency`/`ReinstateAgency`.
4. **I1 — admin-home Agencies tile**: `lib/features/admin/presentation/pages/admin_home_page.dart` — add `if (checker.has(PermissionKeys.agenciesView)) ListTile(leading: Icon(Icons.business_outlined), title: Text(l10n.admin_tile_agencies), trailing: Icon(Icons.chevron_right), onTap: () => context.push(AppRoutes.adminAgencies))` to the tiles list (mirroring the reports tile at `:69-75`).
5. Register the bloc/cubit; regenerate DI config.

**In-spec deps**:

- I depends on Sub-Phase A — `AgencyQueuePage` is registered at `AppRoutes.adminAgencies` (constant in `app_router.dart`, guarded by `requireAgenciesManageRedirect` in `auth_redirect.dart`) by A; the admin-home tile's `onTap` pushes `AppRoutes.adminAgencies` (A).
- I depends on Sub-Phase G — `AgencyQueueBloc` injects `LoadAgencyVerificationQueue`; `AgencyModerationCubit` injects `ApproveAgency`/`RejectAgency`/`SuspendAgency`/`ReinstateAgency` — all at `lib/features/admin/agencies/domain/usecases/*.dart` (G); pages render `AgencyVerificationItem` (G).
- I depends on Sub-Phase J — the queue title, filter labels, decision-action labels, reject-reason + suspend-confirmation copy, and `admin_tile_agencies` are generated from the ARB keys by J.

**Cross-phase deps**:

- I1 consumes `PermissionKeys.agenciesView` (`lib/core/security/permission_keys.dart:33-36`, Phase 6) + `getIt<PermissionChecker>().has(...)` (the same `checker.has(...)` pattern `admin_home_page.dart:69-75` uses for the reports tile).

**Touch fan**: `lib/features/admin/agencies/presentation/bloc/agency_queue_bloc.dart` (CREATE), `agency_queue_state.dart` (CREATE), `agency_moderation_cubit.dart` (CREATE), `lib/features/admin/agencies/presentation/pages/agency_queue_page.dart` (UPDATE-from-stub), `agency_detail_page.dart` (CREATE), `lib/features/admin/agencies/presentation/widgets/agency_queue_card.dart` (CREATE), `agency_decision_dialog.dart` (CREATE), `lib/features/admin/presentation/pages/admin_home_page.dart` (UPDATE — Agencies tile), `lib/core/di/injection.config.dart` (REGENERATED).

---

### Sub-Phase J — Localization: add ~40 bilingual ARB keys

**Scope**: Add the following key groups to BOTH `lib/l10n/app_ar.arb` AND `lib/l10n/app_en.arb`, then run `flutter gen-l10n`:

- Profile/admin tiles: `profile_agency_tile`, `admin_tile_agencies`.
- Create/profile: `agency_create_title`, `agency_name_label`, `agency_description_label`, `agency_phone_label`, `agency_whatsapp_label`, `agency_address_label`, `agency_logo_label`, `agency_create_button`, `agency_create_not_publisher`, `agency_already_owns`, `agency_profile_title`, `agency_edit_button`.
- Status labels: `agency_status_pending`, `agency_status_approved`, `agency_status_rejected`, `agency_status_suspended`.
- Members/invites: `agency_members_title`, `agency_invite_button`, `agency_invite_phone_label`, `agency_invite_role_label`, `agency_role_admin`, `agency_role_agent`, `agency_member_remove`, `agency_invite_user_not_found`, `agency_invite_already_member`, `agency_invitations_title`, `agency_invitation_accept`, `agency_invitation_decline`, `agency_invitation_pending_from`.
- Verification: `agency_verify_title`, `agency_verify_id_number_label`, `agency_verify_registration_label`, `agency_verify_documents_label`, `agency_verify_submit_button`, `agency_verify_submitted`, `agency_verify_rejected_reason`.
- Publish/badge/analytics: `listing_publish_under_agency_label`, `listing_publish_personal_option`, `agency_verified_badge`, `agency_analytics_title`, `agency_analytics_members`, `agency_analytics_listings`.
- Admin queue + decisions: `agencies_queue_title`, `agency_filter_status_label`, `agency_action_approve`, `agency_action_reject`, `agency_action_suspend`, `agency_action_reinstate`, `agency_reject_reason_label`, `agency_suspend_confirm_title`, `agency_suspend_confirm_body`, `agency_decision_success`.

Final count locked at sub-phase implementation time (~40 keys).

**In-spec deps**: none.

**Cross-phase deps**:

- J runs `flutter gen-l10n` which regenerates `lib/l10n/app_localizations.dart` (+ `_ar.dart`/`_en.dart`) — consumed by Sub-Phase H (create/profile/members/verify/badge/publish) and Sub-Phase I (queue, decisions, admin tile).

**Touch fan**: `lib/l10n/app_ar.arb` (UPDATE), `lib/l10n/app_en.arb` (UPDATE), `lib/l10n/app_localizations.dart` (REGENERATED), `app_localizations_ar.dart` (REGENERATED), `app_localizations_en.dart` (REGENERATED).

---

### Self-audit — undeclared consumer check

Total declared inter-sub-phase dependency edges: **16**. Every edge names the specific symbol or file path consumed (zero "easier in sequence" / "uses concepts from").

| From | To | Named consumer |
|------|-----|---------------|
| C | B | `public.agencies` / `public.agency_members` / `public.agency_verification_requests` in `…001`/`…002`/`…003` (policies attach; `v_agencies` selects `agencies`; badge join references `agencies`; audit triggers attach) |
| D | B | `public.agencies` + `public.agency_members` (`…001`/`…002`) and `public.agency_verification_requests` + `ux_agency_open_verification` (`…003`) (create/member/verification INSERT-UPDATE) |
| E | B | `public.agencies` (`…001`) + `public.agency_verification_requests` (`…003`) (moderation UPDATE); `public.agency_members` + `public.agencies` (`…001`/`…002`) (submit_listing membership EXISTS-check) |
| F | A | `AgencyStatus`/`AgencyMemberRole`/`AgencyMemberStatus`/`Agency`/`AgencyMember` at `lib/features/agency/domain/entities/*.dart` |
| F | C | `public.v_agencies` (`…006`) + the agency RLS policies (`…005`) + the badge-augmented `v_listings_public` (`…006`) |
| F | D | `public.create_agency` / `invite_agency_member` / `respond_agency_invitation` / `set_agency_member_role` / `remove_agency_member` / `submit_agency_verification` in `…007`/`…008` |
| G | A | `AgencyStatus` + `Agency` at `lib/features/agency/domain/entities/{agency_status,agency}.dart` |
| G | C | `public.v_agencies` (`…006`) + the `agency_verification_requests` `agencies.view` policy (`…005`) |
| G | D | `public.app_vault_secret_for_agency(uuid,text)` in `…007` (admin decrypt of id/registration numbers) |
| G | E | `moderate_agency` Edge Function at `supabase/functions/moderate_agency/index.ts` |
| H | A | `AppRoutes.agency`/`agencyProfile` in `lib/core/routing/app_router.dart`; the agency enums/entities at `lib/features/agency/domain/entities/*.dart` |
| H | F | `CreateAgency`/`LoadMyAgency`/`InviteAgencyMember`/`RespondAgencyInvitation`/`SubmitAgencyVerification`/`LoadAgencyListings`/`LoadAgencyAnalytics`/… at `lib/features/agency/domain/usecases/*.dart`; `Agency`/`AgencyMember` entities |
| H | J | generated getters in `lib/l10n/app_localizations.dart` (`profile_agency_tile`, `agency_create_title`, `agency_verified_badge`, `listing_publish_under_agency_label`, …) |
| I | A | `AppRoutes.adminAgencies` in `lib/core/routing/app_router.dart`; `requireAgenciesManageRedirect` in `lib/core/routing/auth_redirect.dart` |
| I | G | `LoadAgencyVerificationQueue`/`ApproveAgency`/`RejectAgency`/`SuspendAgency`/`ReinstateAgency` at `lib/features/admin/agencies/domain/usecases/*.dart`; `AgencyVerificationItem` entity |
| I | J | generated getters in `lib/l10n/app_localizations.dart` (`admin_tile_agencies`, `agencies_queue_title`, `agency_action_*`, `agency_suspend_confirm_*`, …) |

**Zero deps lack a named consumer.** Cross-phase deps (to Phase 1–18 artifacts) are listed separately under each sub-phase and similarly name the consumed file or symbol. Sub-Phases A, B, and J declare no in-spec predecessor (they are pure roots).

### Wave summary

| Wave | Sub-Phases | Parallelism | Conflict map |
|------|------------|-------------|--------------|
| 1 | A, B, J | 3 in parallel (no inter-deps). A touches `app_router.dart` + `auth_redirect.dart` + new `lib/features/agency/domain/entities/` + 2 stub pages. B touches `…001`–`…004` + the 3 `supabase/docs/*.md` (CREATE). J touches `app_{ar,en}.arb` + regenerates `app_localizations*.dart`. No two Wave-1 sub-phases share a file → zero intra-wave conflict. |
| 2 | C, D, E | 3 in parallel (all depend only on B from Wave 1). C touches `…005`/`…006`/`…011` + appends to the 3 docs. D touches `…007`/`…008`. E touches `…009`/`…010`/`…012`/`…013` + `supabase/functions/moderate_agency/index.ts` (the storage migration `…013` reads B's `public.agencies`/`public.agency_members` for its ownership predicates — a Wave-1→Wave-2 read dependency on table definitions, no file overlap). Shared files: the 3 `supabase/docs/*.md` (C appends — sequence C's append after B's create). **E re-bases `submit_listing` (`…009`) on the latest `20260522120004` body (R-143) — it does NOT edit the Phase 11 file, it `CREATE OR REPLACE`s in a new migration.** No migration-file overlap. |
| 3 | F, G | 2 in parallel (F dep A+C+D; G dep A+C+D+E). F touches new files under `lib/features/agency/{data,domain}/`. G touches new files under `lib/features/admin/agencies/{data,domain}/`. Both regenerate `lib/core/di/injection.config.dart` (generated — no manual merge; the `/wave` orchestrator regenerates once after both land). No source-file overlap. |
| 4 | H, I | 2 in parallel (H dep A+F+J; I dep A+G+J). H touches `lib/features/agency/presentation/` + `profile_page.dart` + `property_card.dart` + `listing_details_page.dart` + `step_basics.dart` + `listing_form_bloc.dart`. I touches `lib/features/admin/agencies/presentation/` + `admin_home_page.dart`. The six existing-file edits are spread across distinct feature folders with NO overlap between H and I. Both regenerate `injection.config.dart` (generated). |

Total wall-clock parallelism: 3× in Wave 1, 3× in Wave 2, 2× in Wave 3, 2× in Wave 4 — versus a naive sequential 10-step chain. The graph is wide because the two front-end feature areas (self-service vs. admin) are conflict-isolated (different folders + different existing-file edits), and the backend splits cleanly into independent migration files after the three tables land. The one shared backend touchpoint — `submit_listing` — is isolated to Sub-Phase E as a `CREATE OR REPLACE` in a new migration, so it never conflicts with the table/policy/RPC migrations.

> **Storage-migration placement note**: the `agency-assets` (public) + `agency-documents` (private) Storage buckets + policies are authored in Sub-Phase E (folded into `…010`/`…012` or a sibling `…013`) so the self-service upload (F) has a target; they depend on B's `public.agencies`/`public.agency_members` for the path-shape ownership predicate (the `^[uuid]/.+$` regex + membership EXISTS, mirroring `20260522120003`).

---

## Research Decisions (R-135..R-153)

See [research.md](research.md) for full per-decision rationale + rejected alternatives.

| ID | Decision area | Locked answer |
|----|--------------|--------------|
| R-135 | New dependencies | NONE — agencies use the inherited Flutter/BLoC/`go_router`/`supabase_flutter` stack + in-house Postgres tables + Vault + Storage + one Deno Edge Function reusing the Phase 12 runtime (FR-037). |
| R-136 | Three tables + FK | `public.agencies` + `public.agency_members` + `public.agency_verification_requests` per §6.2; enforce `listings.agency_id` FK. |
| R-137 | Enum vs CHECK | `agency_status` native ENUM (pending/approved/rejected/suspended); `member_role`/membership `status`/verification `decision` as TEXT CHECK (table-local, avoids ALTER TYPE friction). |
| R-138 | Create posture (Q3=A) | `create_agency` SECURITY DEFINER RPC; `publisher_status='approved'` eligibility; ONE agency per owner (UNIQUE `owner_user_id`); owner auto-seeded as `admin`/`active` member. |
| R-139 | Membership (Q2=B) | Invite + in-app accept; `agency_members.status` ∈ {pending,active,removed}; `invite`/`respond`/`set_role`/`remove` RPCs. |
| R-140 | Member-mgmt authorization | Per-agency `member_role='admin'` row (an `is_agency_admin(agency_id)` predicate), NOT the inert global `agency_admin` role; no global `agencies.manage*` key (spec clarification). |
| R-141 | Verification + Vault | `submit_agency_verification` RPC; ID-document + commercial-registration numbers Vault-stored, admin-decrypt-only via `app_vault_secret_for_agency`; document files in the private `agency-documents` bucket. |
| R-142 | Moderation posture | `moderate_agency` Edge Function (single fn, action param) + service-role-only `moderate_agency_internal` RPC (Phase 12 pattern); approve/reject gate `agencies.approve`, suspend/reinstate gate `agencies.suspend`. |
| R-143 | Soft publish gate (Q1=A) | Reuse the existing per-user publish RLS unchanged; the ONLY new logic is the `submit_listing` amendment validating agency membership + agency status ∈ {pending,approved}. **Integration check**: re-base the amendment on the latest `20260522120004` body so no validation is dropped. |
| R-144 | FK delete behaviors | `agencies.owner_user_id` `ON DELETE CASCADE`; `agency_members.agency_id` + `agency_verification_requests.agency_id` `ON DELETE CASCADE`; `listings.agency_id` `ON DELETE SET NULL`; member/verification `*_by` `ON DELETE SET NULL`. |
| R-145 | Name uniqueness | Unique among `approved` agencies only — partial unique index `ON (lower(name)) WHERE status='approved'` + an approval-time `name_taken` guard in `moderate_agency_internal` (spec clarification). |
| R-146 | Views | `v_agencies` SECURITY DEFINER + explicit owner/member/admin WHERE (the Phase 18 definer-scoping fix); `v_listings_public` additively LEFT-JOINs approved agencies for the badge fields. |
| R-147 | RLS posture | agencies: public-approved + owner/member + `agencies.view`; members: member + `agencies.view`; verification: agency-admin + `agencies.view`; no client write on any (RPC-only); anon reads only approved agency public profile. |
| R-148 | Storage | `agency-assets` (public, image/jpeg, 5 MB) for logos/cover; `agency-documents` (private, owner/admin only) for verification files — path-shape `agency_id/filename` mirroring `20260522120003`. |
| R-149 | Suspension effect (Q5) | Blocks new agency publishing + hides public profile/badge; does NOT mass-mutate the agency's listings; reinstate returns to `approved`. |
| R-150 | Migration timestamps | `20260531120001`–`…013` (13 migrations; `…013` = Storage buckets + policies; next-day prefix after Phase 18's `20260530120012`); Edge Function `moderate_agency`. |
| R-151 | Audit | Reuse the Phase 4 `log_audit()` on `agencies.status` + `agency_members` (add/remove/role) + `agency_verification_requests.decision`; actor via the `app.current_user_id` GUC set by `moderate_agency_internal`. |
| R-152 | Frontend structure | `lib/features/agency/` (self-service) + `lib/features/admin/agencies/` (verification) mirroring `lib/features/admin/account_approvals/` + `listing_review/`. |
| R-153 | Analytics | `AgencyAnalyticsPage` = minimal own-agency counters (member count + listing-by-status); richer analytics deferred to the Phase 20 admin dashboard. |

## Complexity Tracking

*Empty. All 12 Constitution principles pass. No violations require justification.*
