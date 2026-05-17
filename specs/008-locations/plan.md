# Implementation Plan: Locations Catalog (Governorates, Cities, Areas)

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/008-locations/spec.md`

## Summary

Phase 8 ships the project's first admin-curated geographic catalog: three new bilingual tables (`public.governorates`, `public.cities`, `public.areas`) with public-read RLS, `locations.manage`-gated write RLS, Phase 6-style `is_system` immutability triggers on the two top levels, and Phase 4-style audit-trigger groups on all three — every artifact applied via Supabase MCP `apply_migration` to the remote Supabase project. The Flutter side adds a new feature folder `lib/features/locations/` containing the admin CRUD pages (`LocationsListPage` → `GovernorateDetailPage` → `CityDetailPage`) plus the cascading `LocationPicker` reusable widget that Phase 10's listing form will consume. The Phase 6 `AdminHomePage` gains one new tile "Locations" gated by `PermissionChecker.has('locations.manage')`; the Phase 6 `PermissionChecker` lifecycle is unchanged. The seed migration inserts 14 governorates + ~30–40 cities + a starter set of areas, with the 14 governorates and seat cities marked `is_system=true`. Verification is manual SQL inspection via Supabase MCP `execute_sql` + `get_advisors` after each migration plus end-to-end manual UI verification on the reference Infinix Note 8 device, all walked by `quickstart.md`.

**Technical approach**: Five Session 2026-05-16 clarifications closed the design space — Q1 (no lat/lng columns; Phase 15 adds them later if needed), Q2 (CASCADE on the internal hierarchy FKs with dialog-enumerated counts), Q3 (`is_system BOOLEAN` columns on `governorates` and `cities` plus DB-side immutability triggers, mirroring Phase 6's `roles.is_system` precedent), Q4 (30–40 city rows covering 14 seats + second-tier cities), Q5 (audit triggers attached BEFORE the seed `INSERT`s so every seeded row produces one `*.created` audit row with `actor_user_id=NULL`). The five Phase 8 migrations + the two new policy files + the new feature folder under `lib/features/locations/` + the ARB-key delta on `app_ar.arb` and `app_en.arb` collapse into **five new migration files**, **three new policy files** (one per table — read + write split per the Phase 4/6 inline-bundling pattern), **one new feature folder** under `lib/features/locations/`, **one new tile** on `AdminHomePage`, **four new `go_router` routes** under `/admin/locations/...`, **one new ARB-key cluster** (~25 page/dialog/error keys; no permission-category headings — those landed in Phase 7), and **zero new packages in `pubspec.yaml`**. Phase 4 R-05 / Phase 6 R-05 / Phase 7 R-05 central-helper invariant is preserved a fourth time: `current_user_has_permission()` is unchanged; `log_audit()` is invoked unchanged for the three new audit-trigger groups (Phase 4 R-05 reusability invariant preserved a **fifth** time across Phases 4/5/6/7/8). The Flutter side adds `lib/features/locations/{data,domain,presentation}/` strictly per Constitution IV; the `domain/` of the new feature is Supabase-free per Constitution IX. **No new packages in `pubspec.yaml`**. **No new automated tests** per the durable session feedback rule (`feedback_no_new_tests.md`); verification is manual SQL via Supabase MCP `execute_sql` + `get_advisors` + manual device walk on the reference Infinix Note 8 against the remote Supabase project.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) for the app additions; PostgreSQL (Supabase remote, Postgres 15+) for the SQL migrations. **No Edge Function in Phase 8** — locations writes go through the Phase 6/7 write-side RLS pattern (RLS gate + `current_user_has_permission('locations.manage')` re-check), not through a SECURITY DEFINER RPC. Locations writes are simpler than Phase 7's `mutate_role` (no atomic multi-table delta, no optimistic locking, no super-admin-permission-set immutability), so direct RLS-protected `INSERT` / `UPDATE` / `DELETE` from the Supabase JS-equivalent on the Flutter client is sufficient.

**Primary Dependencies**: `supabase_flutter` (already in `pubspec.yaml`), `flutter_bloc` (already in), `equatable` (already in), `get_it` + `injectable` (already in — used for DI registration of the new BLoCs, use cases, and data sources via codegen), `go_router` (already in — the new `/admin/locations/...` route guards read from `PermissionChecker.has('locations.manage')`). **No new runtime or dev packages.** **Tooling**: Supabase MCP server (`apply_migration`, `execute_sql`, `list_tables`, `list_migrations`, `get_advisors`) is the canonical migration-apply / inspection mechanism — same as Phases 4, 5, 6, 7.

**Storage**: Remote Supabase Postgres project. Phase 8 adds:

- **Three new tables**: `public.governorates`, `public.cities`, `public.areas`. Each carries UUID `id PRIMARY KEY`, TEXT `key` slug, JSONB `display_name`, JSONB `description NULL`, INTEGER `position NULL`, BOOLEAN `is_active NOT NULL DEFAULT true`, TIMESTAMPTZ `created_at` / `updated_at`. `governorates` and `cities` additionally carry BOOLEAN `is_system NOT NULL DEFAULT false`. `cities` carries `governorate_id UUID NOT NULL REFERENCES public.governorates(id) ON DELETE CASCADE`; `areas` carries `city_id UUID NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE`. (FR-001, FR-002, Clarifications Q2/Q3.)
- **Three new audit-trigger groups**: triggers on `public.governorates` (INSERT/UPDATE/DELETE → `governorate.created` / `governorate.updated` / `governorate.deleted` — FR-007); on `public.cities` (INSERT/UPDATE/DELETE → `city.created` / `city.updated` / `city.deleted`); on `public.areas` (INSERT/UPDATE/DELETE → `area.created` / `area.updated` / `area.deleted`). All attached via Phase 4's `log_audit()` reusable trigger function (unchanged for a fifth time across Phases 4/5/6/7/8). The triggers are attached BEFORE the seed `INSERT`s in the same migration so the seed produces ~80 `*.created` audit rows with `actor_user_id=NULL` (Clarifications Q5).
- **Two immutability triggers**: `enforce_governorate_system_immutability` on `public.governorates` (refuses `DELETE` and refuses `UPDATE` on `key` when `is_system=true`); `enforce_city_system_immutability` on `public.cities` (same posture). `areas` has no `is_system` column and therefore no immutability trigger. Pattern mirrors Phase 6's `enforce_role_system_immutability` (FR-007a, Clarifications Q3).
- **Three new RLS policy files**: `governorates_phase8.sql`, `cities_phase8.sql`, `areas_phase8.sql`. Each policy file declares (a) one SELECT policy admitting `anon` AND `authenticated` (locations are global reference data — see Edge Case "Anonymous read on app launch"); (b) INSERT / UPDATE / DELETE policies gated by `current_user_has_permission('locations.manage')`. (FR-008, FR-009.)
- **No new helper functions**. The Phase 6 `current_user_has_permission(TEXT)` helper is reused unchanged. The Phase 4 `log_audit()` and `set_updated_at()` triggers are reused unchanged.

**Testing**: **Manual SQL inspection against the remote Supabase project via Supabase MCP `execute_sql` + `get_advisors` after each migration + manual UI verification on the reference Infinix Note 8 device.** Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's assumptions, this phase introduces NO new automated tests of any kind. Build-time validation is preserved: Supabase's static SQL parser at `apply_migration` time catches syntax errors; Flutter's analyzer + the existing Phase 3 localization lint guard validate the new Dart files. Existing Phase 1/2/3/4/5/6/7 tests remain in source unchanged.

**Target Platform**: Android 7.0+ (API 24+) for the Flutter side (Constitution XI); Supabase remote Postgres for the backend side. iOS, Web, desktop NOT a target.

**Project Type**: Mobile app + backend. Phase 8 introduces the second new feature-folder top-level since Phase 5/6 (the first was Phase 7's `lib/features/super_admin/`): `lib/features/locations/`. It also adds a single new tile to the Phase 6 `AdminHomePage`, and adds ~25 ARB keys to both `app_ar.arb` and `app_en.arb`.

**Performance Goals**:

- `LocationsListPage` initial render: under 1 second on the reference Infinix Note 8 (one read of `SELECT * FROM governorates ORDER BY position NULLS LAST, key` plus a roll-up COUNT against `cities` per row — a small query at MVP scale, ~14 rows).
- `GovernorateDetailPage` initial render: under 1 second (one read of cities for the governorate plus a roll-up COUNT against `areas` per row — typically 1–8 city rows).
- `CityDetailPage` initial render: under 1 second (one read of areas for the city — typically 0–6 area rows).
- `LocationPicker` first render of the governorate level: under 500ms (the catalog is small and Phase 8 ships no client-side cache; each picker mount reads fresh).
- `LocationPicker` cascade transition (governorate → cities; city → areas): under 300ms after selection (one Supabase round-trip per transition).
- Add / edit / delete from the admin forms: under 500ms server-side (one INSERT/UPDATE/DELETE).
- Rename propagation (Constitution V / SC-007): the renamed label appears on any signed-in user's next-render of any LocationPicker mount in under 5 seconds (the picker reads fresh on each mount — no client-side cache to invalidate).
- Migration apply (five migrations) against the remote project: under 60 seconds total.

**Constraints**:

- Constitution II (Source-Controlled Backend) is binding: every backend artifact is a checked-in `.sql` file under `supabase/migrations/` or `supabase/policies/`. No Studio-only edits.
- Constitution III (Security-First Supabase, NON-NEGOTIABLE): the three new tables have RLS enabled. The SELECT policies admit anonymous reads (deliberate carve-out from the authenticated-only default — locations are global reference data; documented in spec Edge Cases and in research R-04). The write-side policies (INSERT/UPDATE/DELETE) are permission-keyed via `current_user_has_permission('locations.manage')`. The two immutability triggers provide defense-in-depth against DELETE / `key`-rename of seeded rows.
- Constitution VII (Dynamic Roles & Permissions) is preserved: no new permission key is introduced (`locations.manage` already exists from Phase 6 §9.1, mapped to `admin` and `super_admin`). Every write surface consults `PermissionChecker.has('locations.manage')` client-side and `current_user_has_permission('locations.manage')` server-side. Audit emission is universal (every `governorates` / `cities` / `areas` mutation produces exactly one `audit_logs` row — Clarifications Q5).
- Constitution VIII (Approval Workflow & Publisher Identity): Phase 8 does not touch the approval workflow. The locations surface is admin-gated only.
- Constitution IX (Future Backend Portability): `lib/features/locations/domain/` imports nothing from `package:supabase_flutter`. Only `lib/features/locations/data/datasources/...` and `lib/features/locations/data/repositories/...` touch Supabase.
- Migrations apply to the **remote** Supabase project via Supabase MCP `apply_migration` (inherited from Phase 4 R-01).
- Migrations MUST be idempotent (Supabase migration tracker + idempotent constructs in the bodies: `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER IF EXISTS ... CREATE TRIGGER`, `DROP POLICY IF EXISTS ... CREATE POLICY`, seed INSERTs use `ON CONFLICT (key) DO NOTHING` or `ON CONFLICT (governorate_id, key) DO NOTHING` / `ON CONFLICT (city_id, key) DO NOTHING` as appropriate). The project memory `project_supabase_mcp_apply_migration.md` is binding.
- Phase 4 R-05 / Phase 5 R-12 / Phase 6 R-05 / Phase 7 R-05 central-helper invariant is preserved a fourth time: `current_user_has_permission()` is unchanged; new policies use it as-is.
- The `log_audit()` reusable trigger function is invoked unchanged for the three new audit-trigger groups (Phase 4 R-05 reusability invariant preserved a **fifth** time across Phases 4/5/6/7/8).
- No new packages in `pubspec.yaml`; no new dev packages.
- No new permission keys (FR-010).

**Scale/Scope**:

- **Five new SQL migration files** under `supabase/migrations/` named with synthetic-monotonic 14-digit timestamps `20260517120001` through `20260517120005`, ordered after Phase 7's `20260516120005_phase7_advisor_hardening.sql`. The five migrations:
  1. `20260517120001_create_governorates.sql` — `CREATE TABLE public.governorates`, `ENABLE ROW LEVEL SECURITY`, attach the `set_updated_at` trigger (Phase 4 helper, unchanged), attach the `enforce_governorate_system_immutability` trigger (new — body inline in this migration), attach the audit trigger via `log_audit()`, then the SEED `INSERT` of the 14 governorates with `is_system=true`. SELECT + write policies bundled inline + mirrored to `supabase/policies/governorates_phase8.sql`. (FR-001/002/003/004/007/007a/008/009.)
  2. `20260517120002_create_cities.sql` — `CREATE TABLE public.cities` with `governorate_id` FK `ON DELETE CASCADE`, RLS, `set_updated_at`, `enforce_city_system_immutability`, audit trigger, SEED `INSERT` of ~30–40 cities (seat cities + second-tier per Clarifications Q4) with `is_system=true`, SELECT + write policies. (FR-001/002/003/005/007/007a/008/009.)
  3. `20260517120003_create_areas.sql` — `CREATE TABLE public.areas` with `city_id` FK `ON DELETE CASCADE`, RLS, `set_updated_at`, audit trigger (no immutability trigger — areas have no protected seed), SEED `INSERT` of the starter areas (no `is_system` column), SELECT + write policies. (FR-001/002/003/006/007/008/009.)
  4. `20260517120004_create_locations_indexes.sql` — performance indexes on `cities(governorate_id)`, `areas(city_id)`, `cities(is_active)`, `areas(is_active)`, plus a uniqueness index per FR-003 (composite unique on `(governorate_id, key)` for `cities` and `(city_id, key)` for `areas`; the `key` on `governorates` is `UNIQUE` at column level already). Idempotent via `CREATE INDEX IF NOT EXISTS`. (Performance Goals.)
  5. `20260517120005_phase8_advisor_hardening.sql` — defense-in-depth (mirroring Phase 5 R-12 + Phase 6 R-12 + Phase 7 R-12 advisor-hardening pattern). Runs Supabase advisor checks; codifies the `anon` SELECT GRANT explicitly to silence advisor warnings about anonymous-read policies; ensures the immutability triggers have the correct `SECURITY DEFINER` / `search_path` posture; reaffirms RLS-enabled state.

- **Three new policy files** under `supabase/policies/`: `governorates_phase8.sql`, `cities_phase8.sql`, `areas_phase8.sql`. Each file is a parallel copy of the inline-bundled SQL in migrations 1–3 (the Phase 6 R-02 invariant — policies live in both source-of-truth files AND inline in the migration). Phase 4/5/6/7 policy files are NOT edited.

- **Three updated doc files** under `supabase/docs/` (and one new): `governorates.md` (NEW), `cities.md` (NEW), `areas.md` (NEW) — each describes the table's columns, RLS posture, immutability trigger (if any), audit-trigger action keys, and the seed inventory. `audit_logs.md` is updated to enumerate the nine new action keys (`governorate.*` / `city.*` / `area.*`).

- **One new feature folder** under `lib/features/locations/` with the full Constitution IV three-layer split (`data/`, `domain/`, `presentation/`). Subfiles:

  - `data/datasources/supabase_locations_datasource.dart` — reads governorates / cities / areas with the filters the admin pages need (active + inactive for admin; active-only for the public picker); INSERTs / UPDATEs / DELETEs through the RLS-gated path.
  - `data/repositories/locations_repository_impl.dart` — the only place that imports `package:supabase_flutter` in the new feature folder.
  - `data/dtos/governorate_dto.dart`, `city_dto.dart`, `area_dto.dart`, `governorate_with_count_dto.dart`, `city_with_count_dto.dart`, `location_mutation_request_dto.dart` — Supabase-shape DTOs.
  - `domain/entities/governorate.dart`, `city.dart`, `area.dart`, `governorate_with_city_count.dart`, `city_with_area_count.dart`, `location_picker_selection.dart` — domain value objects. NO Supabase imports.
  - `domain/repositories/locations_repository.dart` — abstract interface.
  - `domain/usecases/list_governorates.dart`, `load_governorate_detail.dart`, `list_cities_for_governorate.dart`, `load_city_detail.dart`, `list_areas_for_city.dart`, `create_governorate.dart`, `update_governorate.dart`, `delete_governorate.dart`, `create_city.dart`, `update_city.dart`, `delete_city.dart`, `create_area.dart`, `update_area.dart`, `delete_area.dart` — one use case per primary action. (US3/US4/US5.)
  - `presentation/bloc/locations_list_bloc.dart` — owns the governorate list state for `LocationsListPage`.
  - `presentation/bloc/governorate_detail_bloc.dart` — owns the city-list state plus the governorate header for `GovernorateDetailPage`, including the add/edit/delete form sub-state.
  - `presentation/bloc/city_detail_bloc.dart` — owns the area-list state plus the city header for `CityDetailPage`.
  - `presentation/bloc/location_form_bloc.dart` — owns the add/edit form state (validation, save in progress, save success/failure), reused for governorate / city / area forms via a type discriminator.
  - `presentation/bloc/location_picker_bloc.dart` — owns the cascading picker state for the `LocationPicker` widget (selected governorate, loaded cities, selected city, loaded areas, selected area, emitted `LocationPickerSelection`).
  - `presentation/pages/locations_list_page.dart`, `governorate_detail_page.dart`, `city_detail_page.dart`, `location_form_page.dart` (modal/route used for add and edit across the three levels) — the four pages.
  - `presentation/widgets/governorate_card.dart`, `city_card.dart`, `area_card.dart`, `delete_confirmation_dialog.dart` (reusable across all three levels; enumerates dependent counts per Clarifications Q2), `location_picker.dart` (the FR-018 reusable widget), `location_picker_dropdown.dart` (the three-level cascade primitive), `bilingual_display_name_field.dart` (two inputs `ar` + `en` enforcing the FR-016 Arabic-required rule) — the new widgets. All consume Phase 2 design tokens + Phase 3 `AppLocalizations`.

- **One updated existing file**: `lib/features/admin/presentation/pages/admin_home_page.dart` gains one new tile "Locations" gated by `PermissionChecker.has(PermissionKeys.locationsManage)`. Tapping it navigates to `/admin/locations` (the `LocationsListPage` entry point per FR-012).

- **One updated existing file**: `lib/core/routing/auth_redirect.dart` (or the `go_router` config equivalent) gains four new route entries — `/admin/locations`, `/admin/locations/:governorateId`, `/admin/locations/:governorateId/cities/:cityId`, `/admin/locations/form` (with mode + entity-id query params for the modal form) — each with a redirect guard reading `PermissionChecker.has(PermissionKeys.locationsManage)` and falling through to the per-button per-action gate inside each page.

- **One smoke-test surface** (per spec Assumptions): either a dev-only `LocationCatalogBrowsePage` mounted under a debug route OR exercising the public-read path through the LocationPicker mounted on the admin page itself in read-only mode. The plan defers the exact surface to the implementation step; the assumption is that Phase 13 (Public listing details) eventually becomes the canonical consumer, and Phase 8's smoke-test surface is throwaway.

- **ARB key delta** on `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`: approximately 25 new strings for page titles, button labels, form field labels, validation messages, dialog copy, and the structured-error messages (RLS-deny, unique-violation, immutability-trigger-deny). The 12 `permissionCategory<Capitalized>` keys landed in Phase 7 (Clarifications Q6); Phase 8 introduces no new permission categories. All keys ship to both ARB files in the same commit per Phase 3's localization gate.

- **0 new packages** in `pubspec.yaml`.

- **0 new tests** (durable no-new-tests rule).

- **0 changes** to `.github/workflows/ci.yml` (no new tooling needs CI; SQL is validated at `apply_migration` time on the remote).

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists; `/speckit-specify` produced a complete spec with 7 user stories, 25 FRs, 21 SCs; `/speckit-clarify` resolved Q1–Q5 (no lat/lng, CASCADE FKs, `is_system` + immutability triggers, 30–40 city seed, trigger-before-seed). No implementation has begun. |
| II. Source-Controlled Backend | **Pass** | Every Phase 8 backend artifact lives as a checked-in file: 5 migrations under `supabase/migrations/`, 3 new policy files under `supabase/policies/`, 3 new doc files + 1 updated doc file under `supabase/docs/`. No artifact lives only in Studio. The seed inventory (14 governorates + ~30–40 cities + starter areas) is codified in the migrations themselves, not authored in Studio. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | RLS is enabled on all three new tables. SELECT policies admit `anon` AND `authenticated` — a deliberate carve-out for global reference data, documented in spec Edge Cases ("Anonymous read on app launch") and in research R-04, mirroring the forward-stated Phase 13 (public listing details) and Phase 14 (search) public-read requirement. Write-side policies (INSERT/UPDATE/DELETE) are permission-keyed via `current_user_has_permission('locations.manage')` on every table — no admin can bypass via a different role. The two immutability triggers (`enforce_governorate_system_immutability`, `enforce_city_system_immutability`) provide defense-in-depth: even a direct SQL DELETE through Supabase MCP `execute_sql` with an admin JWT is refused for `is_system=true` rows. Audit-trigger coverage is universal — every mutation through any path emits exactly one `audit_logs` row (FR-007, Clarifications Q5). |
| IV. Clean Architecture Flutter | **Pass** | `lib/features/locations/` is a full three-layer Clean Architecture feature folder (`data/`, `domain/`, `presentation/`). BLoCs own state; use cases live in `domain/usecases/`; the repository is abstract in `domain/repositories/` with the Supabase-touching impl in `data/repositories/`. No widget calls Supabase; no use case imports Supabase. The new `LocationPicker` widget consumes the use cases via the BLoC, not via direct repository calls. |
| V. Arabic-First Localization | **Pass** | All ~25 new user-visible chrome strings flow through Phase 3's `AppLocalizations`. The bilingual `display_name` JSONB pattern from Phase 6 (`roles.display_name`) is reused on all three new tables. The `BilingualDisplayNameField` widget enforces FR-016: `ar` value is required, `en` value is optional, the user cannot save with both empty. RTL is honored: confirmations use `EdgeInsetsDirectional`; the cascade picker is layout-direction-aware; long Arabic names wrap correctly within their cards. The Phase 3 localization lint guard catches any hardcoded user-facing string at PR review. |
| VI. Theme System & Design Tokens | **Pass** | The new pages consume Phase 2's `ListTile` / Chip / Card / Button / Dialog primitives. The cascade picker reuses the existing dropdown / modal-list primitives. No inline hex / font-size / padding in any new widget under `lib/features/locations/presentation/widgets/`. |
| VII. Dynamic Roles & Permissions | **Pass** | Phase 8 reuses the Phase 6 `locations.manage` permission key without introducing a new key (FR-010). Every write surface is gated client-side via `PermissionChecker.has('locations.manage')` and server-side via the write-side RLS policies. No hardcoded role checks anywhere in the new feature code (FR-024). Audit emission is universal: 9 new action keys (`governorate.created` / `.updated` / `.deleted`, `city.*`, `area.*`) cover every mutation path including the initial seed (trigger-before-seed per Clarifications Q5). |
| VIII. Approval Workflow & Publisher Identity | **Pass** | Phase 8 does not touch the approval workflow. The locations admin surface is admin-only-gated. No publisher-identity field is read or mutated by Phase 8 code paths. |
| IX. Future Backend Portability | **Pass** | `lib/features/locations/domain/` imports nothing from `package:supabase_flutter` — `grep -R "package:supabase_flutter" lib/features/locations/domain` returns zero results post-implementation (SC-019 equivalent). Only `lib/features/locations/data/datasources/*` and `lib/features/locations/data/repositories/*` touch Supabase types. The `LocationPickerSelection` domain entity is a pure Dart value object. |
| X. Testable AI Workflow | **Pass — Justified.** | Per `feedback_no_new_tests.md` carried forward from Phases 3/4/5/6/7, every FR is verifiable via a manual SQL action with expected output OR via Supabase MCP `execute_sql` / `list_tables` / `get_advisors` calls OR via a manual UI walk on the reference device. The constitution explicitly permits "a SQL query with expected output" or "a UI action with expected screen state" as acceptance steps. `quickstart.md` lists per-FR / per-SC verifications as runnable Supabase MCP calls and device-walk steps. No constitutional amendment is required. |
| XI. Android-First MVP | **Pass** | All Flutter additions target the Android Flutter build only; no platform-conditional code. The remote Supabase backend is platform-neutral. No new platform plugins. |
| XII. No Hidden Product Decisions | **Pass** | All five Session 2026-05-16 clarifications are captured in `spec.md` `## Clarifications`. The decisions are surfaced in the spec's Assumptions section, in `data-model.md`'s schema definitions, and in this plan's Storage and Constraints sections. The plan-time deferral list in `checklists/requirements.md` enumerates the one remaining low-impact decision (editorial-position tie-break) and explicitly defers it as low-impact research-bench work. The `DEFERRED.md` file (authored during implement, reviewed at squash-merge time per project memory `project_deferred_work.md`) captures any in-flight scope decisions discovered during implementation. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/008-locations/
├── plan.md                    # This file
├── research.md                # Phase 0 — locked tech decisions (R-01..R-NN)
├── data-model.md              # Phase 1 — the 3 new tables + 3 audit-trigger groups + 2 immutability triggers + 3 RLS policy files + the seed inventory + the BLoC + entity shapes for the new feature folder + the ARB key inventory
├── quickstart.md              # Phase 1 — end-to-end manual verification recipe via Supabase MCP execute_sql + Flutter device walk on Infinix Note 8
├── contracts/                 # Phase 1 — interface contracts the implementation MUST honor
│   ├── phase8-tables.md                   # 3 new tables: column shapes, FKs, unique constraints, RLS-enabled state
│   ├── phase8-audit-triggers.md           # 3 trigger groups (on governorates, cities, areas) reusing log_audit() unchanged
│   ├── phase8-immutability-triggers.md    # 2 immutability triggers (governorates, cities) — refuse DELETE & key UPDATE when is_system=true
│   ├── phase8-rls-policies.md             # SELECT (anon + authenticated) + write (locations.manage) policies on all 3 tables
│   ├── locations-seed.md                  # The 14 governorates inventory + ~30–40 cities inventory + starter areas inventory
│   ├── location-picker-widget.md          # LocationPicker contract: cascading levels, optional area, active-only filtering, locale fallback chain, emitted LocationPickerSelection entity
│   ├── locations-admin-pages.md           # Page contracts for LocationsListPage, GovernorateDetailPage, CityDetailPage, location form page — form validation, delete confirmation with dependent counts, system-row affordance hiding
│   ├── locations-routing.md               # Admin-home tile visibility + 4 new go_router routes + route-guard logic
│   └── locations-localization.md          # ARB-key inventory for the ~25 new chrome strings + the bilingual display_name fallback rule
├── checklists/
│   └── requirements.md        # From /speckit-specify (validated; updated post-clarify)
├── spec.md                    # From /speckit-specify + /speckit-clarify (Q1-Q5 resolved Session 2026-05-16)
├── tasks.md                   # Created by /speckit-tasks (NOT by /speckit-plan)
├── DEFERRED.md                # Created during /speckit-implement; reviewed at squash-merge per project_deferred_work.md
└── HANDOFF.md                 # Created at /speckit-implement close-out (or omit if no follow-up scope)
```

### Source Code (repository root)

```text
supabase/
├── config.toml                                            # (existing) NO CHANGE in Phase 8.
├── seed.sql                                               # (existing) NO CHANGE — Phase 8 seed lives inline in the table-creation migrations, not in seed.sql (parallel to Phase 6's role/permission seed pattern).
├── migrations/
│   ├── 00000000000000_init_extensions.sql                 # (existing — Phase 1) NO CHANGE.
│   ├── 20260506120001_init_enums.sql ... 20260506120006_enable_vault.sql  # (existing — Phase 4) NO CHANGE.
│   ├── 20260510120001_create_account_approval_requests.sql ... 20260510120006_phase5_advisor_hardening.sql  # (existing — Phase 5) NO CHANGE.
│   ├── 20260515120001_create_roles.sql ... 20260515120008_phase6_advisor_hardening.sql  # (existing — Phase 6) NO CHANGE.
│   ├── 20260516120001_create_phase7_audit_triggers.sql ... 20260516120005_phase7_advisor_hardening.sql  # (existing — Phase 7) NO CHANGE.
│   ├── 20260517120001_create_governorates.sql             # NEW — CREATE TABLE public.governorates (UUID id PK, TEXT key UNIQUE, JSONB display_name NOT NULL, JSONB description NULL, INTEGER position NULL, BOOLEAN is_active NOT NULL DEFAULT true, BOOLEAN is_system NOT NULL DEFAULT false, TIMESTAMPTZ created_at NOT NULL DEFAULT now(), TIMESTAMPTZ updated_at NOT NULL DEFAULT now()). ENABLE ROW LEVEL SECURITY. Attach Phase 4's set_updated_at trigger. Attach new enforce_governorate_system_immutability trigger (body inline). Attach AFTER INSERT/UPDATE/DELETE trigger calling log_audit('governorate.created'|'governorate.updated'|'governorate.deleted', '*', 'id'). Bundle inline + parallel-file SELECT policy (anon + authenticated USING (true)) and write policies (INSERT/UPDATE/DELETE WITH CHECK current_user_has_permission('locations.manage')). Then SEED INSERT of the 14 governorates with is_system=true and ON CONFLICT (key) DO NOTHING (idempotent). (FR-001/003/004/007/007a/008/009.)
│   ├── 20260517120002_create_cities.sql                   # NEW — CREATE TABLE public.cities with governorate_id UUID NOT NULL REFERENCES public.governorates(id) ON DELETE CASCADE, plus the same column shape as governorates including is_system. UNIQUE (governorate_id, key). RLS, set_updated_at, enforce_city_system_immutability, audit trigger, SEED INSERT of ~30–40 cities with is_system=true and ON CONFLICT (governorate_id, key) DO NOTHING. SELECT + write policies. (FR-001/002/003/005/007/007a/008/009.)
│   ├── 20260517120003_create_areas.sql                    # NEW — CREATE TABLE public.areas with city_id UUID NOT NULL REFERENCES public.cities(id) ON DELETE CASCADE, plus the same column shape as governorates EXCEPT no is_system column. UNIQUE (city_id, key). RLS, set_updated_at, audit trigger (no immutability trigger), SEED INSERT of the starter areas with ON CONFLICT (city_id, key) DO NOTHING. SELECT + write policies. (FR-001/002/003/006/007/008/009.)
│   ├── 20260517120004_create_locations_indexes.sql        # NEW — CREATE INDEX IF NOT EXISTS idx_cities_governorate_id ON public.cities(governorate_id); CREATE INDEX IF NOT EXISTS idx_areas_city_id ON public.areas(city_id); CREATE INDEX IF NOT EXISTS idx_governorates_is_active ON public.governorates(is_active); CREATE INDEX IF NOT EXISTS idx_cities_is_active ON public.cities(is_active); CREATE INDEX IF NOT EXISTS idx_areas_is_active ON public.areas(is_active). (Performance Goals.)
│   └── 20260517120005_phase8_advisor_hardening.sql        # NEW — defense-in-depth pass: codify GRANT SELECT ON public.governorates, public.cities, public.areas TO anon, authenticated; verify RLS-enabled state; verify immutability trigger SECURITY DEFINER + search_path posture; runs `get_advisors` clean. (Constitution III defense-in-depth.)
├── policies/                                              # (existing dir from Phase 4)
│   ├── (existing Phase 4/5/6/7 policy files)              # NO CHANGE — Phase 4, 5, 6, 7 policy files are NOT edited (central-helper invariant + no-policy-edits invariant preserved a fourth time).
│   ├── governorates_phase8.sql                            # NEW — SELECT (anon + authenticated USING true) + INSERT/UPDATE/DELETE (current_user_has_permission('locations.manage')) policies on public.governorates. Mirror of the inline-bundled CREATE POLICY statements in migration 1.
│   ├── cities_phase8.sql                                  # NEW — same shape on public.cities.
│   └── areas_phase8.sql                                   # NEW — same shape on public.areas.
├── functions/                                             # (existing dir from Phase 5/7)
│   └── (existing Phase 5/7 functions)                     # NO CHANGE — Phase 8 introduces no Edge Functions.
└── docs/                                                  # (existing dir from Phase 4/5/6/7)
    ├── (existing Phase 4/5/6/7 doc files)                 # NO CHANGE.
    ├── governorates.md                                    # NEW — describes the table, its column shape, RLS posture (anon + authenticated SELECT; locations.manage write), the immutability trigger, the audit-trigger action keys, the 14-row seed inventory.
    ├── cities.md                                          # NEW — same shape for cities.
    ├── areas.md                                           # NEW — same shape for areas (no immutability trigger).
    └── audit_logs.md                                      # UPDATE — enumerate the nine new action keys: governorate.created/.updated/.deleted, city.created/.updated/.deleted, area.created/.updated/.deleted.

lib/
├── main.dart                                              # (existing) NO CHANGE.
├── app.dart                                               # UPDATE — register four new go_router routes under /admin/locations/...; each carries a redirect guard reading PermissionChecker.has(PermissionKeys.locationsManage).
├── core/                                                  # (existing)
│   ├── di/
│   │   ├── injection.dart                                 # NO CHANGE — Phase 8's new services use @injectable annotations at their definition sites; injection.config.dart regenerates automatically.
│   │   └── injection.config.dart                          # AUTO-REGEN — codegen file. Phase 8 adds entries for LocationsRepositoryImpl, the ~14 use cases, and the 5 BLoCs. Run `flutter pub run build_runner build --delete-conflicting-outputs` after the source-side annotations are added.
│   ├── routing/
│   │   └── auth_redirect.dart                             # UPDATE — extend the existing per-route redirect helper with the 4 new locations routes. Pattern is identical to Phase 6's /admin route guard and Phase 7's /admin/super-admin route guards.
│   └── security/
│       ├── permission_checker.dart                        # NO CHANGE — Phase 6 PermissionChecker is consumed as-is. No new lifecycle hooks.
│       ├── permission_keys.dart                           # NO CHANGE — `locationsManage` already exists from Phase 6. Phase 8 introduces no new permission keys (FR-010).
│       ├── permission_catalog_repository.dart             # NO CHANGE — Phase 6 abstract repository.
│       └── permission_catalog_repository_impl.dart        # NO CHANGE — Phase 6 impl.
├── features/                                              # (existing)
│   ├── admin/                                             # (existing — Phase 5 + Phase 6 + Phase 7)
│   │   └── presentation/pages/admin_home_page.dart        # UPDATE — add the Locations tile gated by PermissionChecker.has(PermissionKeys.locationsManage); navigates to /admin/locations.
│   ├── auth/                                              # (existing) NO CHANGE.
│   ├── home/                                              # (existing) NO CHANGE.
│   ├── onboarding/                                        # (existing) NO CHANGE.
│   ├── profile/                                           # (existing) NO CHANGE.
│   ├── super_admin/                                       # (existing — Phase 7) NO CHANGE.
│   └── locations/                                         # NEW FEATURE FOLDER — full Clean Architecture three-layer split (Constitution IV).
│       ├── data/
│       │   ├── datasources/
│       │   │   └── supabase_locations_datasource.dart     # NEW — reads governorates / cities / areas with filters; INSERT/UPDATE/DELETE via the RLS-gated path. The only file importing `package:supabase_flutter` aside from the repository impl.
│       │   ├── dtos/
│       │   │   ├── governorate_dto.dart                   # NEW — bilingual JSONB display_name shape; is_system; is_active; position; created_at/updated_at.
│       │   │   ├── city_dto.dart                          # NEW — adds governorate_id.
│       │   │   ├── area_dto.dart                          # NEW — adds city_id; no is_system.
│       │   │   ├── governorate_with_city_count_dto.dart   # NEW — read-side DTO for LocationsListPage (governorate + rolled-up city count).
│       │   │   ├── city_with_area_count_dto.dart          # NEW — read-side DTO for GovernorateDetailPage (city + rolled-up area count).
│       │   │   └── location_mutation_request_dto.dart     # NEW — write-side DTO for the form save flow; carries the level enum (governorate/city/area), the parent id for cities/areas, the display_name JSONB, is_active, position.
│       │   └── repositories/
│       │       └── locations_repository_impl.dart         # NEW — implements the domain LocationsRepository interface against the datasource.
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── governorate.dart                       # NEW — pure-Dart value object: id, key, displayName (Map<Locale, String>), description, position, isActive, isSystem, createdAt, updatedAt.
│       │   │   ├── city.dart                              # NEW — adds governorateId.
│       │   │   ├── area.dart                              # NEW — adds cityId; no isSystem.
│       │   │   ├── governorate_with_city_count.dart       # NEW — read-side entity with the rolled-up count.
│       │   │   ├── city_with_area_count.dart              # NEW — read-side entity with the rolled-up count.
│       │   │   └── location_picker_selection.dart         # NEW — pure-Dart value object for the LocationPicker output: governorateId, cityId, areaId? (nullable).
│       │   ├── repositories/
│       │   │   └── locations_repository.dart              # NEW — abstract LocationsRepository interface. No Supabase imports.
│       │   └── usecases/
│       │       ├── list_governorates.dart                 # NEW — list governorates for LocationsListPage (admin: include inactive; picker: active-only via a flag).
│       │       ├── load_governorate_detail.dart           # NEW — load a single governorate by id for the detail page header.
│       │       ├── list_cities_for_governorate.dart       # NEW — list cities under a governorate.
│       │       ├── load_city_detail.dart                  # NEW — load a single city by id for the detail page header.
│       │       ├── list_areas_for_city.dart               # NEW — list areas under a city.
│       │       ├── create_governorate.dart                # NEW — INSERT new governorate.
│       │       ├── update_governorate.dart                # NEW — UPDATE existing governorate (display_name, description, position, is_active; refuses key UPDATE if is_system=true via the trigger).
│       │       ├── delete_governorate.dart                # NEW — DELETE governorate; refused server-side for is_system=true.
│       │       ├── create_city.dart                       # NEW — INSERT new city under a governorate.
│       │       ├── update_city.dart                       # NEW — UPDATE existing city.
│       │       ├── delete_city.dart                       # NEW — DELETE city; refused server-side for is_system=true.
│       │       ├── create_area.dart                       # NEW — INSERT new area under a city.
│       │       ├── update_area.dart                       # NEW — UPDATE existing area.
│       │       └── delete_area.dart                       # NEW — DELETE area; never refused (no is_system on areas).
│       └── presentation/
│           ├── bloc/
│           │   ├── locations_list_bloc.dart               # NEW — owns the governorate-list state for LocationsListPage; emits Loading / Loaded(List<GovernorateWithCityCount>) / Error.
│           │   ├── governorate_detail_bloc.dart           # NEW — owns the city-list state for GovernorateDetailPage; emits Loading / Loaded(Governorate + List<CityWithAreaCount>) / Error.
│           │   ├── city_detail_bloc.dart                  # NEW — owns the area-list state for CityDetailPage; emits Loading / Loaded(City + List<Area>) / Error.
│           │   ├── location_form_bloc.dart                # NEW — owns the form state (Idle / Validating / Saving / SaveSuccess / SaveFailure(reason)); reused across governorate/city/area forms via a level enum.
│           │   └── location_picker_bloc.dart              # NEW — owns the cascade picker state (selected governorate, loaded cities, selected city, loaded areas, selected area); emits LocationPickerSelection on commit.
│           ├── pages/
│           │   ├── locations_list_page.dart               # NEW — entry point at /admin/locations. Lists all governorates with city counts. Tile-tap → /admin/locations/:governorateId.
│           │   ├── governorate_detail_page.dart           # NEW — at /admin/locations/:governorateId. Header with governorate name; list of cities with area counts; tile-tap → /admin/locations/:governorateId/cities/:cityId.
│           │   ├── city_detail_page.dart                  # NEW — at /admin/locations/:governorateId/cities/:cityId. Header with breadcrumb; list of areas.
│           │   └── location_form_page.dart                # NEW — modal/route at /admin/locations/form?mode=...&level=...&id=...&parentId=.... Reused for governorate/city/area add+edit.
│           └── widgets/
│               ├── governorate_card.dart                  # NEW — Phase 2 design-token-driven row widget for the governorate list.
│               ├── city_card.dart                         # NEW — same for city.
│               ├── area_card.dart                         # NEW — same for area.
│               ├── delete_confirmation_dialog.dart        # NEW — reusable dialog enumerating dependent counts (per Clarifications Q2); used by the three delete affordances.
│               ├── bilingual_display_name_field.dart      # NEW — pair of inputs for `ar` + `en` with FR-016 validation (Arabic required, English optional).
│               ├── location_picker.dart                   # NEW — the FR-018 reusable widget. Mounts location_picker_bloc; renders three cascading dropdowns; emits LocationPickerSelection.
│               ├── location_picker_dropdown.dart          # NEW — primitive used by location_picker.dart for each level (governorate / city / area).
│               └── system_row_badge.dart                  # NEW — small chip rendered on is_system=true rows; the admin pages show it but the LocationPicker does not.
└── l10n/                                                  # (existing)
    ├── app_ar.arb                                         # UPDATE — add ~25 new ARB keys for the locations admin pages, dialogs, validation messages, error strings. Arabic copy is Syrian-friendly per Constitution V.
    └── app_en.arb                                         # UPDATE — add the same ~25 keys in English. Both files updated in the same commit per Phase 3 localization gate.
```

**Structure Decision**: The feature follows the project's established Mobile + Backend pattern. Backend artifacts (5 migrations + 3 policy files + 4 doc files) live under `supabase/`; Flutter artifacts (new feature folder + 2 updated existing files + 25 new ARB keys) live under `lib/`. The new feature folder `lib/features/locations/` mirrors the Phase 7 `lib/features/super_admin/` structure: `data/`, `domain/`, `presentation/` per Constitution IV. The `LocationPicker` widget is exported from `lib/features/locations/presentation/widgets/location_picker.dart` for downstream consumers (Phase 10 listing form, Phase 14 search, Phase 15 map view) to import.

## Complexity Tracking

> **No constitutional violations. This section is intentionally empty.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | — | — |
