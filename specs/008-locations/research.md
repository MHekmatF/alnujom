# Phase 0 Research: Locations Catalog

**Branch**: `008-locations` | **Date**: 2026-05-16 | **Plan**: [plan.md](plan.md)

This file consolidates the technical decisions taken during Phase 0 planning. Each decision is one short paragraph in the form **Decision / Rationale / Alternatives considered**. Every NEEDS CLARIFICATION marker from earlier phases has been resolved; this file is the single source of truth for "why does Phase 8 ship in exactly this shape?" The five `## Clarifications` answers from Session 2026-05-16 (Q1 lat/lng deferral; Q2 internal FK CASCADE; Q3 `is_system` + immutability triggers; Q4 30–40 city seed coverage; Q5 trigger-before-seed audit ordering) are quoted verbatim where applicable; the additional R-items below are the standing-on-shoulders technical decisions that the plan needs locked before tasks.md.

## R-01 — Migration filename convention: carry forward Phase 6/7's synthetic-monotonic 14-digit timestamp pattern

**Decision**: Five new migration files named `20260517120001_create_governorates.sql` through `20260517120005_phase8_advisor_hardening.sql`, ordered strictly after Phase 7's `20260516120005_phase7_advisor_hardening.sql`. The implementation-plan reference filenames (`0011_create_governorates.sql` etc.) are descriptive integers in the implementation-plan document, not the actual migration filenames; the project established the date-prefixed convention in Phases 4–7 and Phase 8 carries it forward.

**Rationale**: Supabase's MCP `apply_migration` orders migrations by filename; using monotonic timestamps avoids any collision with future phases that may need to insert a new migration retrospectively (each new phase gets a new date prefix). The 14-digit pattern (`YYYYMMDDHHMMSS`) is the project memory `project_supabase_mcp_apply_migration.md`'s codified convention.

**Alternatives considered**: (a) Use the implementation-plan's literal integer names (`0011_`, `0012_`, `0013_`) — rejected: would collide with Phase 4's `00000000000000_init_extensions.sql` lexical ordering and break the project's established pattern. (b) Use the actual date this PR is opened — rejected: the synthetic-monotonic pattern is more predictable for reviewers and matches every prior phase. (c) Use 5-digit sequential integers (`00011_`, `00012_`) — rejected: same as (a).

## R-02 — Policy file organization: inline-bundled CREATE POLICY in the migration AND parallel `.sql` files under `supabase/policies/`

**Decision**: Each table-creation migration (1, 2, 3) bundles the corresponding RLS policies inline (so the migration is self-contained and applies as a single transaction on the remote project) AND a parallel `supabase/policies/<table>_phase8.sql` file holds the exact same `CREATE POLICY` statements as a single-table source-of-truth for reviewers and for `/security-review` workflows. The same SQL is in both places by design; the migration is the canonical-applier, the policy file is the canonical-document.

**Rationale**: The Phase 4 R-02 / Phase 6 R-02 / Phase 7 R-02 invariant is preserved a fourth time. The dual-storage pattern lets reviewers read "all policies on table X" by opening one file, while the migration system applies them atomically. The minor duplication is acceptable because both files are checked into the same PR and never diverge.

**Alternatives considered**: (a) Migration-only — rejected: reviewers would have to grep across all migrations to find the current policy set on a single table. (b) Policy-file-only with a `\i` include from the migration — rejected: Supabase MCP `apply_migration` does not support psql meta-commands.

## R-03 — No new packages in `pubspec.yaml`

**Decision**: Phase 8 ships zero new package dependencies. Every Flutter capability needed (BLoC + DI + Supabase client + go_router + Equatable) is already on the dependency tree from Phases 1/2/3/5/6/7.

**Rationale**: Constitution XI (Android-First MVP) plus the durable feedback rule about minimizing churn. The cascading dropdown widget is built on Flutter's stock `DropdownMenu` / `DropdownButtonFormField` / modal-list primitives (Phase 2 design tokens applied); no third-party dropdown library is needed. The bilingual `display_name` JSONB shape uses `dart:convert` (built-in).

