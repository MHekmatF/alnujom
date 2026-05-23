# Phase 0 Research — Phase 12: Listing Approval Workflow

**Date**: 2026-05-23
**Branch**: `012-listing-approval`
**Spec**: [spec.md](spec.md)
**Plan**: [plan.md](plan.md)

> **Numbering**: This document picks up from Phase 11's R-40. Phase 12 adds R-41 through R-60 (20 new locked decisions). Decisions R-01..R-40 from prior phases are carried forward unchanged unless explicitly amended (only R-05 is narrowly relaxed — see R-43).

## R-41 — Edge Function file layout & deployment via Supabase MCP

**Decision**: Two new Edge Functions at `supabase/functions/approve_listing/index.ts` and `supabase/functions/reject_listing/index.ts`. Each is a self-contained Deno + TypeScript file importing `@supabase/supabase-js@2` via NPM compat. Deployment via Supabase MCP `deploy_edge_function`.

**Rationale**: Q1=B chose Edge Function over RPC. Phase 5 already shipped two Edge Functions (`lookup_email_by_phone`, `request_password_reset`) — Phase 12 follows the same layout (one folder per function, `index.ts` as the entry point). Supabase MCP exposes `deploy_edge_function` which is the consistent path with Phase 4–11's `apply_migration` workflow; deploying via the Supabase CLI is acceptable as a fallback but the MCP path is preferred for CI parity.

**Alternatives considered**:
- **A separate `lib/` subdirectory for shared TS helpers** (e.g., `supabase/functions/_shared/auth.ts`) — rejected; each function is small (~80–110 lines) and a shared helper would be the first cross-function abstraction. If a third notification-bearing Edge Function lands later, this decision is revisited.
- **A single combined `listing_review/index.ts` with a `?action=approve` query param** — rejected; two-function pattern is clearer, allows independent scaling / monitoring, and matches Phase 5's one-function-per-purpose convention.

## R-42 — JWT-bound permission check + service-role privileged UPDATE pattern

**Decision**: Each Edge Function uses two Supabase clients in sequence: (1) a JWT-bound client constructed with `createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization: req.headers.get('Authorization') } } })` calls `current_user_has_permission('listings.approve'|'listings.reject')` — if false, return HTTP 403. (2) A service-role-bound client constructed with `createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)` performs the privileged UPDATE under the status-guard predicate AND invokes the session-variable setters (R-44).

**Rationale**: The JWT-bound client makes the permission check honor the user's actual roles (Phase 6's `current_user_has_permission` reads `auth.uid()` via the JWT). The service-role-bound client bypasses RLS for the UPDATE — required because Phase 10's listings RLS write policy currently permits only `auth.uid()=publisher_user_id OR listings.edit_any` (not `listings.approve` / `listings.reject`); adding a new RLS clause for the approve/reject roles is a possible future amendment but Phase 12 follows the simpler service-role pattern to avoid touching Phase 10's policy file.

**Alternatives considered**:
- **JWT-bound client performs the UPDATE under amended RLS** — rejected for Phase 12; would require amending Phase 10's listings write policy via a new Phase 12 migration to permit `listings.approve` / `listings.reject` holders to update status. Per Phase 11 R-35 immutability, the amendment would ship via `CREATE OR REPLACE POLICY` — this is feasible but adds policy surface that Phase 13 may want to revisit. The service-role pattern is the lighter-weight choice.
- **Pure RPC pattern (no Edge Function)** — rejected per Q1=B.

## R-43 — Session-variable handoff for `changed_by` and `reason` to amended Phase 10 trigger + Phase 4 `log_audit()`

**Decision**: Two new SECURITY DEFINER setter functions ship in the FR-024 migration:
- `public.set_app_user_id_for_session(user_id UUID) RETURNS void` — body: `PERFORM set_config('app.current_user_id', user_id::text, true);`
- `public.set_app_rejection_reason_for_session(reason_json TEXT) RETURNS void` — body: `PERFORM set_config('app.current_rejection_reason', reason_json, true);`

