# Deferred work — Phase 19 (Agencies)

Intentional gaps left at the end of the `/wave all --auto` implementation run, captured per the project's strict-task-completion convention (a partial task stays `- [ ]` with a `⚠️ PARTIAL` prefix in `tasks.md`; the gap is recorded here). The Phase 19 **core loop is complete and verified** (`flutter analyze` clean, 225/225 existing tests pass on every wave): create agency → submit verification → admin approve/reject/suspend/reinstate → invite + accept members → publish under agency (membership-gated) → verified badge on the **home feed + listing details**, with the full RLS/Vault security spine audited clean. The three items below are refinements on the verification UX and the search surface; each needs a small data-layer/backend addition and was out of the UI phase's reach.

| ID | Gap | Tasks | FR / SC | Status |
|----|-----|-------|---------|--------|
| D-1 | Search-results verified badge | T060 | FR-022 | Deferred |
| D-2 | Verification document **file** upload | T058 | FR-006, US1 AS#4 | Deferred |
| D-3 | Rejection-reason text shown to the owner | T058 | FR-009, US1 AS#5 | Deferred |

---

## D-1 — Verified badge on search results

**What ships**: the `PropertyCard` gained an optional badge param, and the **home feed** renders the verified-agency badge (the home query was amended to embed `agency:agencies(id,name,logo_path,status)` and render the badge for `approved` agencies). The **listing details** page also renders it (via `loadAgencyById`).

**What's deferred**: the **search-results** cards do not show the badge. Search is served by the `search_listings` RPC (`supabase/migrations/20260525120003_create_search_listings_rpc.sql`), which does NOT return the agency fields, so the search card has nothing to render.

**Remediation** (a thin backend + DTO change, ~1 small wave):
1. Amend `search_listings` to LEFT JOIN `public.agencies … AND status='approved'` and project `agency_id`/`agency_name`/`agency_logo_path` (mirroring the `v_listings_public` badge amendment in `20260531120006`).
2. Surface those fields in the search result DTO/model and pass them to the search card's `PropertyCard` badge param.

FR-022 is satisfied on the two primary surfaces (home + details); search is the remaining card surface.

## D-2 — Verification document file upload

**What ships**: `agency_verification_page.dart` collects the ID-document number + commercial-registration number and submits them (Vault-stored) via `submitVerification`; the status banner reflects the agency state. The backend is fully ready — the private `agency-documents` Storage bucket + its RLS exist (`20260531120013`), and `submitVerification` accepts an `evidenceUrls` list.

**What's deferred**: there is no UI path to actually **upload** document files. `AgencyRepository.submitVerification` takes pre-uploaded `evidenceUrls` (not file bytes); the datasource has an internal `uploadVerificationDocument` helper, but it is not exposed on the repository interface, so the page submits with `evidenceUrls = null`.

**Remediation**:
1. Expose `uploadVerificationDocument(agencyId, bytes, filename) → Result<String>` (returns the storage path) on `AgencyRepository` + impl (the datasource method already exists).
2. Add a file/image picker to `agency_verification_page.dart` (reuse the Phase 11 media-picker approach), upload each file to `agency-documents` at `<agencyId>/<filename>`, collect the paths, and pass them as `evidenceUrls` to `submitVerification`.

## D-3 — Rejection-reason text surfaced to the owner

**What ships**: when an admin rejects an agency, `moderate_agency_internal` writes the reviewer's reason to `agency_verification_requests.decision_reason`, and the owner sees `agency.status = 'rejected'`.

**What's deferred**: the owner does not see the **reason text** — the `Agency` entity carries only `status`, not the verification request's `decision_reason`, and there is no read to fetch it.

**Remediation**:
1. Add `loadMyVerificationRequest(agencyId) → Result<AgencyVerificationRequest?>` to `AgencyRepository` + impl + datasource (read the latest `agency_verification_requests` row — RLS already permits the agency-admin to read it).
2. On `agency_verification_page.dart`, when `agency.status == rejected`, display `request.decisionReason` (the `agency_verify_rejected_reason` ARB key already exists from Phase 10).

---

**Recommended sequencing**: a single small follow-up wave (D-2 + D-3 share the verification page and are pure data-layer-read + UI; D-1 is an independent search-RPC + DTO change). None blocks the rest of the v1 plan; revisit before the Phase 24 golden-path QA pass.

---

## Future enhancements (NEW — beyond the original Phase 19 scope)