**Alternatives considered**: (a) Add a dedicated address-picker package — rejected: the cascading three-level picker is small enough to build in-house and the requirement is too specific (Syrian-only, no postal codes, no geocoordinates) for a generic package to fit. (b) Add `dropdown_search` for typeahead search inside the picker — rejected: not in scope for v1; admins can add cities via the admin form when the seed doesn't cover them.

## R-04 — Public read SELECT policies admit BOTH `anon` AND `authenticated`

**Decision**: All three new tables get a SELECT policy `USING (true)` available to both `anon` and `authenticated` roles. The migration also issues explicit `GRANT SELECT ON public.governorates, public.cities, public.areas TO anon, authenticated` in `20260517120005_phase8_advisor_hardening.sql` so Supabase advisors do not flag the anonymous-read posture as accidental.

**Rationale**: Locations are global reference data with no privacy concern; both Phase 13 (Public listing details, anonymous home page) and Phase 14 (Search, anonymous filters) require pre-login clients to read the location catalog. This is the second deliberate carve-out from Constitution III's authenticated-only default (the first will be Phase 13's `listings` rows in `status='approved'` — also forward-stated). Both carve-outs are deliberate, table-scoped, and documented in their respective migration comments + spec Edge Cases sections.

**Alternatives considered**: (a) authenticated-only SELECT, expose the catalog via an Edge Function for anon — rejected: adds an Edge Function deployment dependency, hurts cold-start performance for the public home page, and provides no real security benefit (the data is non-sensitive and publishable in any case). (b) Restrict `anon` to active rows only via `USING (is_active = true)` — partially adopted: the LocationPicker filters by `is_active = true` client-side (FR-020), so the same row that is hidden in the picker is still visible in a raw SQL query against an anon JWT, which is fine — there is no security harm.

## R-05 — Internal hierarchy FKs use `ON DELETE CASCADE` (Clarifications Session 2026-05-16 Q2)

**Decision**: `cities.governorate_id` REFERENCES `governorates(id) ON DELETE CASCADE`. `areas.city_id` REFERENCES `cities(id) ON DELETE CASCADE`. Deleting a custom (non-`is_system`) governorate cascades to remove its cities and their areas in the same transaction.

**Rationale**: The 14 seeded governorates and the seeded seat cities are protected by `is_system=true` (R-06) so the cascade only ever fires on a path the admin explicitly authored. The confirmation dialog enumerates the dependent count before the admin commits. Phase 10's `listings.city_id` will use `ON DELETE RESTRICT` (forward-stated in spec Edge Cases and FR-002), so cascade can never silently delete listing rows.

**Alternatives considered**: (a) RESTRICT on both — rejected: forces the admin into a manual three-step "delete areas → delete cities → delete governorate" workflow without safety benefit (the audit trail captures every deletion either way; the protection lives in `is_system`). (b) Hybrid (cascade on areas, restrict on cities) — rejected: inconsistent within a single hierarchy. (c) `ON DELETE SET NULL` — rejected: violates the NOT NULL constraint on the FK column.

## R-06 — `is_system BOOLEAN NOT NULL DEFAULT false` columns on `governorates` and `cities`; no `is_system` on `areas` (Clarifications Session 2026-05-16 Q3)

**Decision**: Both `governorates` and `cities` carry a non-null `is_system BOOLEAN` column defaulting to `false`. The 14 seeded governorates and the ~30–40 seeded cities are inserted with `is_system=true`. Admin-created rows default to `is_system=false`. `areas` does NOT carry the column — areas have no protected seed; every area row, seeded or admin-created, exposes Edit + Delete affordances.

**Rationale**: Mirrors the Phase 6 `roles.is_system` precedent exactly. The seeded 14 governorates are the canonical Syrian administrative divisions — there is no operational scenario under which an admin should delete one; renaming is acceptable (it is a localization correction, not a structural change). Seeded seat cities are similarly load-bearing. Areas, by contrast, are editorial scaffolding the project owner explicitly accepts as fully editable (spec Assumptions).