The Edge Functions call these RPCs via the service-role-bound client IMMEDIATELY BEFORE the UPDATE. The amended `public.listing_status_transition_trigger_fn()` reads:
- `changed_by = coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid())`
- `reason = nullif(current_setting('app.current_rejection_reason', true), '')`

The amended `public.listings_audit_trigger_fn()` AND `public.log_audit()` read `actor_user_id` via the same COALESCE.

**Rationale**: PostgREST's `.update(...)` cannot directly invoke `set_config(...)` from the client side — a tiny RPC wrapper is required. SECURITY DEFINER on the setter functions is safe because: (a) the setter only mutates the *current transaction's* session variable (third arg `true`), (b) the only caller in v1 is the Edge Function's service-role-bound client which already has elevated privileges, (c) misuse by a future RPC caller would only affect their own transaction's audit attribution. The `nullif(current_setting('app.X', true), '')` pattern handles both unset (`current_setting` raises NOTICE → second-arg-true returns NULL, which `nullif` passes through) and empty-string cases (defense-in-depth). Phase 4's `log_audit()` byte-identical-reuse invariant R-05 is narrowly relaxed to "byte-identical except for the actor-source COALESCE" — every Phase 5–11 caller continues to produce correctly-attributed audit rows because the COALESCE falls back to `auth.uid()` when the session variable is unset.

**Alternatives considered**:
- **Pass `actor_user_id` / `reason` as explicit columns on `public.listings` to be picked up by the trigger via `NEW.last_changed_by` / `NEW.last_change_reason`** — rejected; requires schema change (two new columns) AND the columns leak admin-action state into the listings table; the session-variable pattern is cleaner and matches the trigger's existing reads-from-session-context pattern.
- **Use Postgres native `current_role` / JWT claims `request.jwt.claims` extraction** — rejected; the service-role client's JWT does not carry the admin's UID (the service-role JWT is anonymous), so the trigger cannot derive the admin's UID without explicit handoff.
- **Replace the trigger entirely with explicit INSERT statements in the Edge Function body** — rejected; would duplicate the trigger's history-emission logic in TS and create a split between Phase 10's submit_listing path (which still relies on the trigger) and Phase 12's approve/reject path. The session-variable handoff keeps both paths flowing through the same trigger function.

## R-44 — JSON-encoded TEXT storage representation for `listing_status_history.reason`

**Decision**: Per Q4=A, the rejection reason is stored as a JSON-encoded string in Phase 10's existing `listing_status_history.reason TEXT` column. Canonical shape: `{"preset":"<one of six Q3=A keys>","detail":"<string>"}` when detail is non-null, OR `{"preset":"<key>","detail":null}` when detail is null. The `reject_listing` Edge Function builds the string via `JSON.stringify({preset, detail: detail ?? null})` AND hands it to the trigger via `set_app_rejection_reason_for_session(...)` (R-43). The publisher banner + moderation-history page consume the value via `(reason::jsonb)->>'preset'` AND `(reason::jsonb)->>'detail'` — the casts run per-row at read time (acceptable for the publisher dashboard's typical N≤5 rejected listings + N≤5 history rows per listing).

**Rationale**: Q4=A explicitly chose JSON-encoded TEXT to preserve Phase 10's schema immutability per Phase 11 R-35 — no schema migration is required. Forward-compatible with a later JSONB conversion: `ALTER TABLE public.listing_status_history ALTER COLUMN reason TYPE JSONB USING reason::jsonb` converts in place without backfill. Sidecar table and delimited TEXT were rejected in Q4 — sidecar adds a join hop for no analytic benefit; delimited TEXT is fragile.

**Alternatives considered**: See Q4 in spec.md `## Clarifications`.

## R-45 — Phase 6 permission catalog audit result: `listings.reject` already seeded

**Decision**: The audit of Phase 6's seed migrations confirms that `listings.reject` is already inserted into `public.permissions` (Phase 6 migration `20260515120002_create_permissions.sql` line 31) AND mapped to the `moderator`, `admin`, AND `super_admin` roles via `public.role_permissions` (Phase 6 migration `20260515120003_create_role_permissions.sql` lines 32, 47, etc.). The conditional FR-004 micro-migration is **NOT NEEDED** — Phase 12 ships zero new permission keys AND zero new role mappings.

**Rationale**: Direct migration-file inspection during plan-time. The audit is binding for the PR diff — `supabase/migrations/20260523120005_seed_listings_reject_permission_if_missing.sql` is NOT created.

**Alternatives considered**: None — the audit either confirms or denies; it confirmed.

## R-46 — Edge Function local-dev invocation pattern

**Decision**: Local development uses `supabase functions serve approve_listing --env-file .env.local` (and the same for `reject_listing`). The `.env.local` carries `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` — all three values are already used by the Flutter dev build per `project_dart_defines.md` (the Flutter app reads `.env.json`; the Edge Function local-serve reads `.env.local`). For testing against the remote Supabase project, the Edge Functions are deployed via Supabase MCP `deploy_edge_function` then invoked via `supabase functions invoke approve_listing --body '{"listing_id":"..."}'` (or via the Flutter app's `functions.invoke()`).

**Rationale**: Matches Supabase's documented local-dev pattern. The Flutter app's `.env.json` is not directly readable by the Edge Function's Deno runtime; a separate `.env.local` for the functions side is the standard pattern.

**Alternatives considered**:
- **Deploy to a Supabase preview branch for testing** — rejected; preview branches add latency and the team currently uses a single remote project for development.
- **Mock the Edge Function with a local HTTP server** — rejected; would require maintaining two code paths and the Deno runtime's behavior diverges from a generic HTTP server in subtle ways (URL parsing, header handling).

## R-47 — ARB key naming convention for the six Q3=A preset labels

**Decision**: Each preset key gets a paired ARB key with the prefix `reject_preset_<key>`:
- `reject_preset_missing_or_low_quality_photos`
- `reject_preset_incorrect_location`
- `reject_preset_unrealistic_price`
- `reject_preset_incomplete_description`
- `reject_preset_duplicate_listing`
- `reject_preset_other`

The publisher banner (FR-015) AND the reject-reason dialog (FR-013) consume the SAME ARB keys — one localized label per preset, used in both surfaces.

**Rationale**: Matches the existing ARB naming pattern from Phase 10 (`listing_status_<key>`) and Phase 11 (`media_error_<key>`). The single-source-of-truth-per-preset principle prevents drift between the dialog's "this is why I'm rejecting" framing and the banner's "this is why your listing was rejected" framing — both surfaces use the same noun-phrase label.

**Alternatives considered**:
- **Separate ARB keys for dialog vs banner** (`admin_reject_<key>` + `publisher_rejection_<key>`) — rejected; drift risk + 12 keys instead of 6.

## R-48 — Pagination cursor shape for the pending review queue

**Decision**: Cursor-based pagination using `(submitted_at, id)` as the cursor tuple. First-page query: `SELECT ... FROM public.listings WHERE status='pending_review' ORDER BY submitted_at ASC, id ASC LIMIT 20`. Subsequent-page query: `SELECT ... WHERE status='pending_review' AND (submitted_at, id) > ($last_submitted_at, $last_id) ORDER BY submitted_at ASC, id ASC LIMIT 20`. The `submitted_at` is derived from `(SELECT MIN(changed_at) FROM listing_status_history WHERE listing_id=l.id AND new_status='pending_review')` — captured in the data-model's SELECT-shape contract.

**Rationale**: Cursor-based pagination is stable under concurrent inserts (a new submission arriving mid-scroll lands at the bottom of subsequent pages, NOT in the middle of the current page). The `(submitted_at, id)` tuple guarantees a total order even if two listings carry identical `submitted_at` timestamps.

**Alternatives considered**:
- **OFFSET / LIMIT pagination** — rejected; unstable under concurrent inserts; expensive on deep pages.
- **Sort by `id` descending alone** — rejected; the queue's product semantics require oldest-first (admin works through the backlog FIFO).

## R-49 — Phase 10 status-transition trigger function name + signature audit

**Decision**: Phase 10's status-transition trigger function is `public.listing_status_transition_trigger_fn()` (verified via `H:/alnujom-project/supabase/migrations/20260519120006_create_listing_status_history.sql` line 32). It is a `RETURNS TRIGGER` plpgsql function attached to `public.listings` for AFTER INSERT OR UPDATE OF status. Its current body hardcodes `reason=NULL` AND reads `auth.uid()` for `changed_by`. The sibling `public.listings_audit_trigger_fn()` (line 53) also reads `auth.uid()` AND emits the six action keys (`listing.created`, `listing.updated`, `listing.approved`, `listing.rejected`, `listing.paused`, `listing.deleted`) via inline `INSERT INTO audit_logs` — NOT via Phase 4's reusable `log_audit()` helper.

**Rationale**: This audit confirms which functions FR-024's migration must amend. The status-transition trigger's `reason` column needs an additional COALESCE on `current_setting('app.current_rejection_reason', true)` (not just the actor-source change). The `listings_audit_trigger_fn` needs the actor-source COALESCE. Phase 4's `log_audit()` is also amended per Q7=A (forward-prep for future callers; Phase 11's `listing_media` audit triggers consume it).

**Implications for the migration**:
- 3 `CREATE OR REPLACE FUNCTION` statements: `listing_status_transition_trigger_fn`, `listings_audit_trigger_fn`, `log_audit`.
- 2 new `CREATE OR REPLACE FUNCTION` for the session-variable setters (R-43): `set_app_user_id_for_session`, `set_app_rejection_reason_for_session`.
- Total: 5 function definitions in the one migration.

## R-50 — `cached_network_image` consumption pattern for the preview gallery

**Decision**: The `ListingGallery` widget (FR-011 + Q8=A) consumes `cached_network_image` (already in Phase 1's pubspec) against Phase 11's public-bucket URLs from `supabase.storage.from('listing-images').getPublicUrl(<storage_path>)`. The URL is stable per the Q8=A Phase 11 resolution — no signed-URL minting, no expiry. The gallery caches the URL → bytes mapping in the on-device cache. Cache invalidation: the URL changes only when the underlying `listing_media.storage_path` changes (Phase 11's reorder + replace flows produce new storage paths via the `<listing_id>/<ordering>_<rand>.jpg` naming convention), so cache hits are deterministic.

**Rationale**: Phase 11 R-29 forward-stated this consumption pattern; Phase 12 is the first widget to actually consume it. The Pixel 8 Pro emulator and the Infinix Note 8 both benefit from the cache during the admin preview + publisher banner walks.

**Alternatives considered**:
- **Network.image** — rejected; no on-device caching; redundant downloads on every render.
- **A custom image cache layer** — rejected; `cached_network_image` is battle-tested and already in `pubspec.lock`.

## R-51 — Sticky bottom-bar approve/reject CTAs sized for Infinix Note 8 / Pixel 8 Pro portrait

**Decision**: The preview page's approve / reject CTAs live in a `SafeArea`-wrapped `BottomAppBar` at the bottom of the scaffold. Each CTA is a `FilledButton` sized at 48dp tall × half-screen-wide (~177dp on Pixel 8 Pro 412dp portrait; ~172dp on Infinix Note 8 432dp portrait). The two buttons are separated by Phase 2's `Spacing.md` (16dp). The bar's background uses Phase 2's `surfaceContainerHigh` for elevation contrast with the scrolling preview content.

**Rationale**: Sticky bottom bar is the standard Material 3 pattern for primary actions on a long-scroll detail page. The 48dp height matches Material's minimum touch target. Two side-by-side buttons fit comfortably on the 6.2"–6.78" portrait surface.

**Alternatives considered**:
- **Floating Action Button + secondary action menu** — rejected; the FAB pattern is for a single primary action; approve and reject are co-equal admin actions.
- **App bar actions** — rejected; the app bar is small and users scroll the preview away from it.

## R-52 — Edge Function error responses → Dart `Failure` mapping

**Decision**: The Edge Function returns typed JSON error payloads: `{ code: 'permission_denied' | 'invalid_status_transition' | 'already_acted_on' | 'invalid_reason_preset' | 'reason_detail_too_long', ...context }`. The Dart datasource maps each `code` value to a corresponding `Failure` subtype in `lib/core/errors/failure.dart`:

| HTTP code | JSON `code` | Dart Failure |
|---|---|---|
| 403 | `permission_denied` | `PermissionDeniedFailure` |
| 409 | `invalid_status_transition` | `InvalidStatusTransitionFailure(currentStatus)` |
| 409 | `already_acted_on` | `AlreadyActedOnFailure(currentStatus)` |
| 400 | `invalid_reason_preset` | `InvalidReasonPresetFailure(allowed)` |
| 400 | `reason_detail_too_long` | `ReasonDetailTooLongFailure(max)` |
| Other 4xx/5xx | (parse failed or unknown code) | `UnexpectedFailure(rawBody)` |

The BLoCs emit `ListingPreviewState.error(failure)` and the page renders a localized toast (FR-018) keyed by the `Failure` runtime type.

**Rationale**: Typed `Failure` hierarchy matches the project's existing pattern (Phase 5's auth failures, Phase 10's submit_listing failures). The page's switch-on-runtime-type renders the correct localized message without leaking Edge Function internals.

**Alternatives considered**:
- **A single `EdgeFunctionFailure` carrying the raw `code` string** — rejected; the page's localization switch would still need to discriminate on the code; the typed Failure hierarchy is clearer.

## R-53 — BLoC ownership boundary: Phase 12 preview vs Phase 13 listing-details

**Decision**: Phase 12 ships its OWN `ListingPreviewBloc` for the admin preview page; Phase 13 will ship its OWN `ListingDetailsBloc` for the public listing-details page. The two BLoCs do NOT share state or events — they emit different state shapes (Phase 12's includes `mutatorInFlight` + `approveResult` / `rejectResult`; Phase 13's includes favorite-toggle + share-event + contact-CTA-tapped). The five Q8=A shared widgets accept domain entities only — the BLoC layer that fetches the underlying rows is per-consumer.

**Rationale**: Pure-render widgets + per-consumer BLoCs prevent state coupling between admin and public surfaces. If the admin preview later gains a "request more info from publisher" action, the change touches `ListingPreviewBloc` only; Phase 13's BLoC is untouched.

**Alternatives considered**:
- **A shared `ListingDisplayCubit` consumed by both** — rejected; the events are sufficiently different that a shared abstraction would carry both surfaces' bloat.

## R-54 — Concurrent admin race testing approach

**Decision**: The quickstart's concurrent-admin verification uses two simultaneous browser sessions (or one browser + one emulator) signed in as two different admin users. Both admins navigate to the same pending listing's preview page. Both tap Approve nearly simultaneously. The verification confirms: (a) one admin sees the queue update / success toast; (b) the other admin sees a localized "already approved by another admin moments ago" error toast keyed by `AlreadyActedOnFailure(currentStatus='approved')`. The same race is exercised for Reject vs Reject AND Approve vs Reject.

**Rationale**: Manual concurrent-session testing is sufficient for v1 — no automated load-test ships per the durable no-new-tests rule. The status-guard predicate in the Edge Function's UPDATE WHERE clause is the structural enforcement; the test confirms the structured error response surfaces correctly.

**Alternatives considered**:
- **Automated race test via integration test harness** — rejected per `feedback_no_new_tests.md`.

## R-55 — Two-device manual verification matrix

**Decision**: Phase 12's quickstart covers the spec's user stories across two devices:

| User Story | Admin Device | Publisher Device |
|---|---|---|
| US1 — Admin reviews + approves | **Pixel 8 Pro emulator (Android 14)** | (Anonymous device used for public-read verification) |
| US2 — Admin rejects with reason | Pixel 8 Pro emulator | **Infinix Note 8 (Android 10/11)** — sees rejection banner + Resubmit |
| US3 — Public read RLS | (anonymous Supabase client via desktop SQL) | (none) |
| US4 — Audit + status-history | Pixel 8 Pro emulator | (verified via SQL post-action) |
| US5 — Queue pagination | Pixel 8 Pro emulator | (none) |
| US6 — Rejection banner + Resubmit + moderation history | (none) | **Infinix Note 8** |

**Rationale**: Mirrors Phase 11's R-34 two-device matrix. The publisher walk lives on Infinix Note 8 (per `user_test_device.md`); the admin walk lives on the Pixel 8 Pro emulator because admins typically use a desktop-sized screen in the field (the 6.2" portrait emulator approximates a small tablet). Anonymous public-read verification uses Supabase MCP `execute_sql` from the desktop session.

**Alternatives considered**:
- **All testing on Infinix Note 8** — acceptable but slower; the Pixel 8 Pro emulator provides faster Edge Function iteration cycles.

## R-56 — Phase 10 `listing_status_history.reason` column TEXT verification

**Decision**: Phase 10's column is `reason TEXT` (verified via `H:/alnujom-project/supabase/migrations/20260519120006_create_listing_status_history.sql`). Phase 12 reuses the column unchanged AND stores the Q4=A JSON-encoded payload as a TEXT value. No schema migration. Readers (publisher banner + moderation history page) cast at read time: `(reason::jsonb)->>'preset'`. For NULL `reason` rows (every non-rejection status transition), the cast is skipped via `CASE WHEN reason IS NOT NULL THEN ... END`.

**Rationale**: Direct migration-file confirmation. Phase 11 R-35 immutability preserved.

## R-57 — `set_app_user_id_for_session` SECURITY DEFINER safety

**Decision**: The setter function `public.set_app_user_id_for_session(user_id UUID)` is `SECURITY DEFINER` so it can execute `set_config(..., true)` regardless of the caller's role. It accepts `user_id UUID` as an arbitrary input — the caller asserts what the session's effective user is. The session variable is scoped to the current transaction (`set_config(..., true)` third arg `true`) so leak-across-requests is impossible.

**Security analysis**: A malicious caller invoking this RPC could spoof the audit attribution for their own transaction. Mitigations: (a) the only Phase 12 caller is the Edge Function's service-role-bound client which has already passed the permission check on the user's JWT — the asserted user_id IS the JWT's `sub` claim; (b) future RPC callers from unauthenticated contexts would have no audit identity to spoof (the COALESCE falls back to `auth.uid()` which is NULL for anonymous clients); (c) the function does NOT mutate any table — only the transaction-scoped session variable. If a future spec needs to remove SECURITY DEFINER, it can do so by granting EXECUTE only to the service_role.

**Rationale**: SECURITY DEFINER is the minimum-friction path; the security analysis confirms no abuse vector in Phase 12.

**Alternatives considered**:
- **SECURITY INVOKER + explicit `set_config` privilege grant** — rejected; `set_config` is a built-in callable by any role; the SECURITY DEFINER is purely for ergonomics.
- **Use a Postgres CTE / DO block inside the Edge Function's UPDATE** — rejected; PostgREST does not support arbitrary SQL injection.

## R-58 — Audit-log retention for the moderation history page

**Decision**: The moderation history page (FR-017) reads exclusively from `public.listing_status_history` — NOT from `public.audit_logs`. Status-history rows are owner-readable per Phase 10's RLS (which the audit confirms — the existing policy is `SELECT EXISTS (...listing.publisher_user_id=auth.uid()) OR current_user_has_permission('listings.view_all')`). Audit-log rows are admin-only (`audit_logs.view` permission) — NOT readable by the publisher. The two surfaces serve different audiences.

**Rationale**: Publishers should see their own listing's moderation history (status transitions, rejection reasons) without admin permission. The `listing_status_history` table is the authoritative source for this surface. The `audit_logs` table provides additional structured before/after JSONB context valuable for admin internal review — but the publisher does not need that.

**Alternatives considered**:
- **Read from audit_logs** — rejected; would require a new RLS carve-out permitting publishers to read their own listings' audit rows. Adds complexity for no publisher-facing benefit.

## R-59 — Edge Function CORS configuration

**Decision**: No CORS configuration is added to the Edge Functions in Phase 12. The only caller is the Flutter Android app via `supabase_flutter`'s `functions.invoke()`, which makes a server-side HTTPS POST without browser-style CORS preflight. If a future spec (e.g., a web admin tool) requires browser CORS, the Edge Functions can be amended to include `Access-Control-Allow-Origin` headers; Phase 12 ships without.

**Rationale**: Constitution XI Android-First MVP — no web target in scope. CORS handling adds boilerplate without a v1 caller.

**Alternatives considered**:
- **Preemptive CORS headers for future web admin** — rejected per Constitution XI / no-speculative-features rule.

## R-60 — Migration filename + apply order

**Decision**: One migration: `20260523120004_amend_phase10_phase4_triggers_for_session_var.sql`. The synthetic-monotonic 14-digit timestamp `20260523120004` orders AFTER Phase 11's final migration `20260523120003_reorder_listing_media_rpc_revoke_anon.sql` (verified via `H:/alnujom-project/supabase/migrations/` listing). The conditional FR-004 micro-migration is NOT created per R-45's audit. Apply order is single-step: `apply_migration("20260523120004_amend_phase10_phase4_triggers_for_session_var", <body>)`. The Edge Functions deploy separately via `deploy_edge_function` — order between migration and Edge Function deploys does NOT matter (the Edge Functions are idle until invoked; the migration's amended trigger does not change behavior until invoked from an Edge Function with the session variables set).

**Rationale**: Single-migration design minimizes the deploy surface. The synthetic-monotonic numbering picks up where Phase 11 left off.

**Alternatives considered**:
- **Split the FR-024 amendment across three migrations (one per function)** — rejected; a single migration ensures atomic application — either all three functions are amended or none are.

---

## Carry-forward decisions from Phase 11 (R-01..R-40)

All Phase 1–11 decisions remain in force. Specific Phase 12 acknowledgements:

- **R-05 (log_audit reusability invariant)**: Narrowly relaxed in Phase 12 per Q7=A — see R-43 above. From Phase 12 forward, R-05 means "byte-identical reuse EXCEPT for the actor-source COALESCE amendment on `actor_user_id`". Phase 5–11 callers are NOT broken because the COALESCE falls back to `auth.uid()` when the session variable is unset.
- **R-15 (no new permission keys without spec justification)**: Preserved. Phase 12 introduces zero new permission keys per R-45's audit.
- **R-34 (two-device verification matrix)**: Extended in Phase 12 per R-55 — same Infinix Note 8 + Pixel 8 Pro emulator pair, different role assignments per user story.
- **R-35 (immutability of prior-phase migration files)**: Preserved. Phase 10 + Phase 4 original migration files remain unedited; Phase 12 amendments ship via `CREATE OR REPLACE FUNCTION` in a new migration.
- **R-36 (zero new Edge Functions in Phase 11)**: Bounded to Phase 11; explicitly RELAXED in Phase 12 per Q1=B. Phase 12 introduces two new listings-domain Edge Functions. The relaxation acknowledges that Phase 5 already shipped Edge Functions — Phase 12 is the first listings-domain Edge Functions, not the project's first ever.
- **R-29 (cached_network_image consumption)**: Phase 12 is the first widget to consume — see R-50.

## Plan-time decisions deferred to `/speckit-implement` time

These items are NOT settled at plan time AND will be decided during implementation. Each is captured here so the implementer can find the open question without spelunking the spec.

- **D-12-01** — Whether to add an "expand to fullscreen" affordance on the `ListingGallery` widget's individual thumbnails in Phase 12 (vs ship in Phase 13 only). Default: Phase 12 ships a tappable thumbnail that opens a basic full-screen viewer with swipe-to-dismiss; Phase 13 may enhance with pinch-to-zoom + share + favorite.
- **D-12-02** — Whether to render listing prices in the admin preview using the publisher's preferred currency (Phase 9) OR the admin's preferred currency. Default: admin's preferred currency (so the admin sees consistent values across the queue). If publisher's currency is preferred, switch via `displayCurrency` parameter on `ListingPriceBlock`.
- **D-12-03** — Whether the moderation history page surfaces audit-log details (`before_state` / `after_state` JSONB) IF the publisher holds `audit_logs.view`. Default: no — even publishers who somehow gained admin permissions see the same publisher-friendly history view; admin-friendly history is a future-spec super-admin surface.
