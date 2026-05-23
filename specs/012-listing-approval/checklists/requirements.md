# Specification Quality Checklist: Listing Approval Workflow

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-23
**Last validated**: 2026-05-23 (post-`/speckit-clarify` — 8 clarifications resolved across two passes; 5-question quota for `/speckit-clarify` exhausted)
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

> Note on content quality: This spec follows the Phase 10 / Phase 11 precedent of citing specific database object names, Edge Function paths, and table column names. Downstream spec-kit workflow (`research.md`, `data-model.md`, `contracts/`) consumes these names verbatim. User-value framing is preserved at the User Story layer.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain *(3 questions resolved in-session on 2026-05-23)*
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic *(SC items reference observable outcomes — SQL row counts, HTTP responses, UI affordances, file paths — verifiable via the established SQL + manual-device verification surface)*
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded *(Scope note demarcates Phase 12 from Phases 10, 11, 13, 14, 17, 22, 23)*
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification *(same caveat as Content Quality — DB object names + Edge Function paths cited follow Phase 10/11 precedent)*

## Clarifications Log

**Session 2026-05-23 (during `/speckit-specify`) — RESOLVED**:

- **Q1 = B** — Edge Function pattern (follow IMPLEMENTATION_PLAN §6.7). Two new Edge Functions at `supabase/functions/approve_listing/index.ts` AND `supabase/functions/reject_listing/index.ts`. Hard reversal of Phase 11 R-36 invariant ("zero new Edge Functions"). Justified by §6.7 mandate + future-spec Phase 17/22 notification fan-out.
- **Q2 = A** — Default `expires_at = NULL` on approval. Approved listings remain publicly visible indefinitely. No expiry, no renewal UX in v1. Phase 14 "exclude expired" filter is a no-op until a future spec adds auto-expiry.
- **Q3 = A** — Minimal-5 + Other preset taxonomy. Six reject-preset keys: `missing_or_low_quality_photos`, `incorrect_location`, `unrealistic_price`, `incomplete_description`, `duplicate_listing`, `other`. Deliberately diverges from §6.3 `report_reason` enum to keep publisher-actionable presets focused on what the publisher can fix.

**Session 2026-05-23 (during `/speckit-clarify`) — RESOLVED**:

- **Q4 = A** — Rejection-reason storage representation: JSON-encoded TEXT in the existing Phase 10 `listing_status_history.reason TEXT` column. Shape `{"preset":"<key>","detail":"<string>|null}`. No schema migration. Forward-compatible with a later JSONB conversion. Sidecar table and delimited TEXT rejected. FR-002 step (g) + FR-003 + SC-027 capture the canonical write/read paths.
- **Q5 = A** — "Other" preset UX required-ness: UX disables Confirm when (`preset='other' AND detail.trim().length === 0`); server contract stays permissive (no Edge Function validator added). Every Phase-12-UI rejection where preset='other' carries non-empty detail. FR-013(d)+(f) capture the gate; SC-028 verifies.
- **Q6 = A** — Edge Function per-action latency target: ≤ 2 seconds p95 per `approve_listing` / `reject_listing` invocation, measured at the admin device, verifiable via Supabase Edge Function logs `duration_ms`. Cold-start tail acknowledged outside p95. No keep-warm or dedicated-tier engineering in Phase 12. SC-029 verifies.
- **Q7 = A** — Status-transition trigger `changed_by` source from Edge Function: session variable + amend Phase 10 trigger AND Phase 4 `log_audit()` via a new Phase 12 migration (`CREATE OR REPLACE FUNCTION`; original Phase 10/4 files unedited per R-35). Trigger + `log_audit()` source actor via `coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid())`. R-05 invariant narrowly relaxed to "byte-identical except for actor-source COALESCE". FR-024 captures the contract; SC-030 + SC-031 verify.
- **Q8 = A** — Listing-preview shared-widget location: Phase 12 ships five pure-render display widgets under `lib/shared/presentation/widgets/listing_display/` (`listing_gallery.dart`, `listing_price_block.dart`, `listing_location_block.dart`, `listing_amenities_block.dart`, `listing_description_block.dart`). Phase 13 imports verbatim; no second implementation, no drift. FR-011 captures the contract; SC-032 verifies.

## Sections Touched