**Alternatives considered**: (a) UI-side hardcoded slug list — rejected (Clarifications Q3 Option B): protection lives only in the in-app surface; direct SQL via admin JWT bypasses it. (b) Add `is_system` to `areas` as well, with all seeded areas marked `true` — rejected: contradicts the spec's explicit "areas have no protected seed" stance. (c) `is_system` as a CHECK constraint rather than a column — rejected: CHECK constraints cannot reference table-aware policy logic; a column is the right shape.

## R-07 — Immutability triggers: `enforce_governorate_system_immutability` and `enforce_city_system_immutability`, mirroring Phase 6's `enforce_role_system_immutability`

**Decision**: Two new BEFORE-UPDATE-OR-DELETE triggers attached to `public.governorates` and `public.cities`. Each trigger raises `SQLSTATE 42501` with a structured error message if `OLD.is_system = true` AND the action is `DELETE` OR (action is `UPDATE` AND `NEW.key IS DISTINCT FROM OLD.key`). All other column updates (`display_name`, `description`, `position`, `is_active`) are allowed even on `is_system=true` rows. The trigger bodies are `LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth` per the project's standard hardening posture.

**Rationale**: Mirrors `enforce_role_system_immutability` exactly. The trigger is defense-in-depth: the admin UI hides the Delete and `key`-rename affordances on `is_system=true` rows (FR-015 / SC-017), but even if a direct SQL DELETE is issued through Supabase MCP `execute_sql` with an admin JWT, the trigger refuses. The trigger does NOT block legitimate edits (`display_name`, `description`, `position`, `is_active`) because those are exactly the changes an admin needs to make (renaming a governorate; deactivating one; reordering).

