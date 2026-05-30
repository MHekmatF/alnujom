# Phase 0 Research — Agencies (R-135..R-153)

**Feature**: `specs/019-agencies/` | **Date**: 2026-05-30

All NEEDS-CLARIFICATION items from the Technical Context are resolved below. Each decision names the predecessor artifact it builds on so the plan's dependency graph stays auditable. The seven product-shaping clarifications (3 in `/speckit-specify`: Q1 soft publish-gate, Q2 invite+accept, Q3 one-agency-per-approved-publisher; 4 in `/speckit-clarify`: member-management authorization, name-unique-among-approved, owner-delete cascade, Vault field list) live in `spec.md`'s Clarifications section; this file records the *plan-time* (R-) decisions.

---

## R-135 — Zero new dependencies

**Decision**: Add NO new pubspec package and NO new Postgres extension. Agencies use the inherited Flutter/BLoC/`go_router`/`get_it`/`injectable`/`supabase_flutter` stack, three in-house Postgres tables, seven PL/pgSQL write RPCs + two Vault helpers + one moderation RPC, one SECURITY DEFINER view, an additive amendment to `v_listings_public`, an amendment to `submit_listing`, three audit triggers, two Storage buckets, and one Deno Edge Function reusing the `@supabase/supabase-js` import already present in `supabase/functions/approve_listing/index.ts`.

**Rationale**: FR-037 + Constitution XI. Supabase Vault + Storage are already enabled (Phase 4 / Phase 11); the agency pages are plain Material widgets; the moderation flow reuses the Phase 12 Edge-Function runtime.

**Alternatives rejected**: a third-party "organization/team" package (none Android-clean + Syria-safe + worth a dependency for a CRUD + invite flow).

---

## R-136 — Three tables + the listings FK

**Decision**: Create `public.agencies`, `public.agency_members`, and `public.agency_verification_requests` as separate tables per IMPLEMENTATION_PLAN §6.2, and enforce the long-reserved `listings.agency_id` foreign key.

**Rationale**: §6.2 specifies all three. Keeping the roster (`agency_members`) and the review request (`agency_verification_requests`) as separate tables matches the §6.4 read posture (members read the roster; only agency-admins/`agencies.view` read the verification request) and mirrors the Phase 5 `account_approval_requests` separation of the profile from its approval request.

**Alternatives rejected**: folding membership into a JSONB column on `agencies` (loses per-member RLS + the PK-enforced one-row-per-(agency,user)); folding the verification request into `agencies` (loses the admin-only review-material isolation + the re-submit history).

---

## R-137 — `agency_status` native enum; CHECK constraints elsewhere

**Decision**: `agencies.status` uses a new native `agency_status` ENUM (`pending`/`approved`/`rejected`/`suspended`). `agency_members.member_role` (`admin`/`agent`), `agency_members.status` (`pending`/`active`/`removed`), and `agency_verification_requests.decision` (`pending`/`approved`/`rejected`) use inline TEXT CHECK constraints.

**Rationale**: §6.3 lists the agency status as a first-class lifecycle enum and the Phase 5 `account_approval_status` is a native enum, so `agency_status` is a native enum for parity and self-documentation. The table-local role/membership/decision sets are small and inline CHECKs avoid `ALTER TYPE … ADD VALUE` friction (the same reason Phase 18 used TEXT CHECK for `reports.status`). `agency_status` is NOT in `supabase/migrations/20260506120001_init_enums.sql` and is created in `…001`.

**Alternatives rejected**: native enums for all four (more migration ceremony for no benefit on the small sets); TEXT CHECK for `agency_status` too (loses the §6.3 enum parity with `account_approval_status`); reusing `account_approval_status` for the verification `decision` (couples agency verification to the account-approval enum — rejected for decoupling).

---

## R-138 — Create-agency posture (Q3=A)

**Decision**: `public.create_agency(p_name, p_description, p_phone, p_whatsapp, p_address) RETURNS uuid` SECURITY DEFINER, granted to `authenticated`: requires `auth.uid()` + `publisher_status='approved' AND account_status='approved'` (else `not_a_publisher`); requires the caller owns NO agency yet (else `already_owns_agency`, with the `UNIQUE(owner_user_id)` as the race backstop); seeds the agency `status='pending'` with `owner_user_id := auth.uid()`; and seeds the owner as the first `agency_members` row (`member_role='admin'`, `status='active'`) in the same transaction.