**During `/speckit-specify`** (Q1/Q2/Q3): `Status`, `Scope note`, `Clarifications` (Q1/Q2/Q3 resolved + folded-defaults), every User Story (US1–US6), `Edge Cases`, `FR-001`, `FR-002`, `FR-003`, `FR-013`, `FR-018`, `Key Entities` (RejectionReasonPreset enumerated), `SC-022`, `SC-023`, `SC-024`, `Assumptions` (Edge Function deployment story, R-36 reversal, no `expires_at` autopopulation).

**During `/speckit-clarify`** (Q4/Q5/Q6/Q7/Q8): `Clarifications` (Q4 through Q8 resolved; folded-defaults renamed from Q-prefix to "Folded default —" prefix), `FR-001(e)+(f)`, `FR-002(g)+(h)`, `FR-003` (Q4=A storage rep pinned), `FR-011` (Q8=A widget paths pinned), `FR-013(c)+(d)+(f)` (Q5=A UX gate added), `FR-024` (new — Q7=A trigger amendment), US4 acceptance scenario 3 (R-05 invariant relaxed), `SC-005` (R-05 narrow-relaxation language), `SC-027` (new — Q4=A storage verification), `SC-028` (new — Q5=A "Other" detail-required), `SC-029` (new — Q6=A latency budget), `SC-030` (new — Q7=A trigger / log_audit attribution), `SC-031` (new — Q7=A Phase 10/4 file immutability), `SC-032` (new — Q8=A widget file inventory), `Assumptions` (R-05 narrow-relaxation note).

## Coverage Summary (post-clarify, after 5-question quota)

| Taxonomy category | Status |
|---|---|
| Functional Scope & Behavior | **Clear** |
| Domain & Data Model | **Resolved** (Q4=A storage rep pinned; FR-003 + SC-027 verify) |
| Interaction & UX Flow | **Resolved** (Q5=A "Other"-required-when-empty UX gate codified; FR-013 + SC-028 verify) |
| Performance | **Resolved** (Q6=A ≤ 2 seconds p95 latency budget; SC-029 verifies) |
| Reliability & availability | **Clear** (last-writer-wins with status-guard; structured error responses; transaction rollback on audit failure) |
| Observability | **Resolved** (Q7=A trigger + log_audit attribution via session variable; SC-030 verifies correct admin UID on every audit row) |
| Security & privacy | **Clear** (Edge Function permission re-check on JWT-bound client; service-role client only after permission passes; admin identity NOT exposed in publisher UI; session variable scoped to transaction only) |
| Compliance | **Clear** |
| Integration & External Dependencies | **Resolved** (Q1=B Edge Function; Q8=A shared widget paths) |
| Edge Cases & Failure Handling | **Clear** |
| Constraints & Tradeoffs | **Clear** (R-36 reversal acknowledged; R-05 narrowly relaxed per Q7=A) |
| Terminology & Consistency | **Clear** |
| Completion Signals | **Clear** (32 SCs, all verifiable) |
| Misc / Placeholders | **Clear** (zero TODO / NEEDS CLARIFICATION) |

## Notes

- All 8 clarifications resolved (3 during `/speckit-specify`, 5 during `/speckit-clarify`). Spec is ready for `/speckit-plan`.
- 5-question `/speckit-clarify` quota fully consumed in this session.
- Plan-time research file (`research.md`) MUST codify: (a) the exact migration filename + SQL diff for FR-024's amendment of Phase 10's status-transition trigger + Phase 4's `log_audit()` — both via `CREATE OR REPLACE FUNCTION` in a new Phase 12 migration; (b) the local-development invocation pattern for the new Edge Functions (`supabase functions serve approve_listing --env-file .env.local`); (c) the exact ARB key naming convention for the six Q3=A presets (`reject_preset_<key>` proposed); (d) the contract between the Edge Function's `set_config('app.current_user_id', ...)` call and the amended trigger / log_audit body (smoke verification that the COALESCE fallback to `auth.uid()` continues to work for Phase 5–11 callers).
- The R-36 reversal (Q1=B) sets a precedent for future server-side mutators with notification-fanout expectations; the R-05 narrow relaxation (Q7=A) sets a precedent for surgical edits to Phase 4's `log_audit()` when new caller contexts require attribution source amendments.
- The Q8=A shared-widget contract sets a binding constraint on Phase 13: Phase 13 MUST NOT re-implement the five `lib/shared/presentation/widgets/listing_display/` widgets; it imports them verbatim. Phase 13's spec should reference SC-032 as an upstream invariant.
