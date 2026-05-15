# Specification Quality Checklist: Auth & Profile

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-10
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

The spec deliberately mirrors Phase 4's posture on a few items where "no implementation details" is shaded by the project's binding architectural constraints — these are flagged here so a reviewer can decide whether they want them rewritten:

- The synthetic-email format `<E.164 phone>@alnujom.local` is reproduced verbatim (FR-001, FR-015) because it is a load-bearing product decision documented in `docs/IMPLEMENTATION_PLAN.md` §6.6 and §11, not an implementation detail to be hidden — the spec would be incoherent without naming it. Same reasoning for the table name `account_approval_requests` and the column `profiles.is_admin`: these are named in the implementation-plan's Phase 5 deliverables list and every later phase's spec will reference them.
- The phrasing "Supabase MCP `execute_sql`" appears in success criteria because the project (per Phase 4 Q5 clarification) has no local Supabase setup; verification IS manual SQL via the MCP server. The constitution's Principle X explicitly permits "a SQL query with expected output" as an acceptance step, and the durable `feedback_no_new_tests.md` rules out automated tests.
- ADR-0001 reference (FR-005, FR-006, US 5) is intentional and constitutional — Phase 4's spec set the precedent that ADRs are surfaced in the Assumptions / cross-cutting layer of every dependent phase.

These choices match the precedent set by `specs/004-supabase-foundation/spec.md` and were not flagged as defects there.

### Clarification Session 2026-05-10

Five clarification questions were asked and answered, all integrated into the spec:

1. **Vault storage mechanism** — `vault.secrets` per-user-per-field, keyed `pii.<user_id>.<field_name>`. FR-005, FR-006, US 5, and the VaultBackedProfileFields entity were rewritten to reflect this.
2. **`private_contact_methods` shape** — structured JSON with allowlisted keys (`whatsapp`, `telegram`, `signal`, `private_email`, `secondary_phone`). FR-005 and the VaultBackedProfileFields entity were updated.
3. **Password policy** — 8 chars min, no complexity. FR-001 was updated; the Supabase project's `auth.minimum_password_length` is set to 8.
4. **Admin queue scope** — pending-only with approve/reject; suspend/un-suspend/re-open deferred to Phase 7. US 4, FR-019, and the account-status assumption were updated; the suspend action was removed from US 4.
5. **Locale source post-first-sign-in** — server wins; in-app picker writes to both `user_preferences` and secure_storage. FR-018 and the locale-handoff assumption were updated.
