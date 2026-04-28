<!--
SYNC IMPACT REPORT
==================
Version change: TEMPLATE (uninitialized) → 1.0.0
Bump rationale: Initial ratification. The template placeholders had no semantic
content, so the first concrete adoption of all twelve principles, additional
constraints, workflow rules, and governance is treated as the 1.0.0 baseline
rather than a MAJOR/MINOR/PATCH change against a prior version.

Modified principles (placeholder → final name):
  - [PRINCIPLE_1_NAME] → I. Spec-First Development (NON-NEGOTIABLE)
  - [PRINCIPLE_2_NAME] → II. Source-Controlled Backend
  - [PRINCIPLE_3_NAME] → III. Security-First Supabase (NON-NEGOTIABLE)
  - [PRINCIPLE_4_NAME] → IV. Clean Architecture Flutter
  - [PRINCIPLE_5_NAME] → V. Arabic-First Localization
  - (added) VI. Theme System & Design Tokens
  - (added) VII. Dynamic Roles & Permissions
  - (added) VIII. Approval Workflow & Publisher Identity
  - (added) IX. Future Backend Portability
  - (added) X. Testable AI Workflow
  - (added) XI. Android-First MVP
  - (added) XII. No Hidden Product Decisions

Added sections:
  - Additional Constraints & Standards (replaces [SECTION_2_*])
  - Development Workflow & Quality Gates (replaces [SECTION_3_*])
  - Governance (concrete rules)

Removed sections: None (only template scaffolding was removed).

Templates requiring updates:
  - ✅ .specify/templates/plan-template.md — Constitution Check is a generic
    placeholder ("[Gates determined based on constitution file]"); /speckit-plan
    will derive gates from this file. No edit required at ratification.
  - ✅ .specify/templates/spec-template.md — Already aligned: spec-first user
    stories, FRs, success criteria, and assumptions match Principles I, X, XII.
  - ✅ .specify/templates/tasks-template.md — Already aligned: foundational vs.
    user-story phases support MVP-first delivery (XI) and acceptance-criteria
    discipline (X).
  - ✅ .claude/skills/speckit-*/* — No agent-specific names need rewriting; the
    skills delegate to this constitution at runtime.

Follow-up TODOs: None.
-->

# AlNujom Real Estate Constitution

AlNujom Real Estate is an Arabic-first real estate marketplace for Syria, built
with Flutter (Android) on top of Supabase as the v1 backend. This constitution
defines the non-negotiable principles, constraints, workflow, and governance
that every spec, plan, task, and pull request in this repository MUST honor.

## Core Principles

### I. Spec-First Development (NON-NEGOTIABLE)

No implementation work begins until the corresponding spec, plan, data model,
contracts, and tasks exist for the change. The order is fixed:
`/speckit-specify` → `/speckit-clarify` (when ambiguous) → `/speckit-plan` →
`/speckit-tasks` → `/speckit-implement`. Pull requests that introduce production
code without a matching feature folder under `specs/<###-feature-name>/` MUST be
rejected. Out-of-band fixes (typos, copy tweaks, dependency bumps without
behavior change) are the only exceptions and MUST be labeled as such in the PR.

**Rationale**: Specs are the contract that lets humans and AI agents collaborate
without rework. Skipping the spec turns the codebase into the spec, which AI
agents cannot reliably reason about.

### II. Source-Controlled Backend

All Supabase artifacts — schema, migrations, RLS policies, storage rules, seed
data, Edge Functions, SQL functions, triggers, scheduled jobs — MUST live as
files in this repository under a dedicated backend tree (e.g., `supabase/`).
The Supabase MCP and Studio MAY be used for inspection, prototyping, and
applying changes, but every change applied to the live project MUST be
checked in as a migration or definition file in the same PR. The repository,
not the live database, is the source of truth.

**Rationale**: Without source control, environments drift, rollbacks are
impossible, and the future custom-backend migration loses its reference.

### III. Security-First Supabase (NON-NEGOTIABLE)

Every table MUST have Row Level Security enabled. Any table that intentionally
does not enable RLS MUST be documented in the table's migration file with an
explicit justification comment AND an entry in the spec's data-model.md. Public
read access is restricted to data fields explicitly marked as public listing
data; admin-only data, publisher private fields, reports, audit logs, and
permission tables MUST be readable only via RLS policies that check
authenticated role and dynamic permissions. Service-role keys MUST NOT be
shipped to the Flutter client. Sensitive mutations MUST go through Edge
Functions or RPCs that re-check permissions server-side.

**Rationale**: A real estate marketplace handles personally identifying
publisher data and moderation state. A single unprotected table is a breach.

### IV. Clean Architecture Flutter

The Flutter app MUST follow feature-first Clean Architecture with three layers
per feature: `presentation/` (widgets, BLoC/Cubit, view models),
`domain/` (entities, value objects, repository interfaces, use cases), and
`data/` (Supabase data sources, DTOs, repository implementations). Business
rules MUST live in `domain/` use cases, never inline in widgets. State
management defaults to BLoC/Cubit; a feature MAY use simpler local state
(`StatefulWidget`, `ValueNotifier`) only when its spec explicitly approves it.

**Rationale**: The domain layer is the boundary that lets us replace Supabase
later (Principle IX) and lets specs reason about behavior without UI noise.

### V. Arabic-First Localization

Arabic is the default language; English is a required co-equal locale. Every
user-visible string MUST be localized through the app's localization system —
no inline literal strings in widgets. Layouts MUST work in both RTL and LTR
without per-screen overrides; use logical insets (`EdgeInsetsDirectional`,
`Directionality`-aware widgets) instead of left/right primitives. Arabic copy
MUST be Syrian-friendly, professional, and clear; avoid Modern Standard
Arabic phrasings that read stiff to Syrian users when a natural equivalent
exists.

**Rationale**: The product's target market is Syrian. Bolted-on translations
and LTR-shaped layouts produce the exact "imported app" feel we are avoiding.

### VI. Theme System & Design Tokens

The app MUST support light and dark themes through a centralized design-token
module (colors, typography, spacing, radii, elevations). Feature widgets MUST
read from `Theme.of(context)` or the project's token API; hardcoded hex
colors, raw font sizes, and ad-hoc paddings in feature code are forbidden.
New tokens are added in the token module first, then consumed.

**Rationale**: Hardcoded styles guarantee inconsistency and block global
re-skinning, dark-mode parity, and brand updates.

### VII. Dynamic Roles & Permissions

The role/permission system MUST be data-driven, not hardcoded enum branches.
Super admins can create admin roles and grant granular permissions. Every
sensitive action — approving a listing, banning a user, editing another
publisher's content, viewing private publisher data, exporting reports — MUST
(a) check the caller's effective permissions server-side and (b) write an
audit-log entry capturing actor, action, target, timestamp, and before/after
state where applicable. Audit logs are append-only and admin-readable only.

**Rationale**: Hardcoded admin checks rot the moment the team needs a
moderator role or a finance-only role, and unaudited admin actions are
indistinguishable from a compromised account.

### VIII. Approval Workflow & Publisher Identity

Listings are not public until an admin or super-admin approves them. Users,
agents, and agencies that intend to publish MUST themselves be approved
before any of their listings are publishable. A publisher's private identity
fields (full legal name, national ID number, private contact methods) are
visible to admins only; they become visible to other users only when the
publisher's settings explicitly opt in to public display. Rejected listings
MUST carry a reviewer-supplied reason that surfaces to the publisher.

**Rationale**: Trust is the marketplace's product. Unmoderated listings and
leaked publisher identities destroy it on day one.

### IX. Future Backend Portability

Supabase-specific code (the `supabase_flutter` SDK, Supabase types, Postgrest
filters, RLS-shaped queries) MUST be confined to the `data/` layer behind
repository interfaces defined in `domain/`. The domain layer MUST NOT import
from `package:supabase_flutter` or expose Supabase types in its public API.
Use cases speak in domain entities; data sources translate to/from Supabase
DTOs. New cross-cutting services (auth, storage, realtime) MUST be wrapped in
project-defined interfaces before use cases consume them.

**Rationale**: When v2 swaps Supabase for a custom backend, only the `data/`
layer should change. A leaked Supabase type in `domain/` will require touching
every feature.

### X. Testable AI Workflow

Every implementation task in `tasks.md` MUST include explicit acceptance
criteria and validation steps an agent can run (a command, a UI action with
expected screen state, a SQL query with expected output, a contract test).
Tasks without verifiable outcomes are rejected at task review. When an
implementation discovers that real behavior must diverge from the spec, the
agent MUST update the relevant spec/plan/data-model/contracts file in the
same PR — drift between specs and code is treated as a defect.

**Rationale**: AI agents and reviewers cannot tell "done" from "looks done"
without verifiable criteria, and stale specs poison the next agent's context.

### XI. Android-First MVP

The MVP target is Android only. iOS, Flutter Web, and desktop targets MUST
NOT appear in specs, plans, tasks, dependencies, or CI configuration unless
a future, explicitly-approved spec opens them. Avoid adding cross-platform
abstractions, plugin alternatives, or build configurations for non-Android
targets "while we're here."

**Rationale**: Every platform we keep optional during MVP costs review time,
plugin compatibility checks, and reviewer attention without delivering user
value.

### XII. No Hidden Product Decisions

When a requirement is unclear and clarification is not immediately available,
the agent MUST (a) choose the simplest safe MVP behavior, (b) record the
chosen behavior and the rejected alternatives in the spec's `## Assumptions`
section, and (c) flag the open question for the next clarification pass.
Silent product decisions — picking a default, an order, a copy string, an
edge-case behavior, a permission boundary — without writing them down are
forbidden.

**Rationale**: Hidden decisions accumulate as undocumented invariants. Future
agents and reviewers cannot tell intent from accident, and the product slowly
drifts away from what stakeholders believe was agreed.

## Additional Constraints & Standards

**Technology stack (v1)**:

- Mobile client: Flutter (latest stable), targeting Android (minSdk per
  spec); BLoC/Cubit for state; `go_router` or equivalent for navigation
  (decided in the first feature plan, then locked).
- Backend: Supabase (Postgres + Auth + Storage + Edge Functions + Realtime).
  Edge Functions in TypeScript. SQL functions in PL/pgSQL.
- Repository layout: `lib/features/<feature>/{presentation,domain,data}` for
  the app; `supabase/{migrations,functions,policies,seed}` for the backend.

**Currency & money**:

- v1 supports USD and Syrian Pound (SYP). Money values MUST be stored with
  an explicit currency code; never assume a default.
- Currency formatting MUST flow through a localization-aware formatter that
  honors RTL digit grouping and the current locale.
- The schema MUST be designed so a third currency can be added without a
  destructive migration.

**Localization**:

- Translation keys live in version-controlled ARB (or equivalent) files.
  Adding a new user-visible string without an `ar` AND an `en` translation
  blocks merge.

**Security baseline**:

- No service-role secrets in the mobile client. No raw SQL constructed from
  user input on the client. Client uploads to Storage MUST go through signed
  URLs or RLS-protected buckets.
- Authentication MUST use Supabase Auth; custom auth flows require an
  approved spec.

**Performance & UX baselines** (refined per feature):

- Cold app start to first usable screen on a mid-tier Android device SHOULD
  be under 3 seconds.
- List screens MUST paginate (no unbounded queries).
- Image-heavy screens MUST use cached, downscaled thumbnails.

## Development Workflow & Quality Gates

**Branching & commits**: Feature work happens on a `###-feature-name` branch
created by `/speckit-git-feature`. Commits during a Spec Kit phase are made
by `/speckit-git-commit` after each phase (constitution → specify → clarify
→ plan → tasks → implement). Direct commits to `main` are reserved for
release merges.

**Mandatory artifacts per feature** (under `specs/<###-feature-name>/`):

1. `spec.md` — user stories, functional requirements, success criteria,
   assumptions (Principle XII).
2. `plan.md` — Constitution Check, technical context, project structure.
3. `data-model.md` — entities, relationships, RLS posture per table
   (Principle III).
4. `contracts/` — API/Edge Function/RPC contracts.
5. `tasks.md` — phased, dependency-ordered tasks with acceptance criteria
   (Principle X).
6. `quickstart.md` — how a reviewer or new agent validates the feature end
   to end.

**Quality gates**:

- **Plan gate**: `/speckit-plan` MUST run a Constitution Check section that
  enumerates each principle and marks it Pass / Justified / Violation. Any
  Violation requires a row in `## Complexity Tracking` with rejected
  alternatives, or the plan is rejected.
- **Implementation gate**: A task is "done" only when its acceptance
  criteria are demonstrated (test output, query result, screen recording,
  or signed checklist). UI tasks MUST be exercised in the running app, not
  just typechecked.
- **Backend gate**: Every PR that changes Supabase behavior MUST include the
  corresponding migration / policy / function file. Schema-only changes
  applied via the dashboard without a checked-in migration MUST be reverted.
- **Localization gate**: New user-visible strings MUST ship with `ar` and
  `en` entries in the ARB files.

**Review expectations**: Reviewers (human or AI via `/review`,
`/security-review`, `/ultrareview`) MUST verify principle compliance, not
just code correctness. A passing test suite does not waive Constitution
Check failures.

## Governance

This constitution supersedes ad-hoc conventions, individual preferences, and
prior informal agreements. When this file conflicts with another document in
the repository, this file wins until the other document is updated.

**Amendment procedure**:

1. Propose the change by editing `.specify/memory/constitution.md` via
   `/speckit-constitution`, including a Sync Impact Report comment at the
   top of the file.
2. Update the `**Version**` line per the versioning policy below.
3. Propagate the change to dependent templates (`plan-template.md`,
   `spec-template.md`, `tasks-template.md`) and to any agent guidance files
   in the same PR.
4. Land via the standard PR review process. The PR description MUST
   reference the version bump and summarize the principle delta.

**Versioning policy** (semantic):

- **MAJOR**: A principle is removed, a NON-NEGOTIABLE rule is relaxed, or
  governance changes in a backward-incompatible way.
- **MINOR**: A new principle or section is added, or an existing principle
  is materially expanded.
- **PATCH**: Wording clarifications, typo fixes, examples, or non-semantic
  refinements that do not change behavior expected of contributors.

**Compliance review**:

- Every PR MUST pass the plan-time Constitution Check and a final
  pre-merge re-check (`/speckit-analyze` or equivalent) before merge.
- Drift between specs and shipped code is a defect; opening a PR that
  changes behavior without updating the spec is a Principle X and XII
  violation.
- Quarterly (or on demand), an `/ultrareview` of the main branch MAY be
  run to surface accumulated violations; findings are tracked as new
  feature specs.

**Runtime guidance**: For day-to-day execution rules and harness behavior,
see `CLAUDE.md` at the repository root.

**Version**: 1.0.0 | **Ratified**: 2026-04-27 | **Last Amended**: 2026-04-27