**Alternatives considered**: (a) Block all UPDATEs on `is_system=true` rows — rejected: prevents the legitimate "rename a governorate" use case (the plan's third acceptance criterion). (b) Block only DELETE; allow `key` rename — rejected: the `key` slug is the stable identifier referenced by future code (e.g., the smoke-test surface or future ARB-key derivation patterns); changing it would break referential semantics even if the FK is by UUID not by key.

## R-08 — Audit triggers attached BEFORE the seed `INSERT`s (Clarifications Session 2026-05-16 Q5)

**Decision**: Within each table-creation migration, the order of operations is: (1) `CREATE TABLE`, (2) `ENABLE ROW LEVEL SECURITY`, (3) attach `set_updated_at` trigger, (4) attach `enforce_<entity>_system_immutability` trigger (governorates / cities only), (5) attach the audit trigger via `log_audit()`, (6) `CREATE POLICY` statements (SELECT + write), (7) seed `INSERT` statements. The audit trigger is attached **before** the seed INSERTs, so every seeded row produces exactly one `*.created` audit row in `public.audit_logs`. The audit rows have `actor_user_id=NULL` (the migration runs as `postgres`, which carries no `auth.uid()`).

**Rationale**: Preserves the project-wide "every mutation on an audit-tracked table produces exactly one audit row" invariant without an initial-seed carve-out. NULL-actor rows are the standard provenance marker for system / migration mutations; queries that want admin activity only filter `WHERE actor_user_id IS NOT NULL`. The ~80-row audit burst from the seed is the legitimate starting point of the change record and is negligible across the table's lifetime.

**Alternatives considered**: (a) Trigger AFTER seed (Phase 7's effective behavior by phasing accident) — rejected (Clarifications Q5 Option B): leaves a gap in the audit record for the seed rows; future audits looking for "when did this row first appear" find nothing. (b) Tagged action `governorate.seeded` distinct from `governorate.created` — rejected (Clarifications Q5 Option C): adds schema complexity for a one-shot event; the `actor_user_id IS NULL` filter already provides the distinction.

## R-09 — Seed coverage: ~30–40 cities covering 14 seat cities + second-tier known cities of each governorate (Clarifications Session 2026-05-16 Q4)

**Decision**: The seed migration for `cities` (`20260517120002_create_cities.sql`) inserts approximately 30–40 city rows. The 14 seat cities are always included (one per governorate). The second-tier additions include — non-exhaustive — Manbij + Afrin (Aleppo), Salamiya + Masyaf (Hama), Qamishli + Hassakah (Hasakah; note Hassakah is also the seat, so only Qamishli is additive), Douma + Yabroud (Rif Dimashq), Albu Kamal + Mayadeen (Deir ez-Zor), Tabqa (Raqqa), Idlib city is the seat + Maaret al-Numan (Idlib), Daraa city is the seat + Bosra (Daraa), Tartus city is the seat + Banias (Tartus), Latakia city is the seat + Jableh (Latakia), Homs city is the seat + Palmyra + Talkalakh (Homs), Aleppo city is the seat + Azaz + the additions above. The exact final inventory is locked at implementation time when the seed migration is authored; the plan-time target is 30–40 rows total. All seeded cities carry `is_system=true`.

**Rationale**: A minimum-only seed (14 seats) would leave the LocationPicker too thin for Syrian users in second-tier cities, forcing them to wait for an admin to add their city via the in-app form before they can pick a sensible location. A comprehensive seed (~100+ cities) would multiply the up-front authoring work and the bilingual-name verification burden disproportionately. The 30–40 target makes the picker useful on day one without exhaustive editorial work.

**Alternatives considered**: (a) Minimum: 14 seat cities only — rejected (Clarifications Q4 Option A): too sparse for real listings. (b) Comprehensive: all towns >50k residents (~100+) — rejected (Clarifications Q4 Option C): unsourced authority + heavy authoring burden. (c) Option D from the clarification (Option B inventory PLUS a dedicated `notes.md` codifying the exact list at plan time) — partially adopted: the inventory IS codified in `data-model.md` and in the migration's inline comments, but a separate `notes.md` file is not created (the migration is the source of truth).

## R-10 — No `latitude` / `longitude` columns in Phase 8; Phase 15 adds them via a non-breaking follow-up migration (Clarifications Session 2026-05-16 Q1)

**Decision**: None of the three Phase 8 tables carry `latitude`, `longitude`, `bbox`, or any other geographic-coordinate column. Phase 15 (Map view) will decide whether to add per-city center coordinates via a follow-up migration, OR to use per-listing coordinates from the Phase 10 `listings` table directly for pin placement.

**Rationale**: Adding coordinates now imposes a meaningful seed-data sourcing burden (~30 city lat/lng pairs of unclear authority + ~dozens of area lat/lng pairs with even more uncertain coordinates) for unvalidated downstream demand. The Phase 15 map view is more likely to use the per-listing coordinates Phase 10 will carry, in which case the locations-table coordinates would be dead schema. Adding them later is a non-breaking ALTER TABLE if the demand actually materializes.

**Alternatives considered**: (a) Add nullable lat/lng on `cities` only and seed the major ones — rejected: the data sourcing problem is the same as adding to areas; halfway-coverage is worse than none. (b) Add lat/lng + a `bbox` polygon column on cities/areas (PostGIS) for proper geographic regions — rejected: introduces a PostGIS dependency for v1 with no validated downstream demand. (c) Add nullable lat/lng + leave the seed values NULL — rejected: same dead-schema problem with no benefit.

## R-11 — No optimistic locking on locations writes

**Decision**: Phase 8 introduces no `expected_updated_at` token, no concurrent-edit conflict detection, no `40001 serialization_failure` raises on simultaneous edits. Last-write-wins is the explicit policy. The audit trail (R-13) captures both writes if two admins edit the same row simultaneously; the older edit is recoverable from the audit log.

**Rationale**: Locations are a low-write, infrequently-edited surface. Phase 7's `mutate_role` adopted optimistic locking because the role/permission graph is the most security-sensitive in-app data and silent overwrites were unrecoverable in real time; locations do not carry the same risk. The cost of the guard (extra columns / RPC parameters / UI error states) does not justify itself at MVP scale. A later spec MAY retrofit optimistic locking using the existing `updated_at` column if real operational pain emerges.

**Alternatives considered**: (a) Optimistic locking via `updated_at` token, mirroring Phase 7's `mutate_role` — rejected: solves a problem that does not exist at MVP scale. (b) Pessimistic row locking (`SELECT ... FOR UPDATE` inside the form's load step) — rejected: introduces lock-holding sessions on the public Supabase project and risks lock-leak on disconnect. (c) `db_constraint` / triggers ensuring strictly-monotonic `updated_at` — rejected: same complexity-without-benefit.

## R-12 — Editorial position ordering with alphabetical-by-`key` tie-break

**Decision**: All three tables order rows for display by `ORDER BY position NULLS LAST, key ASC` (i.e., rows with a non-null `position` integer come first in ascending order; rows with `NULL position` come next in alphabetical order by their `key` slug; ties on `position` fall back to alphabetical-by-`key`). The ordering is locale-independent. The 14 seeded governorates carry editorially-set `position` values (Damascus = 10, Aleppo = 20, Homs = 30, Latakia = 40, Tartus = 50, Hama = 60, then the remaining 8 governorates 70–140 by population). Seeded seat cities carry `position = 10` (the seat is the first city in its governorate); second-tier cities carry NULL position (alphabetical fallback). Areas all carry NULL position (alphabetical).

**Rationale**: Editorial control matters at the governorate level (Damascus-first is the project owner's stated convention; Aleppo-second is by population). Below that, locale-independent alphabetical-by-`key` is the established pattern (Phase 6 RolesListPage uses the same). The `NULLS LAST` clause makes the ordering deterministic without forcing an editorial step on every new row admin-added by `AssignLocationsPage` users.

**Alternatives considered**: (a) Pure alphabetical-by-`key` — rejected: puts Aleppo before Damascus, which is not the Syrian convention. (b) Order by `created_at` — rejected: tied closely to seed-author serialization, not user expectations. (c) Editorial position required (NOT NULL) — rejected: forces every admin add-city action to think about position, which is friction for the long tail of small cities.

## R-13 — `log_audit()` reusable trigger function is invoked unchanged for a fifth time (Phase 4 R-05 invariant preserved across Phases 4/5/6/7/8)

**Decision**: The three new audit triggers (on `governorates`, `cities`, `areas`) invoke Phase 4's `public.log_audit()` SECURITY DEFINER trigger function unchanged. The triggers pass the full action key as `TG_ARGV[0]`, `'*'` as `TG_ARGV[1]` (columns-to-capture), and `'id'` as `TG_ARGV[2]` (the target column — same for all three tables).

**Rationale**: Phase 4 R-05's "log_audit is a reusable central helper, never edited per-phase" invariant is the foundation of audit consistency across the project. Editing the function for Phase 8 would invalidate every phase's audit-trigger contract. The function's signature is rich enough to express every audit case Phase 8 needs.

**Alternatives considered**: (a) Write Phase-8-specific trigger bodies that emit audit rows directly — rejected: violates Phase 4 R-05 and introduces drift between table audit semantics.

## R-14 — `current_user_has_permission(TEXT)` is invoked unchanged for a fourth time

**Decision**: The new write-side RLS policies (FR-008) consult Phase 6's `public.current_user_has_permission(TEXT)` helper. The helper signature, body, and search-path posture are unchanged. The Phase 8 migrations do NOT edit Phase 6's `20260515120005_create_permission_predicate.sql` or any other helper-bearing migration.

**Rationale**: Phase 6 R-05 / Phase 7 R-05 central-helper invariant preserved a fourth time. Every spec that needs a permission check uses the same helper; the policy bodies stay declarative and reviewable.

**Alternatives considered**: None — this is a project-wide invariant.

## R-15 — No new permission keys; `locations.manage` (already in Phase 6 catalog) is the only gate

**Decision**: Phase 8 introduces zero new rows into the `public.permissions` table. The `locations.manage` row already exists from Phase 6 §9.1 with category `locations` and description "Admin Syrian governorates, cities, areas." The Phase 6 default role-permission mapping already assigns `locations.manage` to the `admin` role (with super_admin inheriting via the full-catalog mapping).

**Rationale**: Phase 6 deliberately seeded `locations.manage` for this exact phase — the key has been waiting. Splitting into multiple keys (e.g., `locations.governorates.manage`, `locations.cities.manage`, `locations.areas.manage`) would over-engineer the permission graph for MVP needs and complicate the admin UI without a real authorization use case (the project has no scenario where an admin should be allowed to manage cities but not governorates).

**Alternatives considered**: (a) Split read vs write into `locations.view` and `locations.manage` — rejected: every authenticated and anon user can read the catalog via the public-SELECT policy (R-04); `locations.view` would be redundant. (b) Add per-level gates — rejected: see above.

## R-16 — Per-table anonymous-SELECT carve-out documented in migration comments

**Decision**: Each of the three table-creation migrations carries a SQL `-- COMMENT` block above the SELECT policy noting that the policy admits `anon` AND `authenticated` for reasons codified in spec Edge Cases ("Anonymous read on app launch") and in research R-04. The `20260517120005_phase8_advisor_hardening.sql` migration additionally codifies `GRANT SELECT ON <table> TO anon, authenticated;` and runs `get_advisors` to confirm no warning is emitted.

**Rationale**: Constitution III's authenticated-only default is a non-negotiable principle. Deviating without explicit documentation per Constitution XII ("No Hidden Product Decisions") would be a violation. The per-migration comment + the advisor-hardening migration give reviewers a clear trace of the intentional choice.

**Alternatives considered**: (a) Document only in spec — rejected: a reviewer reading a migration file in isolation would not see the rationale and might flag it as a defect. (b) Document only in the data-model — rejected: same as (a).

## R-17 — LocationPicker filters `is_active=true` rows from its consumer output but does NOT filter in the admin pages

**Decision**: The `LocationPicker` widget (FR-018) reads rows via the same `LocationsRepository` interface as the admin pages, but passes a `consumerFacing: true` flag (or the equivalent) that the data source uses to add a `WHERE is_active = true` clause. The admin pages call the same repository with `consumerFacing: false` (default) and see every row including `is_active = false` ones; those rows carry a "Hidden" badge widget for visual differentiation.

**Rationale**: FR-014 + FR-020. The admin needs to see deactivated rows to re-activate them or audit them; consumers (listing-form authors, search users) should never see them as selectable options. Keeping the filtering at the data-source layer (rather than at the picker widget) ensures the same rule applies regardless of who consumes the repository.

**Alternatives considered**: (a) Two separate repositories (`AdminLocationsRepository` + `PublicLocationsRepository`) — rejected: duplicates the abstraction without justifying the cost (the underlying SQL is one filter clause). (b) Picker-side filtering after a fetch-all — rejected: wastes a round-trip and exposes hidden rows in transit.

## R-18 — Display-name fallback chain: active locale → other locale → `key` slug (mirrors Phase 6's `roles.display_name` pattern)

**Decision**: Every widget that renders a row label reads `display_name->>'<active locale>'`; if NULL or empty, falls back to `display_name->>'<other locale>'`; if also NULL or empty, falls back to the row's `key` slug. The fallback chain is implemented in a single helper in `lib/features/locations/domain/entities/` (`Governorate.localizedName(Locale)`, `City.localizedName(Locale)`, `Area.localizedName(Locale)`); no widget re-implements the chain. Empty-string check uses `trim().isNotEmpty` to catch whitespace-only values.

**Rationale**: Mirrors Phase 6's `roles.display_name` rendering on `RolesListPage`. The fallback chain ensures no row ever renders blank, even if an admin saves an English value but leaves Arabic blank (which is refused by the form, but defense-in-depth at the rendering layer is cheap).

**Alternatives considered**: (a) Refuse to render rows with missing display_name — rejected: contradicts FR-016's posture of "Arabic required, English optional"; if a future spec changes the validation, the rendering should still cope. (b) Show "(no name)" placeholder — rejected: the `key` slug is a more useful diagnostic.

## R-19 — `BilingualDisplayNameField` widget: two inputs (`ar` + `en`) with FR-016 validation

**Decision**: A new shared widget under `lib/features/locations/presentation/widgets/bilingual_display_name_field.dart` renders two `TextFormField`s side-by-side (or stacked, layout-direction-aware). The Arabic input carries `validator: (value) => value?.trim().isNotEmpty == true ? null : AppLocalizations.of(context).arabicNameRequired`. The English input carries no validator (optional per FR-016). The widget is reused across the three form variants (governorate / city / area) — the form differs only in the parent-id field, not in the bilingual name pattern.

**Rationale**: Constitution V Arabic-first stance is mechanized in widget code, not just in UI copy. The two-input pattern matches what Phase 7's `RoleEditorPage` ended up using for the `display_name` fields, codified in `specs/007-super-admin-roles/contracts/role-editor-page.md` § "Display name fields".

**Alternatives considered**: (a) Single input with a locale toggle — rejected: makes it easy to miss the Arabic field; the bilingual two-input layout makes both fields visible at once. (b) Stacked tabs ("Arabic" tab + "English" tab) — rejected: more UI for the same purpose.

## R-20 — No client-side cache on LocationPicker; reads fresh on each mount

**Decision**: The `LocationPicker` widget reads governorates / cities / areas via the repository on each mount (and on each cascade transition); no client-side cache, no in-memory invalidation logic. The repository may rely on the underlying Supabase client's HTTP-level caching, but no Phase 8 code implements an application-level cache.

**Rationale**: SC-007 requires that renaming a governorate propagates to every signed-in client's next-render of the picker in under 5 seconds. The simplest implementation that satisfies this is "read fresh each time"; the alternative (a client-side cache with explicit invalidation on admin-write) would couple the picker to a global cache-invalidation mechanism the project does not have. The catalog is small (~14 governorates + ~30–40 cities + dozens of areas), so the read cost is negligible.

**Alternatives considered**: (a) Cache the catalog in `PermissionChecker`-style centralized cache with explicit refresh on admin-write — rejected: over-engineered for a catalog this small. (b) Cache for the session, invalidate on app foreground — rejected: same as (a) plus the lifecycle complexity. (c) Cache for the session, accept up-to-5-minute staleness — rejected: violates SC-007.

## R-21 — Smoke-test surface for US1 public-read demonstration is deferred to implementation

**Decision**: The exact mechanism for demonstrating US1 (public clients see the seeded catalog on app launch) is decided during `/speckit-implement`. Three viable options: (a) a dev-only `LocationsCatalogBrowsePage` mounted under a debug route accessible from a "Developer" tile on the home page; (b) the same admin-facing `LocationPicker` widget rendered in a read-only "preview" mode on the admin home for debugging; (c) defer until Phase 13 (Public listing details) — at which point Phase 13's public surface becomes the canonical consumer and Phase 8 ships without a permanent consumer-facing surface. The spec Assumptions section already records this as a plan-time decision.

**Rationale**: The smoke-test surface is throwaway — Phase 13 ships in a future spec with the canonical consumer surface. Building a permanent UI feature in Phase 8 just to demonstrate the public read would be sunk cost. The dev-only browse page (option a) is the minimum viable path.

**Alternatives considered**: All three documented in the decision; the implementation phase picks one.

## R-22 — `DEFERRED.md` and `HANDOFF.md` treatment carries forward from Phase 7

**Decision**: During `/speckit-implement`, if any sub-task or contract item is intentionally deferred (e.g., the smoke-test surface choice in R-21, or a polish item discovered during device-walk), it gets a row in `specs/008-locations/DEFERRED.md` with the rationale and the proposed follow-up spec. At squash-merge time, the reviewer reads `DEFERRED.md` to confirm every deferral is intentional and tracked. If Phase 8's implement step closes with no in-flight scope, the optional `HANDOFF.md` is omitted; otherwise it captures the close-out notes per the project memory `project_deferred_work.md`.

**Rationale**: The project memory `project_deferred_work.md` codifies this pattern across Phases 5/6/7; Phase 8 inherits it without modification.

**Alternatives considered**: None — this is a project-wide pattern.
