# Specification Quality Checklist: Super-Admin Role & Permission Management

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-15
**Feature**: [Link to spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

> Note on "implementation details": the spec necessarily names Postgres-side artifacts (triggers, RLS policies, the `mutate_role` Edge Function, `audit_logs` table, `PermissionChecker` singleton) and Flutter-side artifacts (`RolesListPage`, `RoleEditorPage`, `AssignRolePage`, route guards). This is consistent with the house style established by specs 002–006, all of which reference checked-in Supabase migrations and `lib/features/...` paths because the project is Constitution-II-bound (source-controlled backend) and Constitution-IV-bound (clean architecture with a fixed `lib/features/<feature>/{data,domain,presentation}` shape). Every cited artifact is either (a) already present from a prior phase, (b) named by `docs/IMPLEMENTATION_PLAN.md` as the canonical Phase 7 deliverable, or (c) a direct consequence of the constitution principles cited in §3 of the plan. Per the project's spec-house-style, these are SPEC-level identifiers (the names of the contracts and artifacts), not implementation choices — the actual code/SQL lives in `plan.md`, `data-model.md`, and `contracts/` (forthcoming in the spec's plan phase).

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain (Q1, Q2, Q3 resolved Session 2026-05-15)
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)

> Note on "technology-agnostic": the Success Criteria reference SQL verification via Supabase MCP `execute_sql` and manual UI walks on the reference device — same house-style as prior specs. These are verification *steps*, not implementation details; the measurable outcome is the observable state (audit row count, tile visibility, role count), not the verification mechanism.

- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification (per Content Quality note above)

## Resolved Clarifications (Session 2026-05-15)

- **Q1 — In-app `super_admin` grants**: Resolved → **Allow with two-step confirmation.** Recorded in `spec.md` Clarifications section, encoded in FR-018 and US5 Acceptance Scenario 4.
- **Q2 — Self-revocation guard**: Resolved → **Block all self-revocation of `super_admin`.** Recorded in `spec.md` Clarifications section, encoded in FR-009 (server-side check) and FR-018 (UI-side check), tested in US5 Acceptance Scenario 7.
- **Q3 — Mutation entry point**: Resolved → **SECURITY DEFINER SQL RPC (`public.mutate_role`)**, not an Edge Function. Recorded in `spec.md` Clarifications section, encoded in FR-008, edge-cases section, and assumptions section. Edge Function path is deferred to a later phase.
- **Q4 — Concurrent edits on the same role**: Resolved (via `/speckit-clarify`) → **Optimistic locking via the existing `roles.updated_at` token.** Encoded in FR-008 (new `expected_updated_at` parameter on `mutate_role`), Edge Cases (new bullet), US3 Acceptance Scenario 7, and SC-024.
- **Q5 — `super_admin` role permission-set immutability**: Resolved (via `/speckit-clarify`) → **UI-level block on `RoleEditorPage` checklist + server-side enforcement in `mutate_role` as defense-in-depth.** Encoded in FR-008 (super_admin permission-set immutability check), FR-010 (page-level rendering rule), Edge Cases (new bullet), US3 Acceptance Scenario 4a, SC-025, and SC-026.
- **Q6 — Permission-category display labels**: Resolved (via `/speckit-clarify`) → **ARB-keyed app-side localization, no DB change.** Encoded in FR-010 (rendering rule), Assumptions (new ARB-key inventory of 12 keys), and SC-027.

## Deferred to plan phase

- **Q4-bis (deferred) — RPC structured-error-code catalog**: The spec body now enumerates the canonical SQLSTATEs (`42501` for permission-re-check / super_admin-perm-immutability / self-revoke, `40001` for optimistic-lock conflict, `23503` for FK cascade restrict, `23505` for unique-key conflict). Building the full SQLSTATE → structured-code → localized-message lookup table is plan-level work for the contract artifacts.
- **Q5-bis (deferred) — `AssignRolePage` search field scope**: The narrative and SC-008 are self-consistent ("phone or username"); a tighter FR can be added during `/speckit-plan` task decomposition if the implementer needs sharper guidance.

## Notes

- Validation status: **PASS.** The spec is ready for `/speckit-plan`. Six clarifications resolved across `/speckit-specify` and `/speckit-clarify` sessions on 2026-05-15.
- All locked decisions follow the Phase 6 spec convention (one `### Session <date>` subsection with `Qn.` numbered bullets, in chronological order).