**Rationale**: Q3=A. Reuses the existing publisher-approval signal (the `listings_insert_owner` gate at `20260519120002:66-76`), avoids introducing role-grant UX for the inert seeded `owner`/`agent` roles, and binds `owner_user_id` to `auth.uid()` so it cannot be forged (the Phase 16/17 `record_lead_event`/`add_favorite` SECURITY DEFINER posture).

**Alternatives rejected**: any approved account (Q3 Option B — pulls non-publishers into agency ownership); multiple agencies per owner (Q3 Option C — multi-agency-membership ambiguity); a client INSERT with a WITH-CHECK policy (cannot atomically seed the owner-member row + would still need the eligibility check in a trigger).

---

## R-139 — Membership: invite + in-app accept (Q2=B)

**Decision**: `invite_agency_member(p_agency_id, p_phone, p_role)` resolves `p_phone` to an existing `profiles.user_id` (else `user_not_found`) and creates an `agency_members` row at `status='pending'` (idempotent via the PK + `ON CONFLICT DO NOTHING`); `respond_agency_invitation(p_agency_id, p_accept)` (invitee-only, bound to `auth.uid()`) flips a `pending` row to `active` (accept) or `removed` (decline). The lifecycle is `pending` → `active` → `removed`.

**Rationale**: Q2=B. The invitee must consent before joining; the in-app pending-invitation surface (Sub-Phase H `agency_invitations_cubit`) is the discovery channel since push notifications are Phase 22. Resolving to an existing account mirrors the `auth.uid()`-bound posture of `add_favorite`/`submit_report`.

**Alternatives rejected**: immediate-active invite (adds people without consent); pre-staging unregistered phones (needs signup-time phone-linking + a Phase 22 notify channel that does not exist yet).

---

## R-140 — Member-management authorization = per-agency membership row

**Decision**: Authorization for `invite`/`set_role`/`remove`/profile-edit/verification-submit is the caller's own `agency_members` row with `member_role='admin'` for THAT specific agency — expressed as an `is_agency_admin(p_agency_id)` predicate (`EXISTS(SELECT 1 FROM agency_members WHERE agency_id=p_agency_id AND user_id=auth.uid() AND member_role='admin' AND status='active')`) inside each write RPC and in the `agency_members`/`agency_verification_requests` RLS. The seeded global `agency_admin` system role (`supabase/migrations/20260515120001_create_roles.sql:63`, permission-less) is NOT the gate and stays reserved/inert; no global `agencies.manage*` permission key is introduced.

**Rationale**: spec clarification (member-auth = membership row). Reconciles the IMPLEMENTATION_PLAN's "when the user has an agency-admin role" wording with the §6.4 "Agency admin (own agency)" row-scoped model; correctly scopes authority to one agency (a global key would let an admin act across all agencies).

**Alternatives rejected**: granting `agency_admin` a global `agencies.manage` key (cross-agency over-reach); a hybrid role-gates-UI/row-gates-data (the role adds nothing the membership row does not).

---

## R-141 — Verification submission + Vault-stored identity

**Decision**: `submit_agency_verification(p_agency_id, p_id_document_number, p_registration_number, p_evidence_urls)` (agency-admin only) inserts an `agency_verification_requests` row (`decision='pending'`, `evidence_urls` = the storage paths) and then stores the ID-document number + commercial-registration number via `app_vault_set_agency_secret(p_agency_id, field, value)` (Vault, `secret_name = 'pii.agency.{agency_id}.{field}'`). They are admin-decrypt-only via `app_vault_secret_for_agency(p_agency_id, field)` (returns NULL unless `current_user_has_permission('agencies.view')`/`agencies.approve`). Verification document FILES live in the private `agency-documents` Storage bucket (owner/admin read only). One open (`pending`) request per agency (`ux_agency_open_verification`).

**Rationale**: ADR-0001 (line 49 names agency verification IDs as Vault-backed) + Q4 (ID + registration numbers) + FR-005/FR-006/FR-031. Mirrors the Phase 5 `app_vault_set_secret_for_user`/`app_vault_secret_for_user` helpers (`20260510120004`) with an agency-scoped secret-name namespace.

**Alternatives rejected**: plaintext ID columns gated only by RLS (ADR-0001 rejects this for national-ID-level data); ID-number-only Vault scope (leaves the registration number exposed); all-fields-Vault (needless encrypt/decrypt overhead on non-identifying fields).

