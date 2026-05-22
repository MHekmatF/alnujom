# Research: Listing Creation & Submit-for-Review

**Owner**: Phase 10 (`specs/010-listing-creation/`).
**Created**: 2026-05-18
**Status**: Locked. All decisions below are binding inputs to `plan.md`, `data-model.md`, `contracts/`, `tasks.md`, and the implementation.

Phase 10 makes **20 locked technical decisions** (R-01 through R-20). Phase 9 introduced 22 decisions; Phase 10 reuses 12 of them unchanged via the carry-forward pattern and introduces 8 net-new decisions (R-06 RPC vs Edge Function for `submit_listing`, R-07 area-centroid data-source path, R-09 status-transition trigger vs `log_audit` separation, R-10 NUMERIC(14,2) for `listing_prices.amount`, R-11 listing_visibility parent-column-authoritative sync trigger, R-12 partial unique index on `listing_prices(is_primary)`, R-13 the seven-step form's step-transition auto-save granularity, R-19 publisher-status three-layer enforcement helper at `lib/core/security/`).

---

## R-01 — Migration filename convention (date-prefixed, monotonic per phase) *(carry-forward)*

**Decision**: Phase 10 uses the same synthetic-monotonic 14-digit timestamp prefix pattern Phase 4/5/6/7/8/9 use: `20260519120001_` through `20260519120007_`. The date encodes "May 19, 2026" — one day after Phase 9's `20260518...` series.

**Rationale**: The migration tracker orders by filename ASCII-sort; date-prefixed names are correctly ordered even after long pauses or interleaved chore branches. The IMPLEMENTATION_PLAN's reference to `0016_create_listings.sql` etc. is historical drift; the actual project uses date-prefixed names per the Phase 4 R-01 lock-in.

**Alternatives considered**: Pure descriptive integers (`0016_`) rejected because brittle when phases run out of order; ISO 8601 (`2026-05-19T12:00:01Z_`) rejected because Supabase's migration tracker doesn't tolerate non-numeric prefix characters.

---

## R-02 — Inline policy bundling + parallel policy files *(carry-forward)*

**Decision**: Phase 10's five RLS policy declarations live inline in their respective table-creation migrations (`20260519120002` through `20260519120006`), AND are mirrored to source-of-truth files at `supabase/policies/listings_policies.sql`, `listing_details_policies.sql`, `listing_prices_policies.sql`, `listing_visibility_policies.sql`, `listing_status_history_policies.sql`. Both copies are kept in sync at PR review time.

**Rationale**: The Phase 4 R-02 invariant — policies are reviewable as standalone files AND apply atomically with their table — is preserved a seventh time across Phases 4/5/6/7/8/9/10.

**Alternatives considered**: Policy-only in dedicated files (no inline) rejected because the migration would create the table with RLS enabled but no policies — a transient deny-all window for any concurrent reader; inline-only rejected because reviewers lose the standalone-file scannability.

---

## R-03 — Zero new packages in `pubspec.yaml` *(carry-forward)*

**Decision**: Phase 10 introduces ZERO new runtime packages in `pubspec.yaml`. Every dependency the new code requires is already locked from Phases 1 / 9 / earlier: `flutter_bloc`, `equatable`, `decimal` (added in Phase 9 for Money), `intl`, `go_router`, `supabase_flutter`, `get_it`, `injectable`. No new dev packages.

**Rationale**: Phase 10 reuses Phase 8's `LocationPicker`, Phase 9's `Money` value object + `MoneyFormatter`, Phase 6's `PermissionChecker`, Phase 5's auth/profile flows — all without introducing new third-party code. The form chrome, validators, and BLoC implementations all use stdlib + already-locked packages.

**Alternatives considered**: A form-builder package like `flutter_form_builder` rejected because the seven-step form's state shape is bespoke (per-step auto-save, Q1 required-field validation, draft persistence across app lifecycle) and a generic form builder would force the implementation into its idioms; a phone-validation package like `intl_phone_field` rejected because Phase 5's `PhoneNumber` value object already provides E.164 normalization and the Phase 10 `PhoneValidator` is a thin adapter over that existing logic.

---

## R-04 — No anonymous SELECT carve-out on Phase 10 tables *(deviation from Phase 8/9 pattern, intentional)*

**Decision**: Unlike Phases 8 (`governorates` / `cities` / `areas`) and 9 (`currencies` / `exchange_rates`), Phase 10's five new tables do NOT carve out a broad anonymous SELECT policy. Instead, `public.listings` admits anonymous readers ONLY when `status='approved'` AND the publish window is open (`published_at IS NULL OR published_at <= now()`; `expires_at IS NULL OR expires_at > now()`); all four child tables follow the same gate via parent-derived subquery. `public.listing_status_history` is owner+admin-only — no anonymous access at all. The project-wide anonymous-carve-out count stays at three (Phase 8's locations group + Phase 9's currencies group); Phase 10 does NOT introduce a fourth.

**Rationale**: Listings are user-generated content with privacy implications — a publisher's draft contains their phone number, address, and unapproved price; exposing drafts to anonymous readers would violate Constitution VIII (Approval Workflow & Publisher Identity). The "public when approved" gate is the canonical Phase 13 (public listing details) read path; Phase 10 ships it pre-emptively so Phase 12's approval flip is a status change, not a policy change. The `listing_status_history` table is intentionally hidden from anonymous readers because it captures admin rejection reasons that are not public.

**Alternatives considered**: Anonymous SELECT on all listings rejected because drafts and pending_review listings would leak; anonymous SELECT on a `v_listings_public` view rejected because Phase 14 will need raw-table reads for search (the view is a Phase 14 / Phase 15 concept per IMPLEMENTATION_PLAN §Phase 14 / §Phase 15); split RLS — anon reads via view, owner/admin reads via table — rejected because the maintenance burden of two access paths exceeds the marginal complexity savings.

---

## R-05 — `log_audit()` reusable trigger function unchanged for a SEVENTH time *(carry-forward)*

**Decision**: Phase 10 attaches a new audit-trigger group to `public.listings` using Phase 4's `log_audit()` function unchanged. The action keys are: `listing.created` / `listing.updated` / `listing.deleted` for row-level mutations, PLUS seven status-delta verbs (`listing.submitted` / `listing.approved` / `listing.rejected` / `listing.paused` / `listing.expired` / `listing.sold` / `listing.rented`) computed inside the audit-trigger body from the OLD.status → NEW.status delta when both are present. The R-05 reusability invariant — `log_audit` unchanged across phases — is preserved a SEVENTH time across Phases 4/5/6/7/8/9/10.

**Rationale**: Phase 4's `log_audit(action, target_type, target_id, before_state, after_state)` signature is the canonical audit emission path; every phase that needs audit coverage attaches triggers passing the action name as `TG_ARGV[0]`. Phase 10 follows the precedent.

**Alternatives considered**: A new dedicated `log_listing_audit()` function for the status-delta verbs rejected because it duplicates `log_audit`'s body for no benefit — the delta computation can live in the trigger body itself before calling `log_audit` twice (once for `listing.updated`, once for the status-delta verb when status changed); skipping the status-delta verbs and relying on a downstream consumer to compute deltas from the audit-log JSON rejected because the audit-log table's action-key index is the natural query path for compliance reports ("how many listings were rejected last month").

---

## R-06 — `submit_listing` is a SECURITY DEFINER RPC, NOT a TypeScript Edge Function *(Phase 7 / Phase 9 carry-forward deviation from IMPLEMENTATION_PLAN literal text)*

**Decision**: Phase 10's status-flip mutation lives as a SECURITY DEFINER PL/pgSQL RPC at `public.submit_listing(p_listing_id UUID) RETURNS JSONB` — NOT as a TypeScript Edge Function under `supabase/functions/submit_listing/`. The IMPLEMENTATION_PLAN's literal "Edge Function `submit_listing`" wording is deviated from, identically to how Phase 7 deviated for `mutate_role` (Phase 7 Clarifications Q3) and Phase 9 deviated for `update_exchange_rate` (Phase 9 R-06). The spec's narrative preserves "Edge Function" language at the FR level for readability but the actual implementation is an RPC, surfaced as a spec Assumption.

**Rationale**: Same as Phase 7 / Phase 9. (a) A single migration is simpler than a separate TypeScript build/deploy step; the RPC is migration-tracked alongside the table schemas. (b) Atomic transaction semantics are automatic inside a PL/pgSQL function — the status flip + history insert (via the FR-004 trigger) + audit emission (via the FR-004a trigger) all commit together without explicit BEGIN/COMMIT management. (c) The Q1 Full required-field validation is naturally expressed in SQL — checking that `area_size IS NOT NULL AND area_size > 0` is a one-line condition; the equivalent TypeScript would need to either query the row again or accept the values as parameters and re-validate. (d) Phase 7 + Phase 9 already establish the RPC pattern; consistency reduces reviewer cognitive load. (e) `auth.uid()` is directly accessible inside the function; the TypeScript equivalent would need to plumb the JWT through the function context.

**Alternatives considered**: TypeScript Edge Function rejected for the reasons above; client-side-only status flip (no server function, just an RLS-gated UPDATE) rejected because the Q1 required-field validation needs server-side enforcement (a malicious client could craft an UPDATE bypassing the form's client-side check); a stored procedure called via a custom SQL view rejected because PostgREST's view-update semantics don't compose with the multi-row Q1 validation cleanly.

**Error mapping**: HTTP 403 ↔ SQLSTATE `42501` (insufficient_privilege); HTTP 400 ↔ SQLSTATE `22023` (invalid_parameter_value) with a structured `missing_fields[]` payload in the error `DETAIL`; HTTP 404 ↔ SQLSTATE `42704` (undefined_object); HTTP 500 ↔ any other unhandled SQLSTATE. The Flutter client maps SQLSTATE → user-facing localized errors per FR-019 / FR-024.

---

## R-07 — Area-centroid data-source path: ALTER `public.areas` + seed from OpenStreetMap

**Decision**: Per Q2's resolution, Phase 10 implements the centroid auto-fill by **altering Phase 8's `public.areas` table** to add `centroid_lat NUMERIC(9, 6) NOT NULL` and `centroid_lng NUMERIC(9, 6) NOT NULL` columns, seeded via a migration with manually-researched OpenStreetMap centroids for every existing area row (~50–100 Syrian areas across 14 governorates). The columns ship `NOT NULL` once the seed completes; future admin-added areas are required to carry centroids (Phase 8's location-admin UI is NOT extended in Phase 10 — that's deferred to either a Phase 8 follow-up patch or a future spec). The `public.areas.centroid_lat`/`centroid_lng` values become the source of truth for FR-013a's auto-fill; the Phase 10 form reads them at the moment the location step's "Continue" action commits and writes them to `listings.latitude`/`longitude` verbatim.

**Rationale**: This path aligns with the project's "Phase X row carries its own canonical data" pattern from Phases 4–9: data lives in the database, not in checked-in Flutter code. (a) When admins add new areas via Phase 8's admin UI (post-Phase-10), the form will need to refuse the new area until centroids are also provided — but the schema NOT NULL constraint forces the admin to provide them at insert time, which is a stronger guarantee than a Flutter-side static map. (b) The seed is bounded (~50–100 areas) and the OpenStreetMap centroids are publicly available + free. (c) Phase 15's map view will use these same centroids to render the area-centroid pin until the publisher revisits and adds an exact pin — Phase 10's data lays the groundwork for Phase 15 without Phase 15 having to backfill. (d) The Phase 8 spec explicitly forecasted this in DEFERRED.md ("Listings (Phase 10) are expected to carry their own coordinates, which Phase 15 will likely use directly for pin placement") — Phase 10 honors the forecast.

**Alternatives considered**: Path (ii) Flutter-side static map at `lib/features/locations/data/area_centroids.dart` rejected because admin-added areas would require a client redeploy to get centroids — slow feedback loop and admin-deploy coupling that the project explicitly avoids elsewhere. Path (iii) governorate-fallback (ALTER `public.governorates` instead) rejected because area-centroid resolution is meaningfully more useful than governorate-centroid resolution for Phase 15's map view (a Damascus listing pinned at "Damascus governorate centroid" is uselessly imprecise; "Al-Maliki area centroid" is roughly correct). External geocoder lookup at form time rejected because (a) it introduces a runtime network dependency on a third party, (b) Syria-sanctions risk with most geocoders, (c) the centroid resolution doesn't need to be dynamic — areas are a stable catalog.

**Seed source**: Centroids are sourced from OpenStreetMap nominatim (queried manually at plan time, NOT at run time). The migration file inlines the VALUES as a series of `UPDATE public.areas SET centroid_lat=..., centroid_lng=... WHERE id=...` rows or equivalent `INSERT ... ON CONFLICT` patterns. A `CHECK (centroid_lat BETWEEN 32 AND 37 AND centroid_lng BETWEEN 35 AND 43)` constraint guards against typos (Syria's bounding box).

---

## R-08 — Trigger-before-seed audit ordering invariant *(carry-forward, defensively preserved)*

**Decision**: Phase 10's audit-trigger group on `public.listings` is attached BEFORE any system-seeded listing rows would be inserted. Phase 10 does NOT actually seed any listing rows (the seed inventory is empty); this invariant is preserved defensively. The Phase 8 R-08 / Phase 9 R-08 precedent is maintained: trigger attachment precedes any seed `INSERT` in the table-creation migration, so any future fixture data would emit the correct audit rows with `actor_user_id=NULL`.

**Rationale**: The R-08 invariant is a phase-spanning safety net — even when a phase doesn't currently seed rows, preserving the ordering protects future spec authors from accidentally landing a fixture seed that bypasses audit emission.

**Alternatives considered**: Omitting the trigger-before-seed comment from the migration rejected because the next agent reading the migration would not know whether the ordering is load-bearing. The cost of a single line of comment is negligible.

---

## R-09 — Status-transition trigger and `log_audit` audit trigger are SEPARATE triggers

**Decision**: Phase 10 attaches TWO distinct triggers on `public.listings`:
1. `listing_status_transition_trigger` — an operational-record trigger that appends to `public.listing_status_history`. Fires `AFTER INSERT` and `AFTER UPDATE OF status`. The trigger function lives in migration 6 alongside the `listing_status_history` table.
2. The `log_audit()` audit-trigger group — the compliance trail trigger that emits to `public.audit_logs`. Fires `AFTER INSERT/UPDATE/DELETE`. Calls Phase 4's `log_audit` unchanged.

The two triggers serve different purposes and are queried by different consumers: the history table is operational (cheap, owner+admin readable, no compliance gating), the audit log is compliance (admin-only via `audit_logs.view` permission). Both fire on the same status-changing UPDATE and both commit in the same transaction.

**Rationale**: Combining the two into a single trigger would conflate operational and compliance concerns. Separating them lets each evolve independently (e.g., a future spec could change the history schema without affecting audit emission) and lets each be queried with the appropriate access controls.

**Alternatives considered**: A single trigger that writes to both tables rejected because the access controls diverge — operational reads are cheaper and broader, compliance reads are admin-only; trigger-on-trigger chaining (history trigger fires `log_audit`) rejected because it couples the audit trail to the operational history's schema, making future changes to either side risky.

---

## R-10 — `listing_prices.amount` precision: NUMERIC(14, 2)

**Decision**: `listing_prices.amount` is stored as `NUMERIC(14, 2)` — 12 integer digits + 2 fractional digits. This accommodates SYP-scale prices up to 999,999,999,999.99 (about 10^12) which covers any realistic real-estate price in the Syrian market with room to spare. Display-time rounding follows the row's `currency_code.display_decimals` from Phase 9 (SYP=0, USD=2), but the stored precision is uniformly 2 decimals at the schema level.

**Rationale**: A single NUMERIC precision across all currencies avoids per-currency schema complexity. The 12-integer-digit headroom handles SYP's high nominal values (a typical Damascus apartment in 2026 is ~750M SYP); the 2-decimal-digit tail handles USD/EUR's sub-unit precision. Display-time, the `MoneyFormatter` applies the currency's `display_decimals` rule for rendering (SYP shows 0 decimals even though stored as `.00`).

**Alternatives considered**: NUMERIC(18, 6) (matching Phase 9's `exchange_rates.rate`) rejected because the extra precision is unnecessary for listing prices and the wider column wastes storage; INTEGER cents (storing 1.50 USD as 150) rejected because the cents-vs-halalas-vs-SYP-units conversion logic would have to live in every consumer; NUMERIC without precision rejected because Postgres's unbounded NUMERIC is slightly more expensive to index.

---

## R-11 — `listing_visibility` parent-column-authoritative sync trigger

**Decision**: The `listings.location_visibility` column is authoritative; the duplicated `listing_visibility.location_visibility` column is maintained by a sync trigger `listing_visibility_sync_trigger` on `public.listings` that fires `AFTER INSERT OR UPDATE OF location_visibility` and UPSERTs the corresponding `listing_visibility` row. The form writes ONLY to the parent column; the trigger handles the propagation.

**Rationale**: The IMPLEMENTATION_PLAN §6.2 lists `location_visibility` on BOTH tables. Forward-stated Phase 15 will query `listing_visibility` for the narrow `(listing_id, location_visibility)` projection used by `v_listings_map` per IMPLEMENTATION_PLAN §Phase 15. Keeping the two in sync via a trigger (rather than expecting client code to write to both) eliminates a class of bug where the form forgets to update one of the two columns. The parent-authoritative direction is chosen because the parent row is the primary source-of-truth for the listing as a whole, and Phase 15 / Phase 13 / Phase 14 read the parent for most fields anyway.

**Alternatives considered**: Single source-of-truth on `listing_visibility` (drop the parent column) rejected because Phase 14's search and Phase 13's listing-card queries would need an extra join for every read — performance regression; bidirectional sync (writes to either side propagate) rejected because the directionality matters for consistency reasoning (writes ALWAYS go through the parent); manual application-level sync rejected because it forces every writer (Phase 10 form, Phase 12 admin edits, Phase 18 moderator overrides) to remember the duplication.

---

## R-12 — Partial unique index `(listing_id) WHERE is_primary=true` on `listing_prices`

**Decision**: `public.listing_prices` carries a partial unique index `CREATE UNIQUE INDEX listing_prices_one_primary_idx ON public.listing_prices (listing_id) WHERE is_primary = true` that enforces "exactly one `is_primary=true` row per listing" at the database level, defense-in-depth alongside the Phase 9 forward-stated `UNIQUE(listing_id, currency_code)` constraint.

**Rationale**: Phase 9's Q4 forward-statement enforces "at most one row per currency per listing", but does NOT enforce "exactly one primary per listing". Per Q3, every Phase 10 listing has exactly one row (which is by definition the primary), so this index is currently redundant — but it becomes load-bearing when a future spec adds multi-row entry. Adding the index in Phase 10 means Phase 10 ships a complete contract for the multi-row schema; the future spec doesn't have to add it later (which would require either a downtime migration or a partial-fill safety dance).

**Alternatives considered**: Skip the index, add it later rejected because future migration risk is asymmetric — partial unique indexes can fail if the data already violates the constraint, so adding it later requires verifying data integrity first; full `UNIQUE(listing_id, is_primary)` rejected because that would forbid two non-primary rows, which the multi-row contract DOES allow (Phase 9 Q4 only forbids duplicate currencies); application-level enforcement rejected because RLS + triggers + admin SQL paths all bypass application code.

---

## R-13 — Form step-transition auto-save granularity

**Decision**: The seven-step form auto-saves the in-progress `public.listings` draft row + its child rows on every step transition (forward AND backward). The auto-save commits before the new step renders. Failed auto-saves block the step transition with a localized error and a retry affordance. Auto-save granularity is per-step, not per-keystroke (which would generate excessive RPC traffic on slow connections).

**Rationale**: Per FR-014, in-progress form data is persisted on every step transition so a lifecycle suspend / app close / network drop never loses the publisher's input. Per-step granularity balances persistence completeness against network chattiness: a 7-step form generates ~7 saves per submission (vs ~500 keystrokes); on a 3G connection at 50ms/RTT, that's ~350ms of save overhead vs ~25s of save overhead. The trade-off is that if the publisher loses connectivity mid-step, the current step's edits are lost on app restart — acceptable per Q1's "draft may carry empty required fields indefinitely" stance.

**Alternatives considered**: Per-keystroke auto-save rejected for the network-chattiness reason; per-field-blur auto-save rejected because the form fields are bundled into per-step BLoC state and per-field saves would require finer state slicing; submit-only persistence rejected because it loses everything on lifecycle suspend.

---

## R-14 — Publisher-side draft persistence: single row mutated in place (not delete-and-recreate)

**Decision**: When a publisher edits a draft listing, the existing `public.listings` row is UPDATEd in place via per-step auto-save. The row's UUID `id` is preserved across edits. The same applies to the 1:1 child rows (`listing_details`, `listing_visibility`) and the single `listing_prices` row per Q3. When the publisher re-opens a rejected listing per US3, the same row continues to be UPDATEd; the listing's lineage is preserved across the full draft → pending_review → rejected → pending_review chain. Drafts are NEVER deleted-and-recreated by the form.

**Rationale**: Stable UUIDs let the audit trail and `listing_status_history` correctly attribute mutations to the same listing across its lifecycle. Delete-and-recreate would break the audit chain (the old listing's history would be orphaned) and would risk losing the original `created_at` timestamp.

**Alternatives considered**: Soft-delete + re-insert (mark old as `status='deleted'`, create new) rejected because it duplicates history and complicates the rejected-resubmit flow; pure delete + re-insert rejected for the same reason plus audit-trail orphaning.

---

## R-15 — Zero new permission keys *(carry-forward)*

**Decision**: Phase 10 introduces ZERO new permission keys. The Phase 6 catalog (§9.1) covers every admin surface: `listings.view_all` (admin SELECT on all listings), `listings.approve` / `listings.reject` (Phase 12), `listings.edit_any` (admin edit), `listings.delete_any` (super-admin). Owner-default capabilities cover the publisher's own listings via the `auth.uid()=publisher_user_id` predicate (no key required). The publisher-status gate (`profiles.publisher_status='approved' AND account_status='approved'`) is a profile-state check, not a permission check.

**Rationale**: Constitution VII's dynamic permission catalog should grow only when a new capability surface emerges. Phase 10's surfaces are either owner-default (auth-uid match) or covered by existing Phase 6 keys. Splitting "publisher" into a separate permission ("listings.create") rejected because the gate is conditional on profile state (publisher_status), not on a granted permission — it would be a check-twice (permission AND status) that adds complexity without security benefit.

**Alternatives considered**: New `listings.create` permission key rejected for the above reason; new `listings.draft` / `listings.submit` keys rejected because they would slice owner-default capabilities unnecessarily.

---

## R-16 — Public-read-when-approved RLS shipped in Phase 10 (not Phase 12)

**Decision**: The public-read policy `USING (status='approved' AND (published_at IS NULL OR published_at <= now()) AND (expires_at IS NULL OR expires_at > now()))` is part of Phase 10's `listings_policies.sql`. Phase 12's approval workflow only flips the listing's `status` to `approved`; no Phase 12 policy edit is needed. The same gate cascades to all four child tables via parent-derived subqueries.

**Rationale**: Shipping the policy in Phase 10 means Phase 12's approval action is a single-line SQL update, not a policy migration. This reduces Phase 12's surface area and makes the approval flip atomic.

**Alternatives considered**: Ship a deny-all SELECT in Phase 10, then replace it with the public-read policy in Phase 12 rejected because policy replacement migrations are surgical and error-prone — easier to ship the final policy now and gate on `status` rather than gate on policy version.

---

## R-17 — Forward-stated `listings.agency_id` column without FK constraint in Phase 10

**Decision**: `public.listings.agency_id UUID NULL` ships in Phase 10 with NO foreign-key constraint. Phase 19's migration adds `ALTER TABLE public.listings ADD CONSTRAINT listings_agency_id_fkey FOREIGN KEY (agency_id) REFERENCES public.agencies(id) ON DELETE SET NULL` once `public.agencies` exists. Phase 10 listings populate `agency_id=NULL` always; the "Publish under agency" affordance ships in Phase 19's form extension.

**Rationale**: The column needs to exist in Phase 10 so the schema is forward-compatible without a destructive migration in Phase 19. The FK can't be added in Phase 10 because `public.agencies` doesn't exist yet. Per IMPLEMENTATION_PLAN §Phase 19 deliverables: "`listings.agency_id` foreign key (already on the column from Phase 10; the FK becomes enforced here)" — Phase 10 ships the column, Phase 19 ships the FK.

**Alternatives considered**: Skip the column in Phase 10, add column + FK in Phase 19 rejected because adding a column to an existing populated table is more complex than adding it pre-population; ship a placeholder FK to a phantom `public.agencies` stub rejected because the stub would need to be cleaned up in Phase 19.

---

## R-18 — Validators live in `lib/core/validators/`, not in a feature folder

**Decision**: The three new validators (`AreaSizeValidator`, `PriceValidator`, `PhoneValidator`) live in `lib/core/validators/` rather than under `lib/features/listing_form/domain/validators/`. They are pure-Dart utility functions with no feature-specific dependencies.

**Rationale**: The IMPLEMENTATION_PLAN explicitly places validators under `lib/core/validators/`. Validators are cross-feature concerns — `PhoneValidator` is already conceptually shared with Phase 5's auth flow's `PhoneNumber` value object; `PriceValidator` will be consumed by Phase 14's search filter's price-range input; `AreaSizeValidator` is also a Phase 14 search-filter consumer. Placing them under `lib/core/` makes the cross-feature consumption natural.

**Alternatives considered**: Validators under `lib/features/listing_form/domain/` rejected because future Phase 14 consumers would have to import from a sibling feature folder; validators under `lib/shared/domain/` rejected because `lib/shared/` is reserved for value objects (Phase 9 `Money`) — validators are functions, not value objects.

---

## R-19 — Publisher-status three-layer enforcement via the existing AuthBloc state

**Decision**: The publisher-status gate consumes the existing `AuthBloc` state, which Phase 5 already authored to carry a `Profile` object inside the `Authenticated(Profile)` state. **No new fields are added to `PermissionChecker`** — PermissionChecker is intentionally permission-only and caches `Set<String>` of keys per its existing docstring. Instead:

1. **Router guard**: a new `requirePublisherStatusRedirect(BuildContext, GoRouterState)` function in `lib/core/routing/auth_redirect.dart`, mirroring the existing `requireSuperAdminRedirect` / `requireLocationsManageRedirect` / `requireCurrenciesManageRedirect` shape. The function reads `authBloc.state` (cast to `Authenticated`) and returns `'/home'` (or the appropriate Phase 5 status screen) when the cast fails or when `state.profile.publisherStatus != approved || state.profile.accountStatus != approved`.
2. **UX tile gate**: the HomePage tile is wrapped in a `BlocBuilder<AuthBloc, AuthState>` that returns `const SizedBox.shrink()` when the state is not `Authenticated` with the approved-pair, and renders the tile when both predicates hold.
3. **RLS write policies**: server-side, the policies read `profiles.publisher_status` and `profiles.account_status` directly via the EXISTS subquery (per FR-005). Same gate, server-authoritative.

This three-layer gate keeps `PermissionChecker` clean (still permission-only per its docstring) and reuses the existing AuthBloc state shape Phase 5 already established.

**Rationale**: The Phase 5 AuthBloc emits `Authenticated(profile: Profile)` on every sign-in/refresh; the redirect already subscribes to AuthBloc via `AuthBlocListenable` so the guard re-fires on profile changes (which is how SC-020 mid-session approval propagation works). Extending PermissionChecker to cache profile state would either (a) duplicate the AuthBloc cache, OR (b) drift when AuthBloc refreshes the profile but PermissionChecker hasn't yet. Reading directly from AuthBloc is the single source of truth.

**Alternatives considered**: Extending `PermissionChecker` with a profile-state field rejected because it conflates two distinct caches (permission keys vs profile state) and violates PermissionChecker's existing docstring "session-scoped singleton that caches the current user's effective permission set". Calling Supabase fresh on every UX render rejected for performance + flakiness. Subscribing the UX tile to a separate `ProfileBloc` rejected because Phase 5 chose AuthBloc as the post-login source-of-truth for profile state.

---

## R-20 — No client-side cache on `listings` reads

**Decision**: The publisher-dashboard's `MyListingsPage` and the read-only preview pages fetch fresh from Supabase on each mount. No `lib/features/publisher_dashboard/data/cache/` directory; no SQLite or hive layer. The listing-form's draft auto-save bypasses any cache and writes directly to Supabase via the RPC / RLS-gated UPDATE.

**Rationale**: The publisher's own listings are a small dataset (likely <50 listings even for the most active publisher) and read latency on the reference Infinix Note 8 is acceptable without caching (one paginated read of 20 rows is <1s per the performance budget). A cache would introduce stale-data risk when admins approve/reject between two mounts. The Phase 22 push + Realtime spec may introduce live update via subscriptions; Phase 10 stays simple.

**Alternatives considered**: SQLite cache rejected for the stale-data + complexity reasons; in-memory BLoC cache (kept across navigations) rejected because BLoCs are short-lived and the persistence guarantee isn't needed; Phase 22-style Realtime subscription rejected because it's a Phase 22 concern.

---

## Carry-forward summary

| Decision | Source phase | Phase 10 status |
|---|---|---|
| R-01 (date-prefixed migrations) | Phase 4 | reused unchanged |
| R-02 (inline + parallel policy files) | Phase 4 | reused unchanged |
| R-03 (zero new packages) | Phase 8 | reused (Phase 9 deviated by adding `decimal`; Phase 10 returns to the rule) |
| R-04 (anonymous SELECT carve-out) | Phase 8 / Phase 9 | **intentional deviation** — no broad carve-out; listings are not global reference data |
| R-05 (`log_audit` unchanged) | Phase 4 | reused unchanged for the 7th time |
| R-06 (RPC vs Edge Function) | Phase 7 / Phase 9 | reused (same RPC pattern) |
| R-07 (area-centroid data-source) | net-new | locks the Q2 implementation path |
| R-08 (trigger-before-seed audit ordering) | Phase 8 | defensively preserved (no Phase 10 seed) |
| R-09 (separate status-transition + audit triggers) | net-new | establishes the operational/compliance split |
| R-10 (NUMERIC(14, 2) for amount) | net-new | locks listing-price precision |
| R-11 (parent-column-authoritative sync) | net-new | resolves the `location_visibility` duplication |
| R-12 (partial unique on `is_primary`) | net-new | forward-compatibility with future multi-row spec |
| R-13 (per-step auto-save) | net-new | locks form persistence granularity |
| R-14 (draft mutated in place) | net-new | locks the resubmit lineage |
| R-15 (zero new permission keys) | Phase 6 | reused unchanged |
| R-16 (public-read-when-approved RLS in Phase 10) | net-new | reduces Phase 12's surface |
| R-17 (`listings.agency_id` no FK in Phase 10) | net-new | forward-stated to Phase 19 |
| R-18 (validators in `lib/core/validators/`) | net-new | establishes cross-feature validator pattern |
| R-19 (publisher-status helper) | net-new | unifies the three-layer gate |
| R-20 (no client-side cache) | Phase 9 R-20 | reused unchanged |

Phase 10 reuses 6 decisions unchanged, 1 reused with intentional deviation (R-04), 1 defensively preserved (R-08), and introduces 12 net-new decisions covering Phase 10's specific surface.
