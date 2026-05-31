# Quickstart — Agencies (manual verification recipe)

**Feature**: `specs/019-agencies/` | Reference device: Infinix Note 8 (480 dp) + Pixel 8 Pro AVD (412 dp). Run with `--dart-define-from-file=.env.json` (memory `project_dart_defines.md`). No new automated tests (memory `feedback_no_new_tests.md`) — this recipe is the gate.

## 0. Apply backend (Supabase MCP `apply_migration`, in order)

1. `20260531120001_create_agencies_table.sql`
2. `20260531120002_create_agency_members_table.sql`
3. `20260531120003_create_agency_verification_requests_table.sql`
4. `20260531120004_enforce_listings_agency_fk.sql`
5. `20260531120005_create_agency_policies.sql`
6. `20260531120006_create_v_agencies_view.sql`
7. `20260531120007_create_agency_vault_helpers.sql`
8. `20260531120008_create_agency_write_rpcs.sql`
9. `20260531120009_amend_submit_listing_agency_check.sql`  ← **first read `20260522120004` and re-base (R-143)**
10. `20260531120010_create_agency_moderation_rpcs.sql`
11. `20260531120011_create_agency_audit_triggers.sql`
12. `20260531120012_phase19_advisor_hardening.sql`
13. `20260531120013_create_agency_storage.sql`

Then deploy the `moderate_agency` Edge Function. Confirm `get_advisors` reports no new RLS/security-definer warnings beyond the expected `v_agencies` definer view (consistent with `v_reports`/`v_listings_public`). Verify Supabase Vault is enabled (Phase 4) before applying `…007`.

## 1. Fixtures

- pub-A, pub-B — approved publishers (`publisher_status='approved'`).
- usr-C — approved account, NOT a publisher.
- adm-AG — holds `agencies.view`+`agencies.approve`+`agencies.suspend` (the `admin` role).
- mod-X — holds `reports.manage` only (no `agencies.*`) — negative-control admin.
- ≥ 2 approved listings owned by pub-A.

## 2. Create agency + eligibility (SC-001)

1. Sign in as usr-C → Profile → "My Agency" → tap Create → `not_a_publisher` localized error; `SELECT count(*) FROM agencies` unchanged. ✓
2. Sign in as pub-A → "My Agency" → create (name "مكتب النجوم", contact, logo) < 60 s. `SELECT * FROM agencies WHERE owner_user_id=A` → one row `status='pending'`; `SELECT * FROM agency_members WHERE agency_id=… AND user_id=A` → `member_role='admin'`, `status='active'`. ✓ SC-001.
3. pub-A tries to create a 2nd agency → `already_owns_agency`. ✓

## 3. Submit verification + Vault (SC-002, SC-010)

1. pub-A → Agency → Verify → enter ID-document number + registration number + upload a document → submit. `SELECT * FROM agency_verification_requests WHERE agency_id=…` → one `decision='pending'` row; `evidence_urls` points into `agency-documents`. ✓
2. `pg_dump`-style / column scan: the ID number appears in NO plaintext column of `agencies`/`agency_verification_requests` and in NO `v_*` view. ✓ SC-002.
3. From adm-AG: `SELECT app_vault_secret_for_agency('<agency>','id_document_number')` → returns the number. From pub-A and from anon: same call → NULL / denied. ✓ SC-010.

## 4. Admin gating + verification queue (SC-003, SC-015)

1. Sign in as mod-X (no `agencies.*`) → admin home shows NO Agencies tile; navigate to `/admin/agencies` → redirected to `/admin?denied=agencies`; `select * from agency_verification_requests` → 0 rows. ✓
2. Sign in as adm-AG → admin home shows Agencies tile → queue lists the pending request (agency name + owner + submitted-at) and, on the detail screen, the decrypted ID/registration numbers. Inspect the query → `LIMIT`/cursor present. ✓ SC-003, SC-015.

## 5. Approve / reject / suspend / reinstate (SC-004, SC-005)

| action (adm-AG) | agency.status | verification.decision | audit_logs |
|-----------------|---------------|------------------------|------------|
| approve | `approved` | `approved` (reviewed_by/at set) | `agency.status_changed` + `agency_verification.decided` |
| reject (with reason) | `rejected` | `rejected` (decision_reason set, shown to owner) | both |
| suspend (confirm) | `suspended` | — | `agency.status_changed` |
| reinstate | `approved` | — | `agency.status_changed` |

- After **approve**: `/agency/:id` is publicly reachable (anon) and lists the agency's approved listings. ✓
- After **suspend**: reload the public profile + any card under the agency → profile + badge gone within one refresh; the agency's existing listings keep their status (`SELECT status FROM listings WHERE agency_id=…` unchanged). ✓ SC-005.
- Negative control: from mod-X, `functions.invoke('moderate_agency', …)` → 403; a direct `rpc('moderate_agency_internal', …)` from any client → permission denied (no grant). ✓ SC-011.
- `approve` a second agency that shares an approved agency's name → `name_taken` (R-145). ✓

## 6. Membership: invite + accept (SC-006)

1. pub-A (agency admin) → Members → Invite → enter pub-B's phone, role `agent` → `agency_members` row `status='pending'`. ✓
2. Invite an unregistered phone → `user_not_found`, no row. ✓
3. Sign in as pub-B → "My Agency" → pending invitation visible (no push needed) → Accept → row `status='active'`. Decline path → `removed`. ✓ SC-006.
4. pub-A sets pub-B's role to `admin`, then back to `agent`; tries to remove the owner → `cannot_remove_owner`. An `agent` (pre-promotion pub-B) attempting invite → `permission_denied`. ✓ (SC-012 forge checks: a direct `INSERT INTO agency_members …` from a client → denied; `create_agency` with a crafted `owner_user_id` is impossible — it binds `auth.uid()`.)

## 7. Publish under agency + badge (SC-007, SC-008)

1. As pub-B (now active member): open the listing form → step Basics shows "Publish under agency" with "personal" + "مكتب النجوم". Choose the agency, complete + submit → `SELECT agency_id FROM listings WHERE id=…` = the agency. ✓
2. As pub-A's NON-member friend (or a crafted `submit_listing` with that `agency_id`) → `not_an_agency_member`. ✓ SC-007.
3. As a publisher with no agency → no "Publish under agency" control; listing `agency_id=NULL`. ✓
4. Approve that listing (Phase 12) → anon home/details show the verified-agency badge (name + logo) linking to `/agency/:id`. Suspend the agency → reload → badge gone, layout unchanged. A listing under a `pending` agency shows no badge. ✓ SC-008.

## 8. Read-matrix isolation (SC-009)

- Anon `select * from v_agencies` → only `approved`; zero member/verification rows.
- pub-A `select * from v_agencies` → sees their own (even `pending`) agency; NOT pub-B's-owned agency if pending.
- A non-`agencies.view` authenticated user cannot read another agency's `agency_members` roster or any `agency_verification_requests` row. ✓ SC-009.

## 9. Analytics (SC-015)

1. pub-A → Agency → Analytics → member count + listing-by-status counts match the fixture; the queries are bounded and scoped to pub-A's agency only (no other agency's counters). ✓

## 10. Theme × locale (SC-013)

Walk the create/profile/members/invite/verify/analytics pages, the verified badge, the publish-under-agency selector, the admin queue + decision dialogs, and the Profile/admin tiles in all four combinations (light/dark × ar-RTL/en-LTR) on the 480 dp device and the 412 dp AVD — all strings localized, directionally correct, no overflow. ✓ SC-013.

## 11. Constitution grep gates (SC-014)

- `grep -R "package:supabase_flutter" lib/features/agency/domain lib/features/agency/presentation lib/features/admin/agencies/domain lib/features/admin/agencies/presentation` → zero (Principle IX).
- `grep -RE "role ?== ?'(agency_admin|admin)'" lib/features/agency lib/features/admin/agencies` → zero hardcoded role branches (Principle VII; authorization is `is_agency_admin` / `PermissionKeys.agencies*`).
- `git diff` shows NO new value in the `listings.status` CHECK and NO change to `lead_events`; `pubspec.yaml` carries no new dependency. ✓ SC-014.