---

## R-142 — Moderation posture: Edge Function + service-role `moderate_agency_internal`

**Decision**: A single `moderate_agency` Edge Function (`supabase/functions/moderate_agency/index.ts`) takes `{ agency_id, action ∈ {approve,reject,suspend,reinstate}, reason? }`, JWT-gates per-action (`agencies.approve` for approve/reject, `agencies.suspend` for suspend/reinstate) via `current_user_has_permission`, then invokes the service-role-only `public.moderate_agency_internal(p_agency_id, p_actor_user_id, p_action, p_reason_json)` SECURITY DEFINER RPC.

**Rationale**: FR-008 + Principle III "checks at both ends" + Principle VII. The Phase 12 `approve_listing`/`reject_listing` Edge Functions (`supabase/functions/approve_listing/index.ts`) established this exact pattern; a single action-parameterized function (the Phase 18 `resolve_report` shape) is cleaner than four functions for four closely-related transitions. The service-role-only grant means a bypassed front-end cannot transition an agency (SC-011).

**Alternatives rejected**: four separate Edge Functions (more boilerplate for one gate each); a pure client RPC self-gating on `current_user_has_permission` (loses the second enforcement layer the constitution mandates); a direct client UPDATE under an admin RLS policy (cannot atomically update the agency + the verification request + fire the audit with actor attribution).

---

## R-143 — Soft publish gate (Q1=A) + the `submit_listing` integration check

**Decision**: Publishing under an agency reuses the EXISTING per-user publish RLS unchanged (`listings_insert_owner`/`listings_update_owner` at `20260519120002:66-94`, which gate on `publisher_status='approved' AND account_status='approved' AND auth.uid()=publisher_user_id`). The ONLY new publish-path logic is an amendment to `public.submit_listing(uuid)` (`20260531120009`): when the listing carries a non-null `agency_id`, require the publisher be an `active` member of that agency whose `status ∈ ('pending','approved')`, else `not_an_agency_member`. Agency approval is NOT a second publish gate.

**Rationale**: Q1=A + FR-020. Investigation confirmed `submit_listing` (`20260522120004_amend_submit_listing_rpc_for_media_minimum.sql`) does NOT read or persist `agency_id` today, so the membership validation is the one place Phase 19 must extend it. Because public read is already gated to `status='approved'`, a `pending` agency's member can publish immediately while the agency's badge/profile stay gated on `approved`.

**Integration check (load-bearing)**: the amendment MUST be a `CREATE OR REPLACE` that re-bases on the LATEST `submit_listing` body (`20260522120004`) and preserves every existing validation (profile approval, ≥1 price, ≥1 image, residential rules); it only ADDS the agency-membership branch before the `pending_review` UPDATE. Sub-Phase E's FIRST task is to read `20260522120004` and re-base — exactly the discipline Phase 18's R-124 applied to the listing-transition guard. This is the only existing Phase 10/11 RPC Phase 19 touches.

**Alternatives rejected**: a hard publish gate requiring the agency be `approved` (Q1 Option B — inert new agencies + an agency-status branch in the publish path); validating `agency_id` in the `listings` INSERT/UPDATE RLS only (a draft is never public, and `submit_listing` is the authoritative public-transition gate; the RLS WITH-CHECK is noted as optional defense-in-depth but not the primary gate).

---

## R-144 — FK delete behaviors (Q3 clarification)

**Decision**:
- `agencies.owner_user_id` — `NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE`.
- `agency_members.agency_id` — `NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE`; `agency_members.user_id` — `NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE`; `agency_members.invited_by` — `ON DELETE SET NULL`.
- `agency_verification_requests.agency_id` — `NOT NULL REFERENCES public.agencies(id) ON DELETE CASCADE`; `submitted_by`/`reviewed_by` — `ON DELETE SET NULL`.
- `listings.agency_id` — `REFERENCES public.agencies(id) ON DELETE SET NULL`.

**Rationale**: Q3 clarification (cascade-delete agency). Deleting the owner CASCADE-removes the agency, which cascades to its members + verification requests (no orphaned agency identity); `listings.agency_id` SET-NULLs so listings survive (losing only the badge). v1 has no hard-delete UI (accounts are suspended/soft-deleted), so this path is rarely exercised, but the constraint is defined for correctness.

