# Specification Quality Checklist: Currencies & Exchange Rates

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-17
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs) — *exception: this spec deliberately names Supabase, Postgres, RLS, Flutter, Dart `Decimal`, and `MoneyFormatter` because the implementation plan and predecessor specs do; this is the project-wide spec convention, not a generic-feature spec*
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders — *with caveat as above*
- [x] All mandatory sections completed

## Requirement Completeness

- [x] **No [NEEDS CLARIFICATION] markers remain** — Q1 and Q2 resolved in Session 2026-05-17; Q3 vacated (no longer applicable under Q1's no-conversion stance)
- [x] Requirements are testable and unambiguous — *every FR maps to a verifiable acceptance scenario or success criterion*
- [x] Success criteria are measurable — *23 SCs (added SC-008a for Q2 two-row INSERT, SC-023 for Q1 API enforcement), each with a concrete numeric or boolean target*
- [x] Success criteria are technology-agnostic — *with the same caveat as Content Quality above; SC-008's "SQL grep" is the project convention*
- [x] All acceptance scenarios are defined — *each of US1-US8 has 5-8 numbered Given/When/Then scenarios*
- [x] Edge cases are identified — *10 edge cases enumerated covering anonymous read, insert-only history, multi-row price selection (new), missing display-currency match (replaces "missing rate fallback"), deactivation, seed protection, concurrent rate-set, precision, profiles.preferred_currency non-existence, custom currencies post-v1*
- [x] Scope is clearly bounded — *Phase 9 ships only what's in `lib/features/currencies/` + the formatter + the toggle + the row-selection rule; Phase 10 owns `listing_prices` row persistence and multi-currency form UX; Phase 14 owns any future cross-currency filter UX (Q3 vacated)*
- [x] Dependencies and assumptions identified — *17 assumptions enumerated, including the Q1 plan-override note*

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows — *8 user stories: public read, admin gate, admin set rate (with auto-derived inverse per Q2), user preferred-currency toggle, listing-price native-currency render (per Q1), admin rate history with derived badge, formatter (no conversion API), audit*
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification — *with the project-spec-convention caveat*

## Notes

- All clarifications are now closed; spec is ready for `/speckit-clarify` (which can be skipped given resolved status) or directly `/speckit-plan`.
- **Q1 (Display-time conversion) was resolved with option A — no conversion ever.** This overrides the implementation plan's third headline acceptance criterion ("USD listing displays its SYP equivalent when display_currency = SYP"). The override is documented at the top of `spec.md` in a callout block and in Assumption "Plan-override is bounded to Phase 9 only".
- **Q2 (Inverse rate storage) was resolved with option C — auto-derive inverse server-side.** Each admin call to `update_exchange_rate` atomically INSERTs two rows: the admin-authored row and a derived row with `rate = 1 / admin_rate` (rounded to NUMERIC(18, 6)) marked `source = 'auto-derived from <admin_row_uuid>'`. Two audit rows per admin action.
- **Q3 (Conversion locus) was vacated** by Q1's no-conversion stance. The Pending Clarification Questions section has been removed from the spec body.
- This spec follows the Phase 8 (`008-locations`) structural template: prioritized user stories, FR groupings by domain area (schema, permissions, Edge Function, admin UI, user toggle + row-selection rule, money formatting, localization/tokens/audit), 23 success criteria mapped to FRs and user stories, and an assumptions section that documents the Q1 plan-override and the Q2 auto-derive contract.
