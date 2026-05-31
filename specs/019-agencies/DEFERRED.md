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
