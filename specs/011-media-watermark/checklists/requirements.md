# Specification Quality Checklist: Listing Media Upload, Client-Side Watermark & Storage Policies

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-22
**Last validated**: 2026-05-22 (post-`/speckit-clarify` loop — 5 more questions resolved)
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

> Note on content quality: This spec follows the Phase 10 precedent of citing specific database object names, migration filenames, and (newly added in Q5/Q8) Supabase Storage bucket flags. The downstream spec-kit workflow (`research.md`, `data-model.md`, `contracts/`) consumes these names verbatim. User-value framing is preserved at the User Story layer.

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain *(8 questions resolved across two sessions on 2026-05-22)*
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic *(SC items reference observable outcomes — pixel dimensions, audit-log counts, HTTP response codes, bucket flags — verifiable via the established SQL + manual-device verification surface)*
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded *(Scope note demarcates Phase 11 from Phases 10, 12, 13, 23)*
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification *(same caveat as Content Quality)*

## Clarifications Log

**Session 2026-05-22 (during `/speckit-specify`)**:
- **Q1 = A** — Require ≥1 image at submit; `submit_listing` strengthened per FR-022.
- **Q2 = D** — Disable `external_link` UI in Phase 11; schema enum retained for future-spec forward-compat.
- **Q3 = A** — Edit-in-place + Add more on resubmit; row UUIDs preserved.

**Session 2026-05-22 (during `/speckit-clarify`)**:
- **Q4 = A (with normalization)** — JPEG-only at bucket; picker accepts JPEG/PNG/HEIC/HEIF/WebP and normalizes to JPEG via FR-014 pipeline.
- **Q5 = A** — Manifest declares both legacy `READ_EXTERNAL_STORAGE` AND granular Android-13+ `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`; `image_picker` plugin handles version-aware runtime requests; FR-023 added; SC-026 added.
- **Q6 = B** — Hard cap at 8000×8000 px via header-only metadata read before decode; FR-014 step (a-pre) added; SC-027 added.
- **Q7 = B** — 60-second per-image timeout covering full FR-014 pipeline + retries; FR-015 amended; SC-028 added.
- **Q8 = A** — Public buckets + RLS as access filter; stable public URLs via `getPublicUrl()`; FR-007/FR-008 amended; SC-029 added.

## Sections Touched

`Scope note`, `Clarifications`, `User Story 1`, `User Story 3`, `User Story 5`, `User Story 7`, `Edge Cases`, `FR-007`, `FR-008`, `FR-010`, `FR-011`, `FR-012`, `FR-013`, `FR-014`, `FR-015`, `FR-017`, `FR-019`, `FR-022`, `FR-023` (new), `Key Entities`, `SC-003`, `SC-005`, `SC-017`, `SC-019`, `SC-020`, `SC-023`, `SC-026` (new), `SC-027` (new), `SC-028` (new), `SC-029` (new), `Assumptions` (Image library choice; Android-version coverage gap; Phase 13 gallery consumer; Forward-stated `external_link` UX deferral).

## Coverage Summary (post-clarify)

| Taxonomy category | Status |
|---|---|
| Functional Scope & Behavior | **Clear** |
| Domain & Data Model | **Clear** |
| Interaction & UX Flow | **Clear** (loading-state of existing-row hydration on picker entry — minor; plan-time) |
| Performance | **Resolved** (Q7 timeout + SC-001/SC-011 fps targets) |
| Reliability & availability | **Clear** (atomic-from-publisher invariant + retry + Q7 timeout + edge cases) |
| Observability | **Clear** (audit logs FR-005/FR-021) |
| Security & privacy | **Resolved** (Q8 bucket access, Q5 permissions, EXIF strip, watermark fail-closed) |
| Compliance | **Clear** (no new PII; ADR-0001 already covers admin-only PII for other surfaces) |
| Integration & External Dependencies | **Resolved** (Q4 library choice constraint, Q5 manifest, Q8 bucket config) |
| Edge Cases & Failure Handling | **Resolved** (Q6 pre-decode cap, Q7 timeout, all edge cases enumerated) |
| Constraints & Tradeoffs | **Clear** |
| Terminology & Consistency | **Clear** |
| Completion Signals | **Clear** (29 SCs, all verifiable) |
| Misc / Placeholders | **Clear** (zero TODO / NEEDS CLARIFICATION) |

## Notes

- All 8 clarifications resolved. Spec is ready for `/speckit-plan`.
- Image-library package choice + watermark opacity/position exact numbers + per-image-isolate vs `compute()` choice are intentionally deferred to plan-time research (`research.md`).
- Q5's Android-version test-coverage gap is the only meaningful new commitment beyond the codebase — Phase 11's `quickstart.md` will need both an Infinix Note 8 walk AND a Pixel 8 Pro emulator walk for full SC-026 coverage.