**Alternatives rejected**: `ON DELETE RESTRICT` on the owner (needs an ownership-transfer step out of v1 scope); orphan-owner SET NULL on `owner_user_id` (conflicts with `NOT NULL` + needs reassignment UX); `listings.agency_id` CASCADE (would delete a listing when its agency is removed — loses the listing).

---

## R-145 — Agency name uniqueness among approved (Q2 clarification)

**Decision**: Agency name is unique among `approved` agencies only, enforced by a partial unique index `CREATE UNIQUE INDEX ux_agencies_name_approved ON public.agencies (lower(name)) WHERE status='approved'` PLUS an approval-time guard in `moderate_agency_internal`: an `approve` raises `name_taken` if another `approved` agency already holds `lower(name)`. Duplicate names may coexist while `pending`.

**Rationale**: spec clarification (unique-among-approved). Strengthens the trust/identity model (Principle VIII — prevents impersonation of a verified office) without blocking pending drafts. Suspending/rejecting an agency frees its name (the partial index excludes non-approved rows), and the approval-time guard gives a clean structured error before the index would otherwise raise a unique-violation.

**Alternatives rejected**: global uniqueness (too strict for pending drafts + re-applications); no uniqueness (invites impersonation, contradicts Principle VIII).

---

## R-146 — Views: `v_agencies` definer + `v_listings_public` badge amendment

**Decision**: `public.v_agencies` is a SECURITY DEFINER view (Postgres views with no security_invoker are definer by default; the explicit Phase 18 `20260530120010` pattern) projecting the agency PUBLIC profile fields with `WHERE (a.status='approved' OR a.owner_user_id=auth.uid() OR EXISTS(active membership) OR public.current_user_has_permission('agencies.view'))` — it NEVER projects the Vault ID fields. `public.v_listings_public` is amended additively to `LEFT JOIN public.agencies ag ON ag.id=l.agency_id AND ag.status='approved'`, projecting `agency_id`/`agency_name`/`agency_logo_path` for the verified badge.

**Rationale**: FR-022/FR-029. A definer view is required because an invoker view INNER-JOINing or filtering `agencies` would re-apply the agencies RLS and hide a member's own `pending` agency — the exact gotcha Phase 18 hit and fixed in `20260530120010` (recorded in memory `project_supabase_view_rls_gotchas`). The `v_listings_public` amendment is additive (LEFT JOIN, approved-only) so existing search/home consumers are unaffected and only listings under approved agencies carry the badge.