These are new feature requests captured after Phase 19 shipped (not gaps in the delivered scope). Each is a separate future spec.

### FE-1 — Admin choice on suspend / removal: cascade listings vs. badge-only

**Requested**: 2026-05-31 (on-device QA walk), by the product owner.

**Today (Phase 19, R-149)**: suspending an agency hides its public profile + the verified badge and blocks *new* publishing, but **never touches the agency's existing listings** — they stay at whatever status they held (verified live on-device: A1 stayed `approved` after suspend). Owner-initiated agency *deletion* cascades the agency row and sets `listings.agency_id = NULL` (R-144), again without unpublishing the listings.

**Requested behavior**: when an admin **suspends** (and when an owner **removes/deletes**) an agency, present an explicit choice:
- **(A) Cascade the listings** — unpublish / take down ALL of the agency's listings (e.g. move `approved`→`paused` or a take-down status), or
- **(B) Badge-only** — keep the listings live and only drop the agency profile + verified badge (the current R-149 behavior).

**Touch points for the future spec**:
- `moderate_agency_internal` (the suspend transition) would take an extra `cascade_listings boolean` param and, when true, bulk-update `listings` where `agency_id = …` (deciding the target status + whether it is reversible on reinstate). This deliberately reverses the R-149 "no mass listing mutation" rule **only when the admin opts in**.
- The owner-delete path (R-144 cascade) would gain the same A/B choice before the `agencies` row is deleted.
- UI: a choice control in `AgencyDecisionDialog` (suspend) and in the owner's delete-agency confirmation.
- Audit: log the chosen mode + the count of listings mutated.
- Open question for the spec: is the cascade **reversible** on reinstate (restore prior statuses) or one-way? Reinstate currently only flips the agency back to `approved`.

---

## On-device QA findings — Infinix Note 8 walk, 2026-05-31

Bugs surfaced by the live click-path walk (the backend/RLS/Vault spine was correct throughout — every defect was in the Flutter data/presentation wiring, and none was caught by the wave's `flutter analyze` / grep gates). Fixes are in the working tree, pending a follow-up commit/PR (post-merge to `main`).

| # | Bug | Root cause | Fix | Status |
|---|-----|-----------|-----|--------|
| B-1 | Publishing under an agency never bound `agency_id` (listing submitted as personal) | `SaveFormStep.basics` / `saveBasicsStep` persisted only title/purpose/property_type — `agencyId` was dropped | Threaded `agencyId` through the use-case → repo interface → impl; the Basics save now writes the `agency_id` column (membership still gated at submit, R-143) | ✅ fixed + re-verified on device (listing "A1" bound to مكتب النجوم) |
| B-2 | Admin agency queue empty under every status filter; suspend/reinstate unreachable | `loadQueue` hard-coded `.eq('decision','pending')`, so the Approved/Rejected/Suspended chips (which filter `agencies.status`) could never match | A status filter now targets `agencies.status`; the pending-request gate applies only to the default (no-filter) queue | ✅ fixed + verified (approved agency now lists) |
| B-3 | Opening an approved/suspended agency in admin → "Something went wrong" | `AgencyDetailPage._loadDetail` reused the pending-only queue use-case + `firstWhere(id)` instead of the repository's `loadDetail` (which reads `v_agencies` for any status) | Page now calls `AgenciesAdminRepository.loadDetail(agencyId)` | ✅ fixed + verified (detail opens, suspend/reinstate work) |
| B-4 | An invitee can never reach Accept/Decline | The pending-invitation strip + Accept live only on `agency_members_page` (reachable only by an owner/active member). A pending-only invitee hits `AgencyHomeNone` → the create-agency form. No `AgencyHomeInvited` hub state. | NOT yet fixed — needs a new `AgencyHomeInvited` state on `agency_home_page` that surfaces `loadMyAgencyInvitations()` with Accept/Decline. Requires a second login to verify. | ⏳ to fix in follow-up |

**Also added during the walk (not a Phase 19 bug):** a publisher-only **"+" FAB on Home** (`home_page.dart`) — the app previously had no persistent entry to create a listing once the public feed was non-empty (the create button only renders on an empty feed). Kept as a real UX fix; revisit placement/design.

**Still outstanding from the original deferrals:** D-1 (search-results badge), D-2 (verification document file **upload** UI), D-3 (rejection-reason text shown to owner), plus **agency logo/cover upload UI** (same root cause as D-2 — no image-picker exists anywhere in the agency feature; the create form is name + contact only).
