# Specification Quality Checklist: Contact, Inquiries & Lead Events

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-05-25
**Feature**: [spec.md](../spec.md)

## Content Quality

- [X] No implementation details (languages, frameworks, APIs) — *one allowed deviation: `url_launcher` is named in the dependency-constraints FRs because the constitution's "no commercial-map / no Google-Play-Services-only / no in-app calling" rules require naming the specific accepted launcher; this matches the Phase 15 spec's pattern of naming `flutter_map`, `geolocator`, etc.*
- [X] Focused on user value and business needs
- [X] Written for non-technical stakeholders (with caveat: Constitution Principle III privacy requirements drive several technical-sounding FRs around RLS and Vault — these are kept user-impact-framed: "the inquirer's phone is never visible to anyone but the receiving publisher")
- [X] All mandatory sections completed (User Scenarios, Requirements, Success Criteria, Assumptions)

## Requirement Completeness

- [X] No [NEEDS CLARIFICATION] markers remain — *resolved 2026-05-25: Q1=B-refined (strict source-of-truth, render-but-disable), Q2=B (soft terminal, reopen to seen/responded only), Q3=B (no Phase 16 publisher-side spam UX, enum reserved for forward use)*
- [X] Requirements are testable and unambiguous (each FR can be verified by inspecting a row, capturing a network response, or running a `pg_dump`/`grep` smoke check)
- [X] Success criteria are measurable (every SC has a timestamp, count, or pass/fail observation)
- [X] Success criteria are technology-agnostic (no implementation details — they describe wire-level, behavioral, and observable outcomes)
- [X] All acceptance scenarios are defined (7 user stories, each with Given/When/Then scenarios)
- [X] Edge cases are identified (15+ edge cases including malformed phones, terminal-state listings, Vault decrypt failure, anonymous senders, self-contact, rapid-tap spam)
- [X] Scope is clearly bounded (the Scope note explicitly lists what is OUT of scope — VoIP, chat, share, push, favorites, reports, inquirer-side tracking)
- [X] Dependencies and assumptions identified (Phase 4 Vault, Phase 5 PhoneNumber, Phase 6 permissions, Phase 9 currency unused, Phase 10 listings columns, Phase 12 approval, Phase 13 ContactBlock, Phase 17–22 forward-states)

## Feature Readiness

- [X] All functional requirements have clear acceptance criteria
- [X] User scenarios cover primary flows (Call, WhatsApp, inquiry submit, publisher inbox, RLS, lead events, admin oversight)
- [X] Feature meets measurable outcomes defined in Success Criteria
- [X] No implementation details leak into specification (with the one accepted deviation noted in Content Quality above)

## Notes

- All checklist items pass as of 2026-05-25; spec is ready for `/speckit-clarify` (optional deeper-pass) or `/speckit-plan`.
- Three clarifications resolved during `/speckit-specify` and folded into the spec body: Q1=B-refined (WhatsApp CTA strict source-of-truth + render-but-disable), Q2=B (soft-terminal `closed`-reopen to `seen`/`responded` only), Q3=B (no publisher-side spam-flagging UX in Phase 16; `spam` enum reserved for forward admin use).
- The one accepted technology-naming deviation (`url_launcher` in FR-031) matches the precedent set by the Phase 15 spec naming `flutter_map`, `flutter_map_marker_cluster`, `geolocator`, and `permission_handler` in its own FR-019 — the constitution's "no commercial-map / no Google-Play-Services-only / no in-app calling" rules require the spec to name the accepted launcher to lock the dependency posture.