**Alternatives rejected**: SECURITY INVOKER `v_agencies` (drops a member's own pending agency); a separate `v_agency_badge` view (an extra round-trip per card — folding into `v_listings_public` ships the badge with the existing card query); reading `public.agencies` directly from the client for the badge (would need a permissive public read policy the definer view replaces).

---

## R-147 — RLS posture

**Decision**:
- `agencies` SELECT = `status='approved'` (public, incl. `anon`) OR `owner_user_id=auth.uid()` OR active-membership OR `agencies.view`; no client INSERT/UPDATE/DELETE (REVOKE-d — writes via RPCs + `moderate_agency`).
- `agency_members` SELECT = own row OR active-membership of the same agency OR `agencies.view`; no client write (REVOKE-d — writes via the member RPCs).
- `agency_verification_requests` SELECT = agency-admin of that agency OR `agencies.view`; no client write (REVOKE-d — INSERT via `submit_agency_verification`, decision via `moderate_agency_internal`).
- Vault ID fields: never in any view; admin-decrypt-only via `app_vault_secret_for_agency`.

**Rationale**: FR-029/FR-030/FR-031/FR-032 + §6.4. Mirrors the Phase 18 `reports`/`moderation_actions` REVOKE-all-writes posture; the definer `v_agencies` enforces the public/owner/member/admin read matrix at the wire (SC-009).

**Alternatives rejected**: a publisher/competitor-readable roster (FR leaks staff lists); an admin UPDATE policy enabling direct status change (loses atomicity + the dual-layer moderation gate).

---

## R-148 — Storage buckets

**Decision**: Two buckets (mirroring `20260522120002`/`20260522120003`): `agency-assets` (public read, `image/jpeg`, 5 MB) for logos/cover, owner/agency-admin write gated by a path-shape `^[uuid]/.+$` + agency-admin-membership EXISTS predicate; `agency-documents` (private, `public=false`) for verification files, readable only by the agency's owner/admins + `agencies.view` holders.

**Rationale**: FR-006/FR-033 + §6.5 (the plan lists `agency-assets` + `documents`). Logos are public (they appear on cards for approved agencies); verification documents are sensitive (admin/owner only).

**Alternatives rejected**: one combined bucket (mixes public logos with private documents — wrong access posture); reusing `listing-images` (wrong ownership predicate + mixes domains).

---

## R-149 — Suspension effect (Q5)

**Decision**: `suspend` transitions `approved → suspended`; this removes the agency from public reads (the `v_agencies` WHERE + the `v_listings_public` badge join both require `status='approved'`) and blocks NEW publishing under it (the `submit_listing` amendment requires agency status ∈ {pending,approved}); it does NOT mass-mutate the agency's existing listings. `reinstate` transitions `suspended → approved`.

**Rationale**: Q5 default. Avoids a bulk-listing-transition feature and surprise mass de-listing; mass handling of a suspended agency's listings is noted as possible Phase 20 admin-dashboard work.

**Alternatives rejected**: cascade-pause all of the agency's listings on suspend (a bulk-transition feature beyond Phase 19 scope); per-listing manual handling (more admin toil).

---

## R-150 — Migration timestamps + Edge Function name

**Decision**: Phase 19 migrations are `20260531120001`–`20260531120013` (13 migrations — the 13th, `…013`, creates the two Storage buckets + policies; next-day prefix after Phase 18's last applied migration `20260530120012`). The Edge Function is `moderate_agency`.

**Rationale**: The repo orders migrations by timestamp filename; a strictly-later prefix keeps `supabase db reset` deterministic and a fresh day prefix reads as a distinct phase (the Phase 18 R-133 convention).

**Alternatives rejected**: continuing the `20260530120013+` series (works, but a fresh day prefix reads more clearly).

---

## R-151 — Audit

**Decision**: Reuse the Phase 4 `log_audit()` trigger function (`20260506120004`) via three triggers: `trg_agencies_audit_status` (`AFTER UPDATE OF status`, action `agency.status_changed`), `trg_agency_members_audit` (`AFTER INSERT OR UPDATE OF member_role,status OR DELETE`, action `agency_member.changed`), `trg_agency_verification_audit` (`AFTER UPDATE OF decision`, action `agency_verification.decided`). Actor attribution comes from the `app.current_user_id` GUC set by `moderate_agency_internal` (for status/decision changes) and from `auth.uid()` resolved by `log_audit` for member changes.

**Rationale**: §6.4 ("agencies … Audit-logged: Status changes"; "agency_members … Member adds / removes") + Principle VII. Reusing `log_audit()` (the same trigger `account_approval_requests` uses at `20260510120005`) avoids a parallel audit mechanism (FR-012/FR-041).

**Alternatives rejected**: explicit `INSERT INTO audit_logs` inside each RPC (duplicates the trigger logic + diverges from the established convention).

---

## R-152 — Frontend structure

**Decision**: A new self-service feature `lib/features/agency/` (create/profile/members/listings/analytics/verification + pending-invitations + the publish-under-agency field + the verified badge) and a new admin feature `lib/features/admin/agencies/` (verification queue + decision flow), each with the standard `data/`+`domain/`+`presentation/` layers. The shared value objects/entities live in `lib/features/agency/domain/entities/` and are imported by the admin feature.

**Rationale**: FR-038 + Constitution IV. The admin verification queue is the same shape as the Phase 5 `lib/features/admin/account_approvals/` (a pending queue + approve/reject usecases + a cubit) — the closest existing precedent — and the Phase 12 `lib/features/admin/listing_review/`.

**Alternatives rejected**: a single combined feature folder (mixes the public self-service surface with the privileged admin surface — the repo keeps these split, e.g., `reports/` vs `admin/reports/`).

---

## R-153 — Agency analytics scope

**Decision**: `AgencyAnalyticsPage` shows minimal own-agency counters — member count + listing counts by status — via bounded count queries scoped to the caller's agency. No cross-agency data; no time-series.

**Rationale**: §10 lists `AgencyAnalyticsPage` (counters); FR-034 + SC-015 require bounded, own-agency-only queries. The Phase 20 admin dashboard owns cross-cutting/time-series counters.

**Alternatives rejected**: rich time-series analytics (beyond v1 scope + the dashboard's remit); deferring the page entirely (the §10 deliverable lists it — a minimal counters page satisfies it cheaply).
