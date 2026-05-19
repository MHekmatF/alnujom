# Implementation Plan: Listing Creation & Submit-for-Review

**Branch**: `010-listing-creation` | **Date**: 2026-05-18 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/010-listing-creation/spec.md`

## Summary

Phase 10 introduces the project's first user-publishing pathway: five new tables (`public.listings`, `public.listing_details`, `public.listing_prices`, `public.listing_visibility`, `public.listing_status_history`) with full RLS coverage; one new status-transition trigger (`listing_status_transition_trigger`) that auto-writes append-only history rows on every status change; one new audit-trigger group on `public.listings` emitting both row-mutation verbs (`listing.created` / `listing.updated` / `listing.deleted`) and status-delta verbs (`listing.submitted` / `listing.approved` / `listing.rejected` / `listing.paused` / `listing.expired` / `listing.sold` / `listing.rented`) — Phase 4's `log_audit()` reused unchanged for a **seventh time** (R-05 invariant preserved across Phases 4/5/6/7/8/9/10); one new SECURITY DEFINER PL/pgSQL RPC `public.submit_listing(p_listing_id uuid) RETURNS jsonb` (NOT a TypeScript Edge Function — R-06 deviation from the implementation plan's literal "Edge Function `submit_listing`" wording, mirroring Phase 7's `mutate_role` and Phase 9's `update_exchange_rate` decisions); three Q1/Q2/Q3-resolved invariants — **Q1 Full required-field set** (title, purpose, property_type, governorate_id, city_id, area_id, address_text, area_size, at least one `listing_prices` row with `is_primary=true`, at least one of phone/whatsapp, plus rooms+bathrooms for residential property types), **Q2 Area-centroid auto-fill** for `listings.latitude`/`longitude` (data-source path locked per R-07 to ALTER `public.areas` + seed centroids from OpenStreetMap), **Q3 Single-currency-only across every Phase 10 surface**; one altered Phase 8 table (`public.areas` gains `centroid_lat`/`centroid_lng` columns); the Flutter side adds **two new feature folders** — `lib/features/listing_form/` (multi-step form with seven steps: basics → location → details → prices → visibility → media-placeholder → review) and `lib/features/publisher_dashboard/` (`MyListingsPage` with status filters + the "Create listing" entry tile); three new validators under `lib/core/validators/` (`AreaSizeValidator`, `PriceValidator`, `PhoneValidator`); two updated existing surfaces (the Phase 5 dashboard gains the entry-tile gate; `lib/core/routing/auth_redirect.dart` gains `/publisher/listings/*` route guards); ~40 new ARB keys for the form chrome, validators, status badges, rejection-reason rendering, and `submit_listing` error responses; **zero new packages in `pubspec.yaml`** (every dependency the new code requires — `flutter_bloc`, `equatable`, `decimal`, `intl`, `go_router`, `supabase_flutter` — is already locked from Phases 1/9). All artifacts are applied via Supabase MCP `apply_migration` to the remote Supabase project. **No new automated tests** per the durable session feedback rule (`feedback_no_new_tests.md`); verification is manual SQL via Supabase MCP `execute_sql` + `get_advisors` + a manual UI walk on the reference Infinix Note 8 device.

**Technical approach**: The three Q1/Q2/Q3 clarifications closed the design space — Q1 (Full required-field set with residential-property-type-conditional rooms+bathrooms), Q2 (area-centroid auto-fill from `public.areas.centroid_lat`/`centroid_lng` seeded via OpenStreetMap manual research; publisher cannot override in Phase 10; Phase 15 will add pin-drop edit affordance), Q3 (single-currency-only across every Phase 10 surface; the prices step shows exactly one currency picker + one amount field with no "Add another currency" affordance; the Phase 9 forward-stated multi-row schema support remains intact as defense-in-depth for a future spec). Phase 10's backend deliverables collapse into **seven new migration files** (synthetic-monotonic 14-digit timestamps `20260519120001` through `20260519120007`, one day after Phase 9's `20260518...` series), **five new policy files** (one per table per Phase 6 R-02 inline-bundle-plus-parallel-file pattern: `listings_policies.sql`, `listing_details_policies.sql`, `listing_prices_policies.sql`, `listing_visibility_policies.sql`, `listing_status_history_policies.sql`), **one new SECURITY DEFINER RPC** `submit_listing` (replaces the literal "Edge Function" of the implementation plan per R-06), **two new feature folders** under `lib/features/listing_form/` and `lib/features/publisher_dashboard/`, **one new validators directory** at `lib/core/validators/`, **two updated existing files** (`lib/app.dart` route registrations + the Phase 5 publisher-dashboard tile gate), and **one altered existing Phase 8 table** (`public.areas` gains `centroid_lat`/`centroid_lng` columns + a centroid seed of ~50–100 Syrian areas). Phase 4 R-05 / Phase 6 R-05 / Phase 7 R-05 / Phase 8 R-05 / Phase 9 R-05 central-helper invariant is preserved a **seventh** time: `current_user_has_permission()` is unchanged; `log_audit()` is invoked unchanged for the new audit-trigger group on `public.listings`; `set_updated_at()` is attached unchanged to four of the five new tables. The Flutter side adds two new feature folders strictly per Constitution IV; the `domain/` of each new feature is Supabase-free per Constitution IX. **No new automated tests** per the durable session feedback rule; verification is manual SQL via Supabase MCP `execute_sql` + `get_advisors` + manual device walk on the reference Infinix Note 8.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) for the app additions; PostgreSQL (Supabase remote, Postgres 15+) for the SQL migrations and the new RPC. **No Edge Function in Phase 10** per Research R-06 — the deviation from the implementation plan's literal "Edge Function `submit_listing`" wording is recorded in spec Assumptions ("`submit_listing` implementation surface") and in research R-06, exactly as Phase 7 did for `mutate_role` and Phase 9 did for `update_exchange_rate`. The `submit_listing` mutation lives as a SECURITY DEFINER PL/pgSQL function callable from the Flutter client via `supabase.rpc('submit_listing', {p_listing_id: ...})`.

**Primary Dependencies**: `supabase_flutter` (already in `pubspec.yaml`), `flutter_bloc` (already in), `equatable` (already in), `get_it` + `injectable` (already in — used for DI registration of the new BLoCs, use cases, data sources via codegen), `go_router` (already in — the new `/publisher/listings/*` route guards read from publisher_status + account_status), `intl` (already in — consumed by the `MoneyFormatter` inline price-preview), `decimal` (already in from Phase 9 — used by the form's price field and the FR-018 `PriceValidator`). **Zero new runtime packages**. **Tooling**: Supabase MCP server (`apply_migration`, `execute_sql`, `list_tables`, `list_migrations`, `get_advisors`) is the canonical migration-apply / inspection mechanism — same as Phases 4–9.

**Storage**: Remote Supabase Postgres project. Phase 10 adds:

- **Five new tables** in the `public` schema:
  - `public.listings` — the canonical listing row with the full v1 column inventory per IMPLEMENTATION_PLAN §6.2 (24 columns: `id`, `publisher_user_id`, `agency_id` (FK-less in Phase 10 per Assumption forward-stated to Phase 19), `purpose`, `property_type`, `status` defaulting to `'draft'`, `title`, `governorate_id`, `city_id`, `area_id`, `address_text`, `latitude`, `longitude`, `location_visibility` defaulting to `'approximate'`, `phone`, `whatsapp`, `contact_name_visibility` defaulting to `'public'`, `area_size`, `rooms`, `bathrooms`, `floor`, `created_at`, `updated_at`, `published_at`, `expires_at`). RLS enabled.
  - `public.listing_details` — 1:1 extension carrying `description`, `amenities JSONB`, `year_built`, `furnished`, `parking`. RLS enabled; policies derive ownership through the parent listing.
  - `public.listing_prices` — 1:N rows per listing per Phase 9 forward-statement; per Q3 every Phase 10 listing has exactly ONE row. Columns: `id`, `listing_id`, `currency_code` (FK to `public.currencies(code) ON DELETE RESTRICT`), `amount NUMERIC(14, 2) CHECK (amount > 0)`, `is_primary BOOLEAN`, `created_at`. Carries `UNIQUE(listing_id, currency_code)` (Phase 9 Q4) AND a partial unique index `(listing_id) WHERE is_primary=true` enforcing exactly one primary per listing.
  - `public.listing_visibility` — 1:1 envelope carrying `location_visibility`, `contact_visibility`, `hide_until`, `last_updated_by`. Per Assumption "`listing_visibility` parent-column duplication", the parent `listings.location_visibility` is authoritative and a sync trigger maintains the child row.
  - `public.listing_status_history` — append-only history table. Columns: `id`, `listing_id`, `previous_status`, `new_status`, `changed_by`, `changed_at`, `reason`. Auto-written by the FR-004 trigger on every INSERT and every UPDATE of `status`. RLS makes the table INSERT-only (no UPDATE policy, no DELETE policy).
- **One altered existing Phase 8 table**: `public.areas` gains two new columns — `centroid_lat NUMERIC(9, 6) NOT NULL` and `centroid_lng NUMERIC(9, 6) NOT NULL` — and a seed migration populates centroids for every existing area row from a checked-in OpenStreetMap-sourced data file (~50–100 Syrian areas across the 14 governorates). The columns are NOT NULL once the seed completes; the seed migration runs the `ALTER TABLE` as `NULL` first, populates centroids, then `ALTER TABLE ... ALTER COLUMN ... SET NOT NULL`. Future admin-added areas are required to carry centroids (the Phase 8 area-form is extended in a downstream patch or future spec; Phase 10 itself does not modify Phase 8's location-admin UI). Per FR-013a, when the form encounters an area lacking centroid data (which should never happen post-seed), the location step blocks with a localized error.
- **One new status-transition trigger**: `listing_status_transition_trigger` on `public.listings` fires `AFTER INSERT` (captures `previous_status=NULL` / `new_status=NEW.status`) and `AFTER UPDATE OF status` (captures `previous_status=OLD.status` / `new_status=NEW.status`); the trigger function appends one `listing_status_history` row per fire with `changed_by=auth.uid()` (or NULL when no JWT). The trigger body lives in the same migration that creates `listing_status_history`; no reuse of Phase 4's `log_audit` (the history table is a separate operational record).
- **One new sync trigger**: `listing_visibility_sync_trigger` on `public.listings` fires `AFTER INSERT OR UPDATE OF location_visibility` and UPSERTs the corresponding `listing_visibility` row to keep the duplicated `location_visibility` value in sync (parent column is authoritative). Mirrors a pattern that lets Phase 15's map view read from the narrow `listing_visibility` projection.
- **One new audit-trigger group** on `public.listings` via Phase 4's `log_audit()` unchanged (R-05 invariant preserved a SEVENTH time across Phases 4/5/6/7/8/9/10) emitting `listing.created` / `listing.updated` / `listing.deleted` action keys for row-level mutations AND status-delta verbs (`listing.submitted` / `listing.approved` / `listing.rejected` / `listing.paused` / `listing.expired` / `listing.sold` / `listing.rented`) computed inside the audit-trigger body from the OLD.status → NEW.status delta. Phase 12 will consume the `listing.approved` / `listing.rejected` events without modifying the trigger.
- **One new SECURITY DEFINER RPC**: `public.submit_listing(p_listing_id UUID) RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth`. Body: (a) load the listing row, raise `42704 undefined_object` if missing; (b) verify `auth.uid() = listing.publisher_user_id` (raise `42501 insufficient_privilege` on mismatch); (c) verify the publisher's `profiles.publisher_status='approved'` AND `account_status='approved'` (raise `42501` on mismatch); (d) verify the listing's current `status IN ('draft', 'rejected')` (raise `22023 invalid_parameter_value` on mismatch); (e) re-run the Q1 Full required-field validation per FR-010a (raise `22023` with a structured JSONB payload listing the missing fields under `missing_fields` on failure); (f) `UPDATE public.listings SET status='pending_review' WHERE id=p_listing_id` (the status-transition trigger captures the history row as a side-effect AND the audit-trigger emits the `listing.submitted` row); (g) return `jsonb_build_object('listing_id', p_listing_id, 'status', 'pending_review', 'submitted_at', now())`. The function's transactional scope is automatic — the status flip + history insert + audit emission all commit together.
- **Five new RLS policy files**: one per new table, following Phase 6 R-02 inline-bundle-plus-parallel-file pattern. The policies are bundled inline in each table-creation migration AND mirrored to source-of-truth files at `supabase/policies/listings_policies.sql`, `listing_details_policies.sql`, `listing_prices_policies.sql`, `listing_visibility_policies.sql`, `listing_status_history_policies.sql`. Child-table policies (`listing_details`, `listing_prices`, `listing_visibility`) derive ownership through the parent `listings` row via subquery; `listing_status_history` is INSERT-only by gating the INSERT policy to `pg_trigger_depth() > 0`.
- **No anonymous SELECT carve-out**: Unlike Phases 8 and 9, Phase 10's tables do NOT carve out anonymous read across the board. The `public.listings` SELECT policy admits anonymous readers ONLY when `status='approved'` AND the publish window is open; all child tables follow the same gate. `listing_status_history` is owner+admin-only. The carve-out count remains at three (Phase 8's governorates/cities/areas group + Phase 9's currencies/exchange_rates group); Phase 10 does not add a fourth.

**Testing**: **Manual SQL inspection against the remote Supabase project via Supabase MCP `execute_sql` + `get_advisors` after each migration + manual UI verification on the reference Infinix Note 8 device.** Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's assumptions, this phase introduces NO new automated tests of any kind — including for the three new validators despite the IMPLEMENTATION_PLAN's literal reference to "Unit tests for validators." The validator golden cases are codified in `quickstart.md` as a manual-verification checklist. Build-time validation is preserved: Supabase's static SQL parser at `apply_migration` time catches syntax errors; Flutter's analyzer + the existing Phase 3 localization lint guard validate the new Dart files. Existing Phase 1–9 tests remain in source unchanged.

**Target Platform**: Android 7.0+ (API 24+) for the Flutter side (Constitution XI); Supabase remote Postgres for the backend. iOS, Web, desktop NOT a target.

**Project Type**: Mobile app + backend. Phase 10 introduces the fourth and fifth new feature-folder top-levels since Phase 5/6 (Phase 7's `lib/features/super_admin/`, Phase 8's `lib/features/locations/`, Phase 9's `lib/features/currencies/`, and now Phase 10's `lib/features/listing_form/` AND `lib/features/publisher_dashboard/`). It also introduces a new validators directory `lib/core/validators/` (new top-level under `lib/core/`); extends the existing Phase 5 publisher-dashboard tile gate; adds three new `go_router` routes under `/publisher/listings/...`; adds ~40 new ARB keys to both `app_ar.arb` and `app_en.arb`; alters one Phase 8 table (`public.areas`).

**Performance Goals**:

- Multi-step form first-step render on cold open: under 1 second on the reference Infinix Note 8 (one read of `SELECT * FROM public.listings WHERE id=<draft_id>` + cached LocationPicker + cached currency dropdown).
- LocationPicker cascading-dropdown response (governorate → city → area): under 200ms per cascade level (relies on Phase 8's existing indices).
- Inline price preview via `MoneyFormatter`: under 10ms per keystroke (no I/O; pure-Dart formatting).
- `submit_listing` RPC end-to-end latency: under 200ms server-side + one round-trip; under 1 second total observed on the reference device.
- `MyListingsPage` initial render: under 1 second (one paginated read of `SELECT * FROM public.listings WHERE publisher_user_id=auth.uid() AND status<>'deleted' ORDER BY created_at DESC LIMIT 20`).
- Status-filter chip switch: under 500ms (filter applied client-side on the already-loaded page set).
- Form auto-save on step transition: under 500ms server-side (one UPDATE on the draft row).
- Migration apply (seven migrations) against the remote project: under 90 seconds total (the area-centroid seed migration is the heaviest, ~50–100 row UPSERTs).

**Constraints**:

- Constitution II (Source-Controlled Backend) binding: every backend artifact is a checked-in `.sql` file under `supabase/migrations/` or `supabase/policies/`. No Studio-only edits. The `submit_listing` RPC body is checked in as part of migration 6; no parallel `supabase/functions/submit_listing/` TypeScript folder is created (R-06).
- Constitution III (Security-First Supabase, NON-NEGOTIABLE): all five new tables have RLS enabled. The `public.listings` SELECT policy admits anonymous readers only for `status='approved'` rows within the publish window; child-table SELECT policies join through `listings` to derive the same gate. Write-side policies require `auth.uid() = publisher_user_id` AND the publisher's profile-status pair both `approved`; admin writes are gated by `current_user_has_permission('listings.edit_any')`. The `listing_status_history` table has NO UPDATE policy and NO DELETE policy — append-only by design (FR-007). The `submit_listing` RPC is `SECURITY DEFINER` but re-checks all of the publisher-status precondition + the Q1 required-field set in its body. The status-transition trigger AND the audit-trigger group cover every status change emanating from any path (RPC, RLS-gated direct UPDATE, admin script, Phase 12's `approve_listing` / `reject_listing`).
- Constitution VII (Dynamic Roles & Permissions) preserved: no new permission key (FR-008). The existing Phase 6 keys (`listings.view_all`, `listings.approve`, `listings.reject`, `listings.edit_any`, `listings.delete_any`) cover every admin surface; owner-default capabilities cover the publisher's own listings. Every write surface consults `PermissionChecker` client-side and `current_user_has_permission()` server-side (admin paths); owner paths rely on the `auth.uid()=publisher_user_id` predicate.
- Constitution VIII (Approval Workflow & Publisher Identity) is the central principle this phase advances: the publisher-side leg of the approval pipeline ships here. The "Create listing" tile is hidden for non-approved publishers; the route guard refuses deep links; RLS denies INSERT/UPDATE from non-approved sessions. Listings are NOT public until Phase 12 flips `status='approved'`; the public-read RLS is already in place so Phase 12 only needs to set the status.
- Constitution IX (Future Backend Portability): `lib/features/listing_form/domain/` and `lib/features/publisher_dashboard/domain/` import nothing from `package:supabase_flutter`. Only the `data/datasources/...` and `data/repositories/...` files touch Supabase types. The three new validators under `lib/core/validators/` are pure Dart (no Supabase imports).
- Constitution V (Arabic-First Localization): every user-visible chrome string flows through `AppLocalizations`. Bilingual data labels (governorate / city / area names from Phase 8; currency names from Phase 9) come from the respective tables' bilingual columns. Field labels, step headers, status badges, validator errors, rejection-reason rendering, and the `submit_listing` structured error responses all flow through ARB. Arabic copy is Syrian-friendly per Constitution V.
- Migrations apply to the **remote** Supabase project via Supabase MCP `apply_migration` (inherited from Phase 4 R-01).
- Migrations MUST be idempotent (Supabase migration tracker + idempotent constructs in the bodies: `CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER IF EXISTS ... CREATE TRIGGER`, `DROP POLICY IF EXISTS ... CREATE POLICY`, `ON CONFLICT ... DO NOTHING` for seeds, `DO $$ BEGIN IF NOT EXISTS ... END $$` for constraint adds). The project memory `project_supabase_mcp_apply_migration.md` is binding.
- The `log_audit()` reusable trigger function is invoked unchanged for the new audit-trigger group on `public.listings` (R-05 invariant preserved a SEVENTH time across Phases 4/5/6/7/8/9/10).
- **Zero new packages** in `pubspec.yaml`.
- No new permission keys (FR-008).

**Scale/Scope**:

- **Seven new SQL migration files** under `supabase/migrations/` named with synthetic-monotonic 14-digit timestamps `20260519120001` through `20260519120007`, ordered after Phase 9's `20260518120005_phase9_advisor_hardening.sql`. The seven migrations:
  1. `20260519120001_alter_areas_add_centroids.sql` — `ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS centroid_lat NUMERIC(9, 6)` + `ADD COLUMN IF NOT EXISTS centroid_lng NUMERIC(9, 6)`. Then a `UPDATE public.areas SET (centroid_lat, centroid_lng) = ('<seed_data>') WHERE id='<area_id>'` block per area (manually-researched OpenStreetMap centroids checked into the migration as inline VALUES). Then `ALTER TABLE public.areas ALTER COLUMN centroid_lat SET NOT NULL` + `centroid_lng SET NOT NULL`. Plus a `CHECK (centroid_lat BETWEEN 32 AND 37 AND centroid_lng BETWEEN 35 AND 43)` constraint matching the Syrian-bounds rule. Per R-07. (FR-013a, SC-023.)
  2. `20260519120002_create_listings.sql` — `CREATE TABLE public.listings` per the column shape above with all CHECK constraints + FK references to `public.governorates`/`cities`/`areas` (`ON DELETE RESTRICT`) + FK reference to `auth.users(id) ON DELETE CASCADE` on `publisher_user_id`. `agency_id UUID NULL` with NO FK (Phase 19 adds it). `ENABLE ROW LEVEL SECURITY`. Attach Phase 4's `set_updated_at` trigger. Bundle inline + parallel-file SELECT policy (public when `status='approved'` AND publish-window open; owner-all; admin via `listings.view_all`) and write policies (owner-INSERT when `publisher_status='approved'` AND `account_status='approved'`; owner-UPDATE when own + `status IN ('draft','rejected')`; admin via `listings.edit_any`/`delete_any`).
  3. `20260519120003_create_listing_details.sql` — `CREATE TABLE public.listing_details` with `listing_id UUID PRIMARY KEY REFERENCES public.listings(id) ON DELETE CASCADE` + columns per FR-003 + RLS enabled + Phase 4 `set_updated_at` trigger + SELECT/INSERT/UPDATE/DELETE policies deriving ownership through the parent listing.
  4. `20260519120004_create_listing_prices.sql` — `CREATE TABLE public.listing_prices` with the Phase 9 forward-stated `UNIQUE(listing_id, currency_code)` + the partial unique index `(listing_id) WHERE is_primary=true` enforcing exactly one primary + RLS + parent-derived policies.
  5. `20260519120005_create_listing_visibility.sql` — `CREATE TABLE public.listing_visibility` with `listing_id UUID PRIMARY KEY REFERENCES public.listings(id) ON DELETE CASCADE` + RLS + parent-derived policies. Attach `listing_visibility_sync_trigger` on `public.listings` UPSERTing the child row whenever the parent's `location_visibility` changes.
  6. `20260519120006_create_listing_status_history.sql` — `CREATE TABLE public.listing_status_history` + RLS + append-only INSERT policy gated by `pg_trigger_depth() > 0` (no UPDATE, no DELETE policy). Attach `listing_status_transition_trigger` on `public.listings` (`AFTER INSERT` + `AFTER UPDATE OF status`) appending one history row per fire. Attach Phase 4's `log_audit()` audit-trigger group on `public.listings` emitting `listing.created/.updated/.deleted` plus status-delta verbs. The trigger ordering matters: status-transition first (writes the operational history row), audit-trigger second (writes the compliance trail) — both fire on the same UPDATE, both commit atomically.
  7. `20260519120007_create_submit_listing_rpc.sql` — `CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id UUID) RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth` with the body per FR-010 + FR-010a (permission preconditions, Q1 Full required-field validation, status flip, return JSONB).

- **Five new policy files** under `supabase/policies/`: `listings_policies.sql`, `listing_details_policies.sql`, `listing_prices_policies.sql`, `listing_visibility_policies.sql`, `listing_status_history_policies.sql`. Each file is a parallel copy of the inline-bundled SQL in the corresponding migration (the Phase 6 R-02 invariant — policies live in both source-of-truth files AND inline in the migration). Phase 4/5/6/7/8/9 policy files are NOT edited.

- **Six new/updated doc files** under `supabase/docs/`: `listings.md`, `listing_details.md`, `listing_prices.md`, `listing_visibility.md`, `listing_status_history.md` (all NEW — each describes the table's columns, RLS posture, trigger attachments, child-derived ownership pattern); `audit_logs.md` is updated to enumerate the new action keys (`listing.created/.updated/.deleted` + 7 status-delta verbs).

- **Two new feature folders** under `lib/features/`:

  - `lib/features/listing_form/` with full Constitution IV three-layer split:
    - `data/datasources/supabase_listings_datasource.dart` — reads/writes the parent + 3 child rows for a listing; calls `submit_listing` RPC via `supabase.rpc(...)`. Only file in this feature folder importing `package:supabase_flutter`.
    - `data/dtos/listing_dto.dart`, `listing_details_dto.dart`, `listing_price_dto.dart`, `listing_visibility_dto.dart`, `submit_listing_request_dto.dart`, `submit_listing_response_dto.dart` (matches the RPC's `{listing_id, status, submitted_at}` JSONB shape OR the `{error, missing_fields[]}` shape on failure).
    - `data/repositories/listings_repository_impl.dart` — only other file in the feature touching Supabase types.
    - `domain/entities/listing.dart`, `listing_details.dart`, `listing_price.dart`, `listing_visibility.dart`, `listing_status_history_entry.dart`, `submit_listing_result.dart`, `listing_form_state.dart` (a value object capturing the in-progress form state across all 7 steps with per-step completeness flags).
    - `domain/repositories/listings_repository.dart` — abstract interface.
    - `domain/usecases/load_or_create_draft.dart`, `save_form_step.dart`, `submit_listing.dart`, `delete_draft.dart`, `derive_area_centroid.dart` (the Q2 auto-fill helper consuming Phase 8's altered `public.areas` row), `validate_submit_payload.dart` (the FR-010a Q1 required-field check, runs client-side at Review; server re-runs it).
    - `presentation/bloc/listing_form_bloc.dart` — owns the multi-step form state (current step, in-progress draft, validation results, submit-in-progress, success/failure).
    - `presentation/pages/listing_form_page.dart` — the top-level form route; renders the current step.
    - `presentation/widgets/step_basics.dart`, `step_location.dart`, `step_details.dart`, `step_prices.dart`, `step_visibility.dart`, `step_media_placeholder.dart`, `step_review.dart` — seven step widgets.
    - `presentation/widgets/required_field_chip.dart`, `step_progress_indicator.dart`, `submit_failure_dialog.dart` (renders the `missing_fields[]` payload), `price_preview_subline.dart` (consumes Phase 9 `MoneyFormatter` for the inline price formatting).

  - `lib/features/publisher_dashboard/` with full Constitution IV three-layer split:
    - `data/datasources/supabase_publisher_dashboard_datasource.dart` — reads the publisher's listings + the most-recent status-history row per listing (for rejection-reason rendering).
    - `data/dtos/publisher_listing_dto.dart`, `listing_status_history_entry_dto.dart`.
    - `data/repositories/publisher_dashboard_repository_impl.dart`.
    - `domain/entities/publisher_listing.dart` — a value object combining the listing row + the most-recent history entry + computed flags (is_editable, has_rejection_reason).
    - `domain/repositories/publisher_dashboard_repository.dart` — abstract interface.
    - `domain/usecases/list_my_listings.dart` (paginated read with status filter).
    - `presentation/bloc/my_listings_bloc.dart` — owns the list state + filter.
    - `presentation/pages/my_listings_page.dart`, `publisher_dashboard_home_page.dart` (or extend the existing Phase 5 dashboard with the "Create listing" tile + the "My listings" entry).
    - `presentation/widgets/listing_card.dart`, `status_badge.dart`, `rejection_reason_block.dart`, `resubmit_cta.dart`, `status_filter_chip_row.dart`, `read_only_listing_preview.dart` (rendered when tapping a non-editable status).

- **One new directory** under `lib/core/`:

  - `lib/core/validators/area_size_validator.dart` — positive, ≤999,999 with a "seems too large" warning above 5,000.
  - `lib/core/validators/price_validator.dart` — positive, ≤NUMERIC(14,2) precision, decimal-count gated by the row's currency `display_decimals`.
  - `lib/core/validators/phone_validator.dart` — E.164 normalization, accepts Syrian local 09xxxxxxxx form normalizing to `+963...`.

- **Three updated existing files**:
  - `lib/app.dart` (or the equivalent `go_router` config) — registers three new routes: `/publisher/listings/create`, `/publisher/listings/<id>/edit`, `/publisher/dashboard/my-listings`. Each carries a redirect guard reading `profiles.publisher_status='approved' AND account_status='approved'`.
  - The Phase 5 publisher dashboard page — extended with the "Create listing" tile gated by the same approved-pair check, and a "My listings" entry tile that navigates to `/publisher/dashboard/my-listings`.
  - `lib/core/routing/auth_redirect.dart` — extended with the publisher-status check for `/publisher/listings/*` routes.

- **One altered existing Phase 8 table**: `public.areas` gains `centroid_lat` + `centroid_lng` columns + a seed of ~50–100 manually-researched OpenStreetMap centroids checked into migration 1's inline VALUES (R-07).

- **One smoke-test surface**: a dev-only `ListingFormShowcasePage` mounted under a debug route exercising the multi-step form with mock data. The Q1 validation goldens and the validator goldens are exercised via the quickstart manual-verification checklist.

- **ARB key delta** on `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`: approximately 40 new strings for the form's 7 step headers + ~15 field labels + ~6 validator messages + 9 status badge labels + the rejection-reason rendering + the resubmit CTA + the media placeholder banner + ~5 structured-error keys from `submit_listing` (`missing_fields_title`, `missing_field_<name>` for each Q1 required field). The Q1-related field labels (`field_label_title`, `field_label_governorate`, `field_label_city`, `field_label_area`, `field_label_address_text`, `field_label_area_size`, `field_label_rooms`, `field_label_bathrooms`, `field_label_phone`, `field_label_whatsapp`) flow through ARB. All keys ship to both ARB files in the same commit per Phase 3's localization gate.

- **Zero new packages** in `pubspec.yaml`.

- **0 new tests** (durable no-new-tests rule).

- **0 changes** to `.github/workflows/ci.yml`.

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists; `/speckit-specify` produced a complete spec with 7 user stories, 21 FRs, 24 SCs; `/speckit-clarify` Session 2026-05-18 resolved Q1 (Full required-field set), Q2 (area-centroid auto-fill), Q3 (single-currency-only across every Phase 10 surface). No implementation has begun. |
| II. Source-Controlled Backend | **Pass** | Every Phase 10 backend artifact lives as a checked-in file: 7 migrations under `supabase/migrations/`, 5 new policy files under `supabase/policies/`, 5 new doc files + 1 updated doc file under `supabase/docs/`. The `submit_listing` RPC body is checked in as part of migration 7 — there is no out-of-band TypeScript code. No artifact lives only in Studio. The area-centroid seed is codified in migration 1's inline VALUES. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | RLS is enabled on all five new tables. The `public.listings` SELECT policy admits anonymous readers only when `status='approved'` AND the publish window is open — no broad anon carve-out (the project-wide carve-out count remains at three: Phase 8's locations + Phase 9's currencies group; Phase 10 does NOT add a fourth). Child-table SELECT policies derive the same gate through the parent. Write-side policies require `auth.uid()=publisher_user_id` AND the publisher's profile-status pair both `approved`. The `listing_status_history` table has NO UPDATE policy and NO DELETE policy — append-only by design (FR-007). The `submit_listing` RPC is `SECURITY DEFINER` but re-checks all preconditions in its body. Audit-trigger coverage is universal — every mutation through any path emits the correct count of `audit_logs` rows. |
| IV. Clean Architecture Flutter | **Pass** | `lib/features/listing_form/` and `lib/features/publisher_dashboard/` are full three-layer Clean Architecture feature folders (`data/`, `domain/`, `presentation/`). BLoCs own state; use cases live in `domain/usecases/`; repositories are abstract in `domain/repositories/` with Supabase-touching impls in `data/repositories/`. No widget calls Supabase; no use case imports Supabase. The three new validators under `lib/core/validators/` are pure Dart utilities consumed by the form widgets. |
| V. Arabic-First Localization | **Pass** | All ~40 new user-visible chrome strings flow through Phase 3's `AppLocalizations`. Bilingual data labels (governorate / city / area names from Phase 8; currency names from Phase 9) come from the respective tables' bilingual columns, not from ARB. RTL is honored: form steps, status badges, rejection-reason blocks all use `EdgeInsetsDirectional` and direction-aware text. The Phase 3 localization lint guard catches any hardcoded user-facing string at PR review. |
| VI. Theme System & Design Tokens | **Pass** | Every new widget under `lib/features/listing_form/presentation/` and `lib/features/publisher_dashboard/presentation/` consumes Phase 2's `ListTile` / Chip / Card / Button / Dialog / FormField primitives. The status badges use Phase 2 color tokens for the per-status palette. No inline hex / font-size / padding in any new widget. |
| VII. Dynamic Roles & Permissions | **Pass** | Phase 10 introduces zero new permission keys (FR-008). The existing Phase 6 keys (`listings.view_all`, `listings.approve`, `listings.reject`, `listings.edit_any`, `listings.delete_any`) cover every admin surface; owner-default capabilities cover the publisher's own listings. The publisher-status gate (`profiles.publisher_status='approved' AND account_status='approved'`) is checked in three layers: UX tile hide (`PermissionChecker.userIsApprovedPublisher` helper), router guard (`auth_redirect.dart` extended), RLS deny on direct writes. Audit emission is universal: 10 new action keys (`listing.created/.updated/.deleted` + 7 status-delta verbs) cover every mutation path. |
| VIII. Approval Workflow & Publisher Identity | **Pass** | Phase 10 ships the publisher-side leg of the approval workflow. Non-approved users (`pending` / `rejected` / `suspended` on either `publisher_status` or `account_status`) are refused at all three layers. Listings are NOT public until Phase 12 flips `status='approved'`; the public-read RLS is already in place so Phase 12 only needs to set the status. Rejection-reason rendering on `MyListingsPage` carries the most-recent `listing_status_history.reason` text — the Phase 12 admin's rejection reason will surface to the publisher per the resubmit loop (US3). Publisher private fields (phone, whatsapp) are stored on the parent `listings` row with `contact_name_visibility` controlling per-listing exposure (Phase 13+ owns the rendering); Phase 10 does not modify the Phase 5/19 publisher-identity Vault columns. |
| IX. Future Backend Portability | **Pass** | `lib/features/listing_form/domain/` and `lib/features/publisher_dashboard/domain/` import nothing from `package:supabase_flutter` — verifiable by `grep -R "package:supabase_flutter" lib/features/listing_form/domain lib/features/publisher_dashboard/domain` returning zero results post-implementation. The three new validators under `lib/core/validators/` are pure Dart with only standard-library + `decimal` imports. Only the `data/datasources/` and `data/repositories/` files touch Supabase types. |
| X. Testable AI Workflow | **Pass — Justified.** | Per `feedback_no_new_tests.md` carried forward from Phases 3–9, every FR is verifiable via a manual SQL action with expected output OR via Supabase MCP `execute_sql` / `list_tables` / `get_advisors` calls OR via a manual UI walk on the reference device. The validator golden cases are codified in `quickstart.md` as a manual-verification checklist instead of an automated unit-test file. The constitution explicitly permits "a SQL query with expected output" or "a UI action with expected screen state" as acceptance steps. No constitutional amendment is required. |
| XI. Android-First MVP | **Pass** | All Flutter additions target the Android Flutter build only; no platform-conditional code. The remote Supabase backend is platform-neutral. Zero new packages; no new platform plugins. |
| XII. No Hidden Product Decisions | **Pass** | All three Session 2026-05-18 clarifications (Q1, Q2, Q3) are captured in `spec.md` `## Clarifications`. The R-06 deviation from the implementation plan's "Edge Function `submit_listing`" text to "SECURITY DEFINER RPC `submit_listing`" is recorded in research R-06 AND added as a new spec Assumption ("`submit_listing` implementation surface") so the spec and plan agree on the implementation surface. The R-07 area-centroid data-source path (ALTER `public.areas` + seed) is recorded in research and surfaced in spec FR-013a + this plan's Storage section. The decisions are surfaced in the spec's Assumptions section, in `data-model.md`'s schema definitions, and in this plan's Storage and Constraints sections. The plan-time deferral list in `checklists/requirements.md` is empty (all three Qs resolved). |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/010-listing-creation/
├── plan.md                    # This file
├── research.md                # Phase 0 — locked tech decisions (R-01..R-NN)
├── data-model.md              # Phase 1 — the 5 new tables + 1 altered Phase 8 table + 1 status-transition trigger + 1 sync trigger + 1 audit-trigger group + 1 RPC + 5 RLS policy files + the area-centroid seed inventory + the BLoC + entity + use-case shapes for the 2 new feature folders + the validator API shapes + the ARB key inventory + per-FR / per-SC verification map
├── quickstart.md              # Phase 1 — 14-step end-to-end manual verification recipe via Supabase MCP execute_sql + Flutter device walk on Infinix Note 8 + Q1 required-field goldens + validator goldens
├── contracts/                 # Phase 1 — 13 interface contracts
│   ├── phase10-tables.md                       # 5 new tables: column shapes, FKs, CHECK constraints, RLS-enabled state
│   ├── phase10-altered-areas.md                # public.areas centroid columns + seed inventory + Syrian-bounds CHECK
│   ├── phase10-status-transition-trigger.md    # listing_status_transition_trigger contract: AFTER INSERT + AFTER UPDATE OF status; append-only history-row emission
│   ├── phase10-audit-triggers.md               # log_audit() reuse for the 10 new action keys (listing.created/.updated/.deleted + 7 status-delta verbs)
│   ├── phase10-rls-policies.md                 # 5-table policy inventory: public-when-approved SELECT, owner write gated by approved-pair, admin write via listings.edit_any/delete_any, listing_status_history append-only via pg_trigger_depth()
│   ├── phase10-v-publisher-listings.md         # v_publisher_listings view contract: LEFT JOIN LATERAL for most-recent history + LEFT JOIN listing_prices(is_primary) + RLS inheritance + GRANT SELECT TO authenticated
│   ├── submit-listing-rpc.md                   # SECURITY DEFINER RPC contract: signature, precondition checks, Q1 Full required-field validation, status flip, JSONB return shape, SQLSTATE error contract
│   ├── listing-form-pages.md                   # Multi-step form: 7 steps, per-step widgets, BLoC events, auto-save granularity, Q1 validation surface, Q2 centroid auto-fill, Q3 single-currency
│   ├── my-listings-page.md                     # MyListingsPage contract: status filter chips, sort order, rejection-reason rendering, resubmit CTA, read-only preview path
│   ├── area-centroid-autofill.md               # FR-013a contract: lookup, step-block on missing data, no-publisher-override invariant
│   ├── validators.md                           # 3 validator APIs (AreaSizeValidator, PriceValidator, PhoneValidator) + per-validator golden inputs/outputs
│   ├── listings-routing.md                     # 3 new go_router routes + publisher-status redirect guards + the publisher-dashboard tile gate
│   └── listings-localization.md                # ARB key inventory + Syrian-friendly Arabic copy + status-badge label set + structured-error key shape
├── checklists/
│   └── requirements.md        # From /speckit-specify + /speckit-clarify (all 3 Qs resolved; checklist fully green)
├── spec.md                    # From /speckit-specify + /speckit-clarify (Q1=B Full, Q2=A centroid auto-fill, Q3=A single-currency)
├── tasks.md                   # Created by /speckit-tasks (NOT by /speckit-plan)
├── DEFERRED.md                # Created during /speckit-implement; reviewed at squash-merge per project_deferred_work.md
└── HANDOFF.md                 # Created at /speckit-implement close-out (or omit if no follow-up scope)
```

### Source Code (repository root)

```text
supabase/
├── config.toml                                            # (existing) NO CHANGE in Phase 10.
├── seed.sql                                               # (existing) NO CHANGE — Phase 10 seed (area centroids) lives inline in migration 1.
├── migrations/
│   ├── (existing Phase 1/4/5/6/7/8/9 migrations)         # NO CHANGE.
│   ├── 20260519120001_alter_areas_add_centroids.sql      # NEW — ALTER public.areas ADD centroid_lat + centroid_lng (initially NULL), UPDATE per-area inline VALUES seed from OpenStreetMap, ALTER SET NOT NULL, CHECK (centroid_lat BETWEEN 32 AND 37 AND centroid_lng BETWEEN 35 AND 43). (FR-013a, R-07, SC-023.)
│   ├── 20260519120002_create_listings.sql                # NEW — CREATE TABLE public.listings per the 24-column shape; ENABLE RLS; attach set_updated_at trigger; bundle inline + parallel-file SELECT policy (public when status='approved' + publish-window-open; owner-all; admin via listings.view_all) and write policies (owner gated by approved-pair; admin via listings.edit_any/delete_any). (FR-001/002/005/006.)
│   ├── 20260519120003_create_listing_details.sql         # NEW — CREATE TABLE public.listing_details (1:1 with listings); ENABLE RLS; attach set_updated_at trigger; bundle policies deriving ownership through parent. (FR-003.)
│   ├── 20260519120004_create_listing_prices.sql          # NEW — CREATE TABLE public.listing_prices with Phase 9 forward-stated UNIQUE(listing_id, currency_code) + partial unique index (listing_id) WHERE is_primary=true + FK to currencies(code) ON DELETE RESTRICT + CHECK (amount > 0). ENABLE RLS; bundle parent-derived policies. (FR-003, SC-008, SC-009, SC-022.)
│   ├── 20260519120005_create_listing_visibility.sql      # NEW — CREATE TABLE public.listing_visibility (1:1); ENABLE RLS; attach listing_visibility_sync_trigger on public.listings to maintain duplicated location_visibility column; bundle parent-derived policies. (FR-003.)
│   ├── 20260519120006_create_listing_status_history.sql  # NEW — CREATE TABLE public.listing_status_history; ENABLE RLS; INSERT-only policy gated by pg_trigger_depth() > 0; NO UPDATE policy, NO DELETE policy. Attach listing_status_transition_trigger on public.listings (AFTER INSERT + AFTER UPDATE OF status) appending one history row per fire. Attach log_audit() trigger group on public.listings emitting the 10 new action keys. (FR-004, FR-004a, FR-007.)
│   └── 20260519120007_create_submit_listing_rpc.sql      # NEW — CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id UUID) RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth with the body per FR-010 + FR-010a. (FR-010, FR-010a, SC-010, SC-011.)
├── policies/                                              # (existing dir)
│   ├── (existing Phase 4/5/6/7/8/9 policy files)         # NO CHANGE.
│   ├── listings_policies.sql                              # NEW — mirror of migration 2's inline policies.
│   ├── listing_details_policies.sql                       # NEW — mirror of migration 3's inline policies.
│   ├── listing_prices_policies.sql                        # NEW — mirror of migration 4's inline policies.
│   ├── listing_visibility_policies.sql                    # NEW — mirror of migration 5's inline policies.
│   └── listing_status_history_policies.sql                # NEW — mirror of migration 6's inline policies (append-only invariant).
├── functions/                                             # (existing dir)
│   └── (existing Phase 5/7 functions)                     # NO CHANGE — Phase 10 introduces no Edge Functions; submit_listing is an RPC per R-06.
└── docs/                                                  # (existing dir)
    ├── (existing Phase 4/5/6/7/8/9 doc files)            # NO CHANGE except audit_logs.md.
    ├── listings.md                                        # NEW — describes the parent table, RLS posture, trigger attachments.
    ├── listing_details.md                                 # NEW — describes the 1:1 extension table, parent-derived policies.
    ├── listing_prices.md                                  # NEW — describes the row-per-currency table, Phase 9 forward-stated constraints, Phase-10 single-row-per-listing invariant per Q3.
    ├── listing_visibility.md                              # NEW — describes the visibility envelope, sync trigger, parent-column-authoritative pattern.
    ├── listing_status_history.md                          # NEW — describes the append-only history table, trigger writes, RLS posture.
    └── audit_logs.md                                      # UPDATE — enumerate the 10 new action keys: listing.created/.updated/.deleted + listing.submitted/.approved/.rejected/.paused/.expired/.sold/.rented.

lib/
├── main.dart                                              # (existing) NO CHANGE.
├── app.dart                                               # UPDATE — register three new go_router routes: /publisher/listings/create, /publisher/listings/<id>/edit, /publisher/dashboard/my-listings.
├── core/                                                  # (existing)
│   ├── di/
│   │   ├── injection.dart                                 # NO CHANGE.
│   │   └── injection.config.dart                          # AUTO-REGEN — codegen adds entries for the 2 new repos, ~6 use cases, ~3 BLoCs.
│   ├── routing/
│   │   └── auth_redirect.dart                             # UPDATE — extend with /publisher/listings/* redirect guards checking publisher_status + account_status both 'approved'.
│   ├── security/
│   │   └── permission_checker.dart                        # UPDATE — add userIsApprovedPublisher helper reading profiles.publisher_status + account_status from the cached profile. NO new permission keys (FR-008).
│   └── validators/                                        # NEW DIRECTORY — pure Dart validation utilities.
│       ├── area_size_validator.dart                       # NEW — positive, ≤999999, warning above 5000.
│       ├── price_validator.dart                           # NEW — positive, ≤NUMERIC(14,2), currency.displayDecimals-aware.
│       └── phone_validator.dart                           # NEW — E.164 normalization with Syrian-prefix recognition.
├── shared/                                                # (existing — Phase 9)
│   ├── domain/value_objects/money.dart                    # NO CHANGE — consumed by the form's price step.
│   └── presentation/money_formatter.dart                  # NO CHANGE — consumed by the price-preview-subline widget.
├── features/                                              # (existing)
│   ├── admin/                                             # (existing — Phase 5+6+7+8+9) NO CHANGE in Phase 10 — Phase 12 will edit the admin home for the listing-approval queue.
│   ├── auth/                                              # (existing) NO CHANGE.
│   ├── currencies/                                        # (existing — Phase 9) NO CHANGE.
│   ├── home/                                              # (existing) NO CHANGE.
│   ├── locations/                                         # (existing — Phase 8) NO CHANGE — Phase 10 consumes Phase 8's LocationPicker as-is.
│   ├── onboarding/                                        # (existing) NO CHANGE.
│   ├── profile/                                           # (existing — Phase 5 + Phase 9 preferred-currency toggle) UPDATE one file — the publisher-dashboard tile gate adds the "Create listing" tile + the "My listings" entry tile, both gated by the approved-pair check. (Exact filename verified at implement time — likely lib/features/profile/presentation/pages/publisher_dashboard_page.dart from Phase 5.)
│   ├── super_admin/                                       # (existing — Phase 7) NO CHANGE.
│   ├── listing_form/                                      # NEW FEATURE FOLDER — full Clean Architecture three-layer split.
│   │   ├── data/
│   │   │   ├── datasources/supabase_listings_datasource.dart
│   │   │   ├── dtos/{listing,listing_details,listing_price,listing_visibility,submit_listing_request,submit_listing_response}_dto.dart
│   │   │   └── repositories/listings_repository_impl.dart
│   │   ├── domain/
│   │   │   ├── entities/{listing,listing_details,listing_price,listing_visibility,listing_status_history_entry,submit_listing_result,listing_form_state}.dart
│   │   │   ├── repositories/listings_repository.dart
│   │   │   └── usecases/{load_or_create_draft,save_form_step,submit_listing,delete_draft,derive_area_centroid,validate_submit_payload}.dart
│   │   └── presentation/
│   │       ├── bloc/listing_form_bloc.dart
│   │       ├── pages/listing_form_page.dart
│   │       └── widgets/{step_basics,step_location,step_details,step_prices,step_visibility,step_media_placeholder,step_review,required_field_chip,step_progress_indicator,submit_failure_dialog,price_preview_subline}.dart
│   └── publisher_dashboard/                               # NEW FEATURE FOLDER — full Clean Architecture three-layer split.
│       ├── data/
│       │   ├── datasources/supabase_publisher_dashboard_datasource.dart
│       │   ├── dtos/{publisher_listing,listing_status_history_entry}_dto.dart
│       │   └── repositories/publisher_dashboard_repository_impl.dart
│       ├── domain/
│       │   ├── entities/publisher_listing.dart
│       │   ├── repositories/publisher_dashboard_repository.dart
│       │   └── usecases/list_my_listings.dart
│       └── presentation/
│           ├── bloc/my_listings_bloc.dart
│           ├── pages/my_listings_page.dart
│           └── widgets/{listing_card,status_badge,rejection_reason_block,resubmit_cta,status_filter_chip_row,read_only_listing_preview}.dart
└── l10n/                                                  # (existing)
    ├── app_ar.arb                                         # UPDATE — add ~40 new ARB keys for form chrome, validators, status badges, rejection-reason rendering, submit_listing structured errors.
    └── app_en.arb                                         # UPDATE — add the same ~40 keys in English. Both files updated in the same commit per Phase 3 localization gate.

pubspec.yaml                                               # NO CHANGE — zero new packages.
```

**Structure Decision**: The feature follows the project's established Mobile + Backend pattern (same as Phases 5–9). Backend artifacts (7 migrations + 5 policy files + 6 doc files) live under `supabase/`; Flutter artifacts (2 new feature folders + 1 new core directory + 3 updated existing files + ~40 new ARB keys) live under `lib/`. The two new feature folders `lib/features/listing_form/` and `lib/features/publisher_dashboard/` mirror Phases 7/8/9's feature-folder structure: `data/`, `domain/`, `presentation/` per Constitution IV. The three validators live under `lib/core/validators/` (not under either feature folder) because they are pure utility code consumed across both folders. The form's price step consumes Phase 9's `MoneyFormatter` and `Money` value object via `lib/shared/` imports unchanged. Phase 8's `LocationPicker` is consumed verbatim by the form's location step per SC-021. The `submit_listing` RPC is the only server-side mutation surface — direct UPDATEs against `public.listings` to flip status are forbidden by the RLS policies for non-admin paths.

## Complexity Tracking

> **No constitutional violations. This section is intentionally empty.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | — | — |
