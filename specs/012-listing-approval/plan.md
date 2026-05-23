# Implementation Plan: Listing Approval Workflow

**Branch**: `012-listing-approval` | **Date**: 2026-05-23 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/012-listing-approval/spec.md`

## Summary

Phase 12 introduces the project's first **listings-domain Edge Functions** (continuing the Edge Function precedent Phase 5 set with `lookup_email_by_phone` + `request_password_reset` — Phase 7's R-06 and Phase 11's R-36 chose RPCs for those specific surfaces; Phase 12's notification-fanout-anticipating mutators choose Edge Functions per Q1=B and IMPLEMENTATION_PLAN §6.7). **Two new Edge Functions** under `supabase/functions/` — `approve_listing/index.ts` flips `public.listings.status` from `pending_review` to `approved`, sets `published_at=now()`, leaves `expires_at=NULL` per Q2=A; `reject_listing/index.ts` flips status to `rejected` and persists a Q4=A JSON-encoded reason `{"preset":"<one of six Q3=A keys>","detail":"<string|null>"}` into Phase 10's `listing_status_history.reason TEXT` column. Both Edge Functions follow the **JWT-bound permission check → service-role privileged UPDATE** pattern: a JWT-bound Supabase client calls `current_user_has_permission('listings.approve'|'listings.reject')`, a service-role-bound client performs the UPDATE under the status-guard predicate `AND status='pending_review'` (last-writer-wins concurrency per the Q-resolution's folded-default), and Phase 10's amended status-transition trigger + Phase 10's amended `listings_audit_trigger_fn` + Phase 4's amended `log_audit()` source the admin's UID via `coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid())` per Q7=A + FR-024.

**One new SQL migration** ships the amended trigger function bodies via `CREATE OR REPLACE FUNCTION` — three functions amended: `public.listing_status_transition_trigger_fn()` (Phase 10), `public.listings_audit_trigger_fn()` (Phase 10), `public.log_audit()` (Phase 4) — each gaining the same single-line COALESCE on the actor source AND (for the status-transition trigger only) a second COALESCE on the `reason` source via `current_setting('app.current_rejection_reason', true)`. Phase 4's, Phase 6's, Phase 10's original migration files remain **unedited** per Phase 11 R-35 immutability — the amendments live exclusively in the new Phase 12 migration. The R-05 invariant on `log_audit()` byte-identical reuse is narrowly relaxed from "byte-identical" to "byte-identical except for the actor-source COALESCE" per Q7=A; every Phase 5–11 caller continues to produce correctly-attributed audit rows because the COALESCE falls back to `auth.uid()` when the session variable is unset. **One conditional micro-migration** (FR-004 `seed_listings_reject_permission_if_missing.sql`) ships only if a plan-time audit of Phase 6's seed reveals the `listings.reject` key is absent (Phase 6's §9.1 catalog lists both `listings.approve` AND `listings.reject`; the audit confirms whether the seed migration actually inserted both). **Zero schema changes** — no new tables, no new columns (the Q4=A JSON-encoded reason reuses Phase 10's existing `listing_status_history.reason TEXT` column unchanged), no new RLS policies on `public.listings` (Phase 10's public-read policy is verified end-to-end against real `approved` rows; Phase 11's `listing_media` + `storage.objects` policies are verified to honor parent-status flips per Phase 11 SC-025 — no edits). **Zero new permission keys** if the Phase 6 catalog audit passes (FR-009-equivalent for Phase 12).

The Flutter side adds **one new feature folder** under `lib/features/admin/listing_review/` (sibling of Phase 5's `lib/features/admin/account_approvals/`) with all three Clean Architecture layers (`data/`, `domain/`, `presentation/`); **one extended existing feature folder** at `lib/features/publisher_dashboard/` adding the rejection-reason banner + Resubmit button on rejected cards (Phase 10 MyListingsPage extended in place) + a new moderation-history read-only page; **one new shared-widget subdirectory** at `lib/shared/presentation/widgets/listing_display/` housing **five new pure-render widgets** per Q8=A (gallery, price block, location block, amenities block, description block) consumed by Phase 12's admin preview AND forward-stated for Phase 13's public listing-details page; **three new routes** in `lib/core/routing/app_router.dart` (`/admin/listing-review/pending`, `/admin/listing-review/preview/:id`, `/publisher/listings/:id/moderation-history`); **one extended existing page** at `lib/features/admin/presentation/pages/admin_home_page.dart` (Phase 6's admin home) gaining a "Pending review" tile gated by `PermissionChecker.any(['listings.approve', 'listings.reject'])`; an **ARB-key delta** of ~32 new keys covering queue chrome + preview CTAs + the approve confirmation dialog + the reject-reason dialog including the six Q3=A preset labels (`reject_preset_missing_or_low_quality_photos` / `_incorrect_location` / `_unrealistic_price` / `_incomplete_description` / `_duplicate_listing` / `_other`) + the publisher rejection banner + the moderation history page + structured-error toasts + status-transition labels for all nine `public.listings.status` enum values (used by the moderation history page); **zero new pubspec packages**; **zero AndroidManifest changes**; **no new automated tests** per the durable session feedback rule (`feedback_no_new_tests.md`); verification is manual SQL via Supabase MCP `execute_sql` + `get_advisors` + a two-device manual UI walk (Infinix Note 8 as the publisher-side device + Pixel 8 Pro emulator as the admin-side device).

**Technical approach**: The eight Q-resolutions from spec.md close the design space — Q1=B (two Edge Functions, JWT-bound permission check + service-role privileged UPDATE), Q2=A (`expires_at` left NULL on approval; no expiry / renewal UX in v1), Q3=A (six rejection-reason preset keys with one-ARB-key-per-preset), Q4=A (JSON-encoded TEXT storage in the existing `listing_status_history.reason` column), Q5=A (UX-required free-text when `preset='other'`; server contract stays permissive), Q6=A (≤ 2 seconds p95 per Edge Function invocation; cold-start tail acknowledged outside p95), Q7=A (session-variable handoff to amended trigger + amended log_audit; R-05 narrowly relaxed; FR-024 amendment migration), Q8=A (five shared display widgets under `lib/shared/presentation/widgets/listing_display/`; Phase 13 imports verbatim). Phase 12 backend collapses into **one mandatory migration** (FR-024 trigger + log_audit amendment) + **one conditional micro-migration** (FR-004 perm-key seed, only if audit reveals the gap) + **two Edge Function files** + **three updated existing doc files** under `supabase/docs/`. The Flutter side adds one new feature folder, one extended existing folder, one new shared-widget subdirectory, three new routes, ~32 ARB keys. **No CORS configuration** is added to the Edge Functions — the only caller in v1 is the Flutter Android app via `supabase_flutter`'s `functions.invoke()`, which does not require browser-style CORS preflight. **No keep-warm cron pinger** is added in Phase 12 per Q6=A's "no keep-warm engineering" guidance.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) for the app additions; PostgreSQL (Supabase remote, Postgres 15+) for the SQL migration; **TypeScript on Deno** for the two new Edge Functions (matching Phase 5's `supabase/functions/lookup_email_by_phone/index.ts` + `request_password_reset/index.ts` precedent — Phase 12 follows the same code style, same `@supabase/supabase-js` import path, same error-shape conventions Phase 5 established). **Zero new pubspec packages** in Phase 12 (a hard reversal from Phase 11's R-22 three-package addition — Phase 12 needs no new client-side capabilities).

**Primary Dependencies**: All existing packages consumed unchanged — `supabase_flutter` (Phase 12 uses `client.functions.invoke('approve_listing', body: {...})` AND `client.functions.invoke('reject_listing', body: {...})` for the first time in the project; Phase 5's Edge Functions are called via the auth-data-source's `Supabase.instance.client.functions.invoke(...)` — same SDK surface), `flutter_bloc` (two new BLoCs in Phase 12: `PendingQueueBloc`, `ListingPreviewBloc`; one new lightweight cubit for the moderation history page; the publisher-side rejection banner reads from Phase 10's existing `MyListingsBloc` via `BlocSelector` — no new BLoC there), `equatable`, `get_it` + `injectable` (DI registrations for the new datasources / repositories / use cases / BLoCs — generated via `build_runner` as usual), `go_router` (three new route definitions in `lib/core/routing/app_router.dart`; each gated by an `auth_redirect.dart` guard composed with the new `PermissionChecker.any(['listings.approve','listings.reject'])` gate per FR-008), `intl` (the time-since-submit formatter for the queue card surface + the changed-at timestamps on the moderation history page), `cached_network_image` (consumed by the Q8=A `ListingGallery` widget for thumbnail + full-screen image caching — Phase 11 R-29 forward-stated the consumption pattern; Phase 12 is the first widget to actually consume it for the public-bucket URLs via `getPublicUrl()`).

**Tooling**: Supabase MCP server (`apply_migration`, `execute_sql`, `list_tables`, `list_migrations`, `get_advisors`, `deploy_edge_function`) — Phase 12 is the FIRST phase to consume the MCP `deploy_edge_function` tool for the two new Edge Functions (Phase 5's existing Edge Functions were deployed via the Supabase CLI in pre-MCP-era; Phase 12 uses the MCP path consistently with Phases 4–11's `apply_migration` workflow). Local-dev invocation of the Edge Functions is via `supabase functions serve approve_listing` / `reject_listing` against a local `.env.local` carrying the `SUPABASE_URL` / `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY` triple — the service-role key was already provisioned during Phase 4's Vault scaffolding per ADR-0001; Phase 12 does NOT add new repository secrets.

**Storage**: Remote Supabase Postgres project. Phase 12 backend artifacts:

- **One mandatory new migration**: `20260523120004_amend_phase10_phase4_triggers_for_session_var.sql` per FR-024 — three `CREATE OR REPLACE FUNCTION` statements:
  - `public.listing_status_transition_trigger_fn()` — Phase 10's original body verbatim EXCEPT (a) the `changed_by` column expression changes from `auth.uid()` to `coalesce(nullif(current_setting('app.current_user_id', true), '')::uuid, auth.uid())`, AND (b) the `reason` column expression changes from the hardcoded `NULL` to `nullif(current_setting('app.current_rejection_reason', true), '')`. Both COALESCEs fall back to the original Phase 10 behavior when the session variables are unset, preserving Phase 10's `submit_listing` semantics.
  - `public.listings_audit_trigger_fn()` — Phase 10's original body verbatim EXCEPT the `actor_user_id` column expression changes from `auth.uid()` to the same COALESCE. The function body's six action keys (`listing.created`, `listing.updated`, `listing.approved`, `listing.rejected`, `listing.paused`, `listing.deleted`) and their `before_state` / `after_state` JSONB shapes are unchanged.
  - `public.log_audit()` — Phase 4's original body verbatim EXCEPT the `actor_user_id` insertion expression changes from `auth.uid()` to the same COALESCE. Reused by Phase 11's `listing_media` audit triggers AND by future-phase audit emitters; the amendment is forward-compatible.
- **One conditional micro-migration**: `20260523120005_seed_listings_reject_permission_if_missing.sql` per FR-004 — `INSERT INTO public.permissions (key, description_ar, description_en, category) VALUES ('listings.reject', '...', '...', 'listings') ON CONFLICT (key) DO NOTHING` AND `INSERT INTO public.role_permissions (role_id, permission_id) SELECT r.id, p.id FROM public.roles r CROSS JOIN public.permissions p WHERE r.key IN ('moderator', 'admin', 'super_admin') AND p.key = 'listings.reject' ON CONFLICT (role_id, permission_id) DO NOTHING`. Ships **only if** the plan-time audit (`research.md` R-49) confirms the gap; the spec's FR-004 explicitly conditions on this audit. If Phase 6's seed already inserted `listings.reject`, this migration ships as a no-op (the ON CONFLICT clauses are defensive but the file is omitted from the PR diff).
- **Zero new tables, columns, or RLS policies**. Phase 10's public-read policy on `public.listings` is verified end-to-end against real `approved` rows (FR-006); Phase 11's `listing_media` + `storage.objects` policies are verified to honor parent-status flips (FR-007 + Phase 11 SC-025). No policy edits.
- **Zero new SQL functions beyond the FR-024 amendments**. No new RPC ships (Q1=B chose Edge Functions; the `current_user_has_permission` RPC from Phase 6 is consumed unchanged by the Edge Functions for the permission re-check).

**Edge Functions**:

- `supabase/functions/approve_listing/index.ts` — TypeScript + Deno. Imports `@supabase/supabase-js@2` via the Deno NPM compat layer (matching Phase 5's existing functions). Function shape: (a) read POST body `{ listing_id: UUID }`; (b) extract `Authorization` header → JWT; (c) create JWT-bound client `createClient(SUPABASE_URL, SUPABASE_ANON_KEY, { global: { headers: { Authorization } } })`; (d) `await jwtClient.rpc('current_user_has_permission', { perm_key: 'listings.approve' })` → if false, return `new Response(JSON.stringify({code:'permission_denied'}), {status:403})`; (e) create service-role client `createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY)`; (f) `await serviceClient.rpc('exec_sql', ...)` is NOT used — instead, the function uses the standard PostgREST UPDATE path via `serviceClient.from('listings').update(...).eq('id', listing_id).eq('status', 'pending_review').select('id, status, published_at, expires_at').maybeSingle()` — the status-guard predicate is the `.eq('status', 'pending_review')` filter; if `data === null`, fetch the listing's current status via a follow-up `serviceClient.from('listings').select('status').eq('id', listing_id).single()` AND return `{code:'invalid_status_transition'|'already_acted_on', current_status}`; (g) IMMEDIATELY BEFORE the UPDATE, set the session variable via a separate RPC `await serviceClient.rpc('set_app_user_id_for_session', { user_id: jwt.sub })` (a new tiny SECURITY DEFINER plpgsql function ships in the same Phase 12 migration as a session-variable setter — `CREATE OR REPLACE FUNCTION public.set_app_user_id_for_session(user_id UUID) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$ BEGIN PERFORM set_config('app.current_user_id', user_id::text, true); END; $$;` — this is required because PostgREST's `update()` cannot directly call `set_config`); (h) on UPDATE success, the amended status-transition trigger + amended `listings_audit_trigger_fn` fire automatically; return HTTP 200 with `{status, published_at, expires_at}`. Total Edge Function body: ~80 lines of TypeScript.
- `supabase/functions/reject_listing/index.ts` — TypeScript + Deno. Same shape as approve_listing EXCEPT: (a) POST body `{ listing_id: UUID, reason_preset: <one of six Q3=A keys>, reason_detail?: string }`; (b) validate `reason_preset` is in the hard-coded array `['missing_or_low_quality_photos', 'incorrect_location', 'unrealistic_price', 'incomplete_description', 'duplicate_listing', 'other']` → if not, return HTTP 400 `{code:'invalid_reason_preset', allowed:[...]}`; (c) validate `reason_detail?.length ≤ 500` → if not, return HTTP 400 `{code:'reason_detail_too_long', max:500}`; (d) build the JSON-encoded reason via `const reasonJson = JSON.stringify({preset: reason_preset, detail: reason_detail ?? null})`; (e) call a second session-variable-setter RPC `await serviceClient.rpc('set_app_rejection_reason_for_session', { reason_json: reasonJson })` (sibling of the Phase 12 setter introduced in approve_listing); (f) UPDATE under the status-guard; (g) on success, the amended trigger fires AND writes the JSON-encoded reason to `listing_status_history.reason`; return HTTP 200 with `{status:'rejected', reason_preset, reason_detail}`. Total Edge Function body: ~110 lines of TypeScript.
- Both functions are deployed via Supabase MCP `deploy_edge_function` during `/speckit-implement`; the function source files are checked into `supabase/functions/<name>/index.ts` per Constitution II.

**Testing**: **Manual SQL inspection against the remote Supabase project via Supabase MCP `execute_sql` + `get_advisors` after the migration + manual UI verification on two devices (Infinix Note 8 as the publisher device for the rejection-banner + Resubmit + moderation-history walks; Pixel 8 Pro emulator as the admin device for the queue + preview + approve + reject walks).** Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's Assumptions, this phase introduces NO new automated tests of any kind — including for the Edge Function bodies, the amended trigger functions, or the new Dart use cases / BLoCs. The Edge Function happy paths, error responses, status-guard race, and audit-log emission are codified in `quickstart.md` as manual-verification cases exercised via `supabase functions invoke` from the desktop AND through the admin UI on the Pixel 8 Pro emulator. Build-time validation is preserved: Supabase's static SQL parser at `apply_migration` time catches syntax errors in the FR-024 amendment migration; Deno's `--check` lint catches Edge Function TypeScript type errors at deploy time; Flutter's analyzer + the existing Phase 3 localization lint guard validate the new Dart files. Existing Phase 1–11 tests remain unchanged.

**Target Platform**: Android 7.0+ (API 24+) for the Flutter side (Constitution XI); Supabase remote Postgres + Supabase Edge Functions Deno runtime for the backend. iOS / Web / desktop NOT a target. Edge Functions are platform-agnostic by design — the Deno runtime is hosted by Supabase; the only client surface is the Flutter Android app.

**Project Type**: Mobile app + backend. Phase 12 introduces ONE new feature folder under `lib/features/admin/listing_review/` (sibling of Phase 5's `lib/features/admin/account_approvals/`); ONE new shared-widget subdirectory under `lib/shared/presentation/widgets/listing_display/` housing five pure-render widgets per Q8=A; ONE extended existing feature folder at `lib/features/publisher_dashboard/` (one new page, one new BLoC, two new widgets, one new use case + repository extension); ONE extended existing page at `lib/features/admin/presentation/pages/admin_home_page.dart`; ONE extended existing routing file at `lib/core/routing/app_router.dart` (three new routes). Phase 12 does NOT introduce changes to `pubspec.yaml`, `AndroidManifest.xml`, `analysis_options.yaml`, or `.github/workflows/`.

**Performance Goals**:

- `approve_listing` Edge Function p95: ≤ 2 seconds end-to-end at the admin device per Q6=A + SC-029 (covers cold-start tail outside p95). Warm function path ≤ 800 ms median.
- `reject_listing` Edge Function p95: same target (slightly higher median ~1 second due to the extra session-variable RPC call AND the additional input validation).
- Admin queue page initial load: under 1 second on the Pixel 8 Pro emulator for the first 20 listings — a single PostgREST SELECT against `public.listings` joined to `listing_status_history` for `submitted_at` + `public.listing_media` for the main-image thumbnail.
- Listing preview page open: under 1.5 seconds — gallery thumbnails via `cached_network_image` against Phase 11's public-bucket URLs; on cold cache the first thumbnail loads in ~600 ms over Supabase storage CDN.
- Reject-reason dialog open: under 200 ms (no network round-trip; pure UX).
- Confirmation dialog → mutator call → queue refresh: under 3 seconds total (the 2-second Edge Function p95 + ~500 ms queue re-fetch).
- Publisher dashboard rejection banner render: under 100 ms additional cost over Phase 10's existing rejected-card render (the JSON cast on `listing_status_history.reason` is per-row, N typically ≤ 5 rejected listings per publisher).
- Moderation history page load: under 800 ms — a single PostgREST SELECT against `listing_status_history` with `ORDER BY changed_at ASC`; typical N ≤ 5 history rows per listing.
- FR-024 migration apply: under 5 seconds (three `CREATE OR REPLACE FUNCTION` statements; no schema changes; no row-level data backfill).

**Constraints**:

- Constitution II (Source-Controlled Backend) binding: the one FR-024 migration is a checked-in `.sql` file under `supabase/migrations/`; the conditional FR-004 micro-migration is a checked-in `.sql` file as well (omitted from the PR if not needed). Both Edge Functions are checked-in TypeScript files under `supabase/functions/<name>/index.ts`. No Studio-only edits to the trigger functions. The three updated doc files under `supabase/docs/` (per Project Structure below) are checked in.
- Constitution III (Security-First Supabase, NON-NEGOTIABLE): Phase 10's public-read RLS on `public.listings` is verified — no policy edit. Phase 11's `listing_media` + `storage.objects` policies are verified — no edits. The Edge Functions re-check the caller's permission server-side via the JWT-bound client (not the service-role client) before performing the privileged UPDATE. The service-role key is consumed ONLY inside the Edge Function's Deno runtime — never shipped to the Flutter client. The session variables (`app.current_user_id` + `app.current_rejection_reason`) are scoped to the current transaction (`set_config(..., true)` third arg) — no leak across requests. Phase 12's session-variable setter RPCs are SECURITY DEFINER but accept any authenticated caller (the audit trail is still correct because the service-role-bound caller is the Edge Function whose permission check has already passed).
- Constitution V (Arabic-First Localization): every new user-visible chrome string flows through `AppLocalizations`. ~32 new ARB keys cover queue chrome + preview CTAs + the approve confirmation dialog + the reject-reason dialog including the six Q3=A preset labels + the publisher rejection banner + the moderation history page + structured error toasts + status-transition labels for all nine `public.listings.status` enum values (`draft`, `pending_review`, `approved`, `rejected`, `paused`, `sold`, `rented`, `expired`, `deleted` — the moderation history page renders previous-status → new-status arcs and needs localized labels for each). The Phase 3 localization lint guard catches any hardcoded user-facing string at PR review.
- Constitution VI (Theme System & Design Tokens): every new widget under `lib/features/admin/listing_review/presentation/` + `lib/features/publisher_dashboard/presentation/pages/listing_moderation_history_page.dart` + `lib/shared/presentation/widgets/listing_display/` consumes Phase 2 design tokens. The queue-card uses `surfaceContainer`; the preview's approve CTA uses `success`; the preview's reject CTA uses `danger`; the rejection banner uses `dangerContainer` background + `onDangerContainer` foreground. No inline hex / font-size / padding.
- Constitution VII (Dynamic Roles & Permissions) preserved: zero new permission keys if FR-004's Phase 6 audit passes (most likely — Phase 6's §9.1 catalog explicitly lists both `listings.approve` AND `listings.reject`). The existing `PermissionChecker.any(['listings.approve','listings.reject'])` gate covers route + UX surfaces. The Edge Functions re-check the permission server-side. Audit emission is universal: every approve / reject action writes exactly one `listing_status_history` row AND exactly one `audit_logs` row via the amended `listings_audit_trigger_fn` per FR-021.
- Constitution VIII (Approval Workflow & Publisher Identity): Phase 12 IS the approval workflow itself. The reject reason flows from the admin's dialog through the Edge Function through the JSON-encoded `listing_status_history.reason` to the publisher's `MyListingsPage` rejection banner — closing the loop. The Q3=A six-preset taxonomy is publisher-actionable. The admin's identity is preserved in `listing_status_history.changed_by` + `audit_logs.actor_user_id` for internal audit; the publisher-facing UI shows only "Admin team" per FR-015 / FR-017, preserving moderator anonymity.
- Constitution IX (Future Backend Portability): `lib/features/admin/listing_review/domain/` AND `lib/features/publisher_dashboard/domain/` continue to be Supabase-free. The new use cases (`LoadPendingQueue`, `LoadListingPreview`, `ApproveListing`, `RejectListing`, `LoadModerationHistory`) are abstract Dart classes. Only `lib/features/admin/listing_review/data/datasources/supabase_listing_review_datasource.dart` (new) and `lib/features/publisher_dashboard/data/datasources/supabase_publisher_dashboard_datasource.dart` (extended) touch Supabase types. The five Q8=A shared display widgets accept domain entities as inputs — no Supabase types in their public APIs.
- Migrations apply to the **remote** Supabase project via Supabase MCP `apply_migration`. Edge Functions deploy via Supabase MCP `deploy_edge_function`. The project memory `project_supabase_mcp_apply_migration.md` is binding — re-applying a migration name re-runs the SQL AND adds a duplicate tracker row, so the FR-024 migration name is unique.
- Migrations MUST be idempotent (`CREATE OR REPLACE FUNCTION`, `ON CONFLICT DO NOTHING` for the conditional perm-key seed).
- The `log_audit()` reusable trigger function is **narrowly amended** in Phase 12 per Q7=A — the byte-identical R-05 invariant is relaxed to "byte-identical except for the actor-source COALESCE on the `actor_user_id` insertion expression". Every Phase 5–11 caller continues to produce correctly-attributed audit rows because the COALESCE falls back to `auth.uid()` when the session variable is unset.
- **Zero new packages** in `pubspec.yaml` (Phase 12 reverses Phase 11's R-22 three-package addition to a zero-package phase).
- **Zero AndroidManifest changes** (Phase 12 needs no new Android permissions).
- No iOS-only code (Constitution XI).

**Scale/Scope**:

- **One mandatory new SQL migration** under `supabase/migrations/` — `20260523120004_amend_phase10_phase4_triggers_for_session_var.sql` (FR-024). Contains five `CREATE OR REPLACE FUNCTION` statements: three trigger / log_audit amendments AND two new session-variable setter functions (`set_app_user_id_for_session` + `set_app_rejection_reason_for_session`).
- **One conditional new SQL migration** under `supabase/migrations/` — `20260523120005_seed_listings_reject_permission_if_missing.sql` (FR-004). Ships only if the plan-time R-49 audit reveals the gap.
- **Two new Edge Function files** under `supabase/functions/`:
  - `supabase/functions/approve_listing/index.ts`
  - `supabase/functions/reject_listing/index.ts`
- **Three updated doc files** under `supabase/docs/`:
  - `listings.md` — UPDATE — note Phase 12's `approve_listing` writer + the Q2=A `expires_at = NULL` default behavior.
  - `listing_status_history.md` — UPDATE — note the Q4=A JSON-encoded `reason` storage rep + the amended trigger function body.
  - `audit_logs.md` — UPDATE — enumerate the two new action keys (`listing.approved`, `listing.rejected`) + the Q7=A actor-source amendment + the narrow R-05 relaxation.
- **One new feature folder** under `lib/features/admin/listing_review/` carrying the full three-layer split:
  - `data/datasources/supabase_listing_review_datasource.dart` — NEW — only Phase 12 file in `lib/features/admin/listing_review/` importing `package:supabase_flutter`. Exposes `loadPendingQueue(cursor)`, `loadListingPreview(id)`, `approveListing(id)`, `rejectListing(id, preset, detail)` — all of which delegate to `Supabase.instance.client.from('listings').select(...)` (queue + preview) AND `Supabase.instance.client.functions.invoke('approve_listing'|'reject_listing', body: {...})` (mutators).
  - `data/dtos/pending_listing_summary_dto.dart` — NEW — DTO matching the queue card join shape (listing + main_media + governorate/city/area names + primary price + publisher's display name + submitted_at).
  - `data/repositories/listing_review_repository_impl.dart` — NEW — concrete repository impl.
  - (`domain/entities/rejection_reason.dart` was originally planned HERE but RELOCATED to `lib/core/listing/rejection_reason.dart` per analysis finding C2 — the enum is consumed by BOTH the admin feature AND the publisher_dashboard feature, so a feature-neutral location avoids cross-feature imports. See tasks.md T016 + data-model.md §3.1 location-update note.)
  - `domain/entities/pending_listing_summary.dart` — NEW — entity for the queue card.
  - `domain/entities/listing_preview.dart` — NEW — aggregate entity for the preview page (composes Phase 8 location + Phase 9 prices + Phase 10 listing + listing_details + Phase 11 listing_media).
  - `domain/repositories/listing_review_repository.dart` — NEW — abstract repository.
  - `domain/usecases/load_pending_queue.dart` — NEW.
  - `domain/usecases/load_listing_preview.dart` — NEW.
  - `domain/usecases/approve_listing.dart` — NEW.
  - `domain/usecases/reject_listing.dart` — NEW.
  - `presentation/bloc/pending_queue_bloc.dart` — NEW — handles `LoadFirstPage`, `LoadNextPage`, `Refresh` events; emits `PendingQueueState` with cursor + listings list + loading + error states.
  - `presentation/bloc/listing_preview_bloc.dart` — NEW — handles `LoadPreview(id)`, `ApprovePressed`, `RejectPressed(preset, detail)` events; emits `ListingPreviewState` with the preview aggregate + mutator-in-flight flag + success / error states.
  - `presentation/pages/pending_queue_page.dart` — NEW.
  - `presentation/pages/listing_preview_page.dart` — NEW.
  - `presentation/widgets/pending_queue_card.dart` — NEW.
  - `presentation/widgets/reject_reason_dialog.dart` — NEW — the FR-013 modal with six preset chips + free-text field + Q5=A enable-Confirm rule.
  - `presentation/widgets/approve_confirmation_dialog.dart` — NEW.
- **One extended existing feature folder** under `lib/features/publisher_dashboard/`:
  - `data/datasources/supabase_publisher_dashboard_datasource.dart` — EXTEND — gains `loadModerationHistory(listingId)` method.
  - `data/repositories/publisher_dashboard_repository_impl.dart` — EXTEND — gains the corresponding method.
  - `domain/entities/moderation_history_entry.dart` — NEW — entity for the moderation history list row (`previous_status`, `new_status`, `changed_at`, `reason_preset?`, `reason_detail?`).
  - `domain/repositories/publisher_dashboard_repository.dart` — EXTEND.
  - `domain/usecases/load_moderation_history.dart` — NEW.
  - `presentation/bloc/moderation_history_cubit.dart` — NEW — a lightweight Cubit (read-only page, no events besides initial load).
  - `presentation/pages/listing_moderation_history_page.dart` — NEW per FR-017.
  - `presentation/pages/my_listings_page.dart` — EXTEND — the Rejected filter section now includes the rejection-reason banner per FR-015 + the Resubmit button per FR-016 + the View moderation history link per FR-017.
  - `presentation/widgets/rejection_reason_banner.dart` — NEW — the banner per FR-015 with the Q4=A JSON parse.
  - `presentation/widgets/resubmit_button.dart` — NEW (or a simple inline `OutlinedButton` per design-token guidance — research-time decides).
- **One new shared-widget subdirectory** at `lib/shared/presentation/widgets/listing_display/` per Q8=A — five new pure-render widgets:
  - `listing_gallery.dart` — `ListingGallery({required List<ListingMedia> media})` — consumes Phase 11's `listing_media` rows ordered by `ordering ASC` with `is_main=true` first; uses `cached_network_image` against `getPublicUrl()` URLs from Phase 11.
  - `listing_price_block.dart` — `ListingPriceBlock({required List<ListingPrice> prices, required Currency displayCurrency})` — Phase 9 `MoneyFormatter`.
  - `listing_location_block.dart` — `ListingLocationBlock({required Governorate gov, required City city, required Area area})` — Phase 8.
  - `listing_amenities_block.dart` — `ListingAmenitiesBlock({required Map<String, dynamic> amenities})` — Phase 10.
  - `listing_description_block.dart` — `ListingDescriptionBlock({required String description})` — Phase 10.
- **One extended existing routing file** at `lib/core/routing/app_router.dart`: three new routes — `/admin/listing-review/pending` (queue), `/admin/listing-review/preview/:id` (preview), `/publisher/listings/:id/moderation-history` (moderation history). Each gated by the existing `auth_redirect.dart` guard composed with a new `PermissionChecker.any([...])` route guard.
- **One extended existing page** at `lib/features/admin/presentation/pages/admin_home_page.dart` (Phase 6 admin home) gaining a new "Pending review" tile per FR-008 + FR-009 (the tile is gated by `PermissionChecker.any(['listings.approve', 'listings.reject'])`).
- **ARB key delta** on `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`: approximately 32 new strings — `admin.tile.pendingReview`, `admin.queue.title`, `admin.queue.empty`, `admin.queue.submittedAt.{just_now,minutes,hours,days}`, `admin.queue.publisherPrefix`, `admin.preview.title`, `admin.preview.cta.approve`, `admin.preview.cta.reject`, `admin.approveDialog.title`, `admin.approveDialog.body`, `admin.approveDialog.confirm`, `admin.approveDialog.cancel`, `admin.rejectDialog.title`, `admin.rejectDialog.detailLabel.optional`, `admin.rejectDialog.detailLabel.required`, `admin.rejectDialog.detailHint.other`, `admin.rejectDialog.counter`, `admin.rejectDialog.confirm`, `admin.rejectDialog.cancel`, `reject_preset_missing_or_low_quality_photos`, `reject_preset_incorrect_location`, `reject_preset_unrealistic_price`, `reject_preset_incomplete_description`, `reject_preset_duplicate_listing`, `reject_preset_other`, `publisher.rejection.attribution`, `publisher.rejection.resubmit`, `publisher.rejection.viewHistory`, `publisher.history.title`, `publisher.history.status.{draft,pending_review,approved,rejected,paused,sold,rented,expired,deleted}`, `publisher.history.adminTeam`, `admin.error.{permission_denied,invalid_status_transition,already_acted_on,invalid_reason_preset,reason_detail_too_long}`, `admin.toast.{approveSuccess,rejectSuccess}`. All keys ship to both ARB files in the same commit per Phase 3's localization gate.
- **0 new packages** in `pubspec.yaml`.
- **0 new tests** (durable no-new-tests rule).
- **0 changes** to `.github/workflows/ci.yml`.
- **0 changes** to `AndroidManifest.xml`.

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists with 6 user stories, 24 FRs (FR-001..FR-024), 32 SCs (SC-001..SC-032); `/speckit-clarify` Session 2026-05-23 resolved 5 additional questions (Q4 storage rep, Q5 "Other" UX gate, Q6 latency budget, Q7 trigger amendment, Q8 shared widget paths) on top of the 3 resolved during `/speckit-specify` (Q1 Edge Function, Q2 NULL expires_at, Q3 Minimal-5+Other presets). All 8 Qs are folded into FRs / SCs / Assumptions. No implementation has begun. |
| II. Source-Controlled Backend | **Pass** | Every Phase 12 backend artifact is a checked-in file: 1 mandatory migration + 1 conditional migration under `supabase/migrations/`, 2 Edge Function files under `supabase/functions/<name>/index.ts`, 3 updated doc files under `supabase/docs/`. The amendments to Phase 10's status-transition trigger + Phase 10's `listings_audit_trigger_fn` + Phase 4's `log_audit()` ship via `CREATE OR REPLACE FUNCTION` in the new Phase 12 migration — Phase 4's, Phase 6's, Phase 10's original migration files remain unedited per R-35 immutability. No Studio-only changes. Edge Function deployment goes through Supabase MCP `deploy_edge_function`, also a checked-in artifact path. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | Phase 10's RLS on `public.listings` is verified end-to-end against real `approved` rows (the first phase to exercise the public-read path with real data); no policy edit. Phase 11's `listing_media` + `storage.objects` policies are verified to honor parent-status flips per Phase 11 SC-025; no edits. The Edge Functions re-check the caller's permission via a JWT-bound client BEFORE performing the privileged UPDATE via a service-role client — the service-role key never leaves the Deno runtime. The session-variable setters are SECURITY DEFINER but the audit trail remains correct because the Edge Function's permission check is the authoritative gate. The status-guard predicate `AND status='pending_review'` is the concurrency boundary — last-writer-wins with a structured `already_acted_on` error to the loser. No new anonymous-SELECT carve-outs (Phase 11 R-04 invariant preserved). The Q5=A UX-required "Other" detail rule is structurally enforced (Confirm disabled) but the server contract stays permissive — defense-in-depth keeps the structural gate at the server boundary (`invalid_reason_preset` for malformed preset; `reason_detail_too_long` for length violations). |
| IV. Clean Architecture Flutter | **Pass** | All new Dart code lives in the three-layer split. The new feature folder `lib/features/admin/listing_review/` carries `data/` + `domain/` + `presentation/`. The extended `lib/features/publisher_dashboard/` follows the same layout. The five Q8=A shared widgets live in `lib/shared/presentation/widgets/listing_display/` and accept domain entities only — they are pure-render. No widget calls Supabase. No use case imports Supabase. The two new BLoCs (`PendingQueueBloc` + `ListingPreviewBloc`) + one Cubit (`ModerationHistoryCubit`) keep BLoC ownership at the page boundary. |
| V. Arabic-First Localization | **Pass** | All ~32 new user-visible chrome strings flow through Phase 3's `AppLocalizations`. The six Q3=A preset keys each have a paired ARB key in `ar` AND `en`. The status-transition labels for all nine `public.listings.status` enum values are localized for the moderation history page. RTL is honored: the queue card uses `EdgeInsetsDirectional`; the preview's sticky bottom bar uses `AlignmentDirectional.bottomCenter`; the rejection banner uses `Directionality`-aware quote-block styling. The Phase 3 localization lint guard catches any hardcoded user-facing string at PR review. |
| VI. Theme System & Design Tokens | **Pass** | Every new widget under `lib/features/admin/listing_review/presentation/`, `lib/features/publisher_dashboard/presentation/pages/listing_moderation_history_page.dart`, `lib/features/publisher_dashboard/presentation/widgets/rejection_reason_banner.dart`, and `lib/shared/presentation/widgets/listing_display/` consumes Phase 2's design tokens. The preview's approve CTA uses Phase 2's `success` token; reject uses `danger`; the rejection banner uses `dangerContainer` background + `onDangerContainer` foreground; the moderation history page status chips reuse Phase 10's `status_badge.dart` from the publisher dashboard. No inline hex / font-size / padding. |
| VII. Dynamic Roles & Permissions | **Pass** | Phase 12 introduces zero new permission keys IF the FR-004 plan-time audit (R-49) confirms Phase 6's seed already inserted both `listings.approve` AND `listings.reject`. The conditional micro-migration ships only if the gap is real. The existing `PermissionChecker` gates the admin home tile + the queue route + the preview CTAs. The Edge Functions re-check the permission server-side via Phase 6's `current_user_has_permission` RPC — the frontend gates are UX convenience; the Edge Function is the security boundary (Constitution III + VII). Audit emission is universal: every approve / reject writes one `listing_status_history` row + one `audit_logs` row via the amended `listings_audit_trigger_fn`. The Phase 4 `log_audit()` narrow amendment per Q7=A preserves attribution correctness for every prior phase's call site (COALESCE falls back to `auth.uid()` when session var is unset). |
| VIII. Approval Workflow & Publisher Identity | **Pass** | Phase 12 IS the approval workflow itself. The Q3=A six-preset taxonomy is publisher-actionable (matches what the publisher needs to fix); the rejection reason flows from admin dialog → Edge Function → JSON-encoded `listing_status_history.reason` → publisher's `MyListingsPage` rejection banner → Resubmit deep-link back to the Phase 10 form. The admin's identity is preserved internally (in `listing_status_history.changed_by` + `audit_logs.actor_user_id`) but NEVER exposed in publisher UI (only "Admin team" per FR-015 / FR-017), preserving moderator anonymity per Constitution VIII intent. The Q2=A `expires_at=NULL` default keeps approved listings publicly visible indefinitely — matches the Syrian market context where listings persist for months. |
| IX. Future Backend Portability | **Pass** | `lib/features/admin/listing_review/domain/` AND `lib/features/publisher_dashboard/domain/` continue to import nothing from `package:supabase_flutter`. The new use cases (LoadPendingQueue / LoadListingPreview / ApproveListing / RejectListing / LoadModerationHistory) are abstract Dart classes. Only the two datasources touch Supabase types. The five Q8=A shared widgets accept domain entities only — no Supabase types in their public APIs. The Edge Functions' HTTP error responses (typed `{code, ...}` JSON shapes) are mapped to Dart `Failure` types in the data layer per R-53; the use cases see only `Result<T, Failure>` from the repository surface. |
| X. Testable AI Workflow | **Pass — Justified.** | Per `feedback_no_new_tests.md` carried forward from Phases 3–11, every FR is verifiable via a manual SQL action with expected output OR via Supabase MCP `execute_sql` / `list_tables` / `get_advisors` / Edge Function `duration_ms` log inspection OR via a two-device manual UI walk on the Infinix Note 8 + Pixel 8 Pro emulator. The trigger-amendment correctness, the Edge Function happy path + error responses, the concurrent-admin race, the audit-log attribution under the COALESCE amendment, the storage-RLS deny-on-status-revert path, the Q3=A preset enum match, the Q4=A JSON encoding / decoding, the Q5=A "Other" detail-required UX gate, the Q6=A ≤2s p95 latency, the Q7=A trigger amendment correctness for Phase 5–11 callers, the Q8=A widget reuse contract — all codified in `quickstart.md` as a manual-verification checklist. The constitution explicitly permits "a SQL query with expected output" or "a UI action with expected screen state" as acceptance steps. No constitutional amendment is required. |
| XI. Android-First MVP | **Pass** | All Flutter additions target the Android Flutter build only. No platform-conditional code. Zero new pubspec packages (no risk of iOS-only or web-only plugin churn). The Edge Functions are server-side TypeScript on Deno; they have no Android / iOS / web bearing. The R-55 two-device walk includes the Infinix Note 8 (publisher device) + the Pixel 8 Pro emulator (admin device) — both Android targets; no iOS path is exercised. The admin queue + preview UX is sized for the 6.78" portrait screen but reflows correctly on the Pixel 8 Pro emulator's larger 6.2" portrait. |
| XII. No Hidden Product Decisions | **Pass** | All eight Session 2026-05-23 clarifications (Q1 through Q8) are captured in `spec.md` `## Clarifications`. The Q1=B Edge Function path acknowledges that Phase 5 already shipped Edge Functions — Phase 12 is the FIRST listings-domain Edge Functions, not the project's first ever. The Q2=A NULL expires_at decision is recorded with the Syrian-market rationale. The Q3=A six-preset taxonomy is enumerated explicitly. The Q4=A JSON-encoded TEXT storage rep is captured in FR-003 + SC-027. The Q5=A "Other" UX rule is captured in FR-013(d)+(f) + SC-028. The Q6=A latency budget is captured in SC-029. The Q7=A trigger + log_audit amendment is captured in FR-024 + SC-030 + SC-031 — including the R-05 narrow-relaxation acknowledgement. The Q8=A widget paths are captured in FR-011 + SC-032. Every plan-time research item (R-41..R-60) has a paired clarification answer or a paired FR/SC; no decision lives only in conversation. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/012-listing-approval/
├── plan.md                              # This file (/speckit-plan output)
├── research.md                          # Phase 0 — 20 locked tech decisions (R-41..R-60 — picks up from Phase 11 R-40)
├── data-model.md                        # Phase 1 — full FR-024 amendment SQL bodies (3 functions + 2 setters) + Edge Function I/O contracts + Dart entity / DTO / use case shapes + ARB key inventory + per-FR / per-SC verification map
├── quickstart.md                        # Phase 1 — manual verification recipe: FR-024 migration apply + Edge Function deploy + Pixel 8 Pro emulator admin walk + Infinix Note 8 publisher walk + SC matrix
├── contracts/                           # Phase 1 — 10 interface contracts
│   ├── phase12-approve-listing-edge-function.md           # NEW — POST body + response shapes + error codes + permission check + UPDATE predicate
│   ├── phase12-reject-listing-edge-function.md            # NEW — POST body + 6-preset validator + Q4=A JSON build + UPDATE predicate
│   ├── phase12-trigger-and-log-audit-amendment.md         # NEW — FR-024 amendment contract: 3 functions amended + 2 session-variable setter functions + R-05 narrow relaxation
│   ├── phase12-rejection-reason-storage-format.md         # NEW — Q4=A JSON-encoded-TEXT shape + read pattern + future-spec JSONB conversion path
│   ├── phase12-admin-queue-page.md                        # NEW — queue route + card composition + cursor pagination contract
│   ├── phase12-listing-preview-page.md                    # NEW — preview composition consuming the Q8=A shared widgets + sticky bottom bar CTAs
│   ├── phase12-shared-display-widgets.md                  # NEW — Q8=A five widgets API surface (constructor params, render contract, theming hooks)
│   ├── phase12-reject-reason-dialog.md                    # NEW — FR-013 dialog including Q5=A "Other" UX-required gate + Q3=A six presets
│   ├── phase12-publisher-rejection-banner.md              # NEW — FR-015 banner + Q4=A JSON parse pattern
│   └── phase12-moderation-history-page.md                 # NEW — FR-017 read-only page + admin-identity-suppression rule
├── checklists/
│   └── requirements.md                  # From /speckit-specify + /speckit-clarify (all 8 Qs resolved; checklist fully green)
├── spec.md                              # From /speckit-specify + /speckit-clarify (Q1=B Edge Function, Q2=A NULL expires_at, Q3=A Minimal-5+Other, Q4=A JSON TEXT, Q5=A Other-required-UX, Q6=A 2s p95, Q7=A session-var amendment, Q8=A shared widget paths)
├── tasks.md                             # Created by /speckit-tasks (NOT by /speckit-plan)
├── DEFERRED.md                          # Created during /speckit-implement; reviewed at squash-merge per project_deferred_work.md
└── HANDOFF.md                           # Created at /speckit-implement close-out (or omit if no follow-up scope)
```

### Source Code (repository root)

```text
supabase/
├── config.toml                                                            # (existing) NO CHANGE.
├── seed.sql                                                               # (existing) NO CHANGE.
├── migrations/
│   ├── (existing Phase 1–11 migrations)                                   # NO CHANGE.
│   ├── 20260523120004_amend_phase10_phase4_triggers_for_session_var.sql   # NEW per FR-024 — 5 CREATE OR REPLACE FUNCTION statements: 3 amendments (status-transition trigger, listings_audit_trigger_fn, log_audit) + 2 session-variable setters (set_app_user_id_for_session, set_app_rejection_reason_for_session). (FR-024, SC-030, SC-031.)
│   └── 20260523120005_seed_listings_reject_permission_if_missing.sql      # CONDITIONAL per FR-004 — ships only if Phase 6 seed audit reveals the listings.reject key gap. (FR-004.)
├── functions/
│   ├── (existing Phase 5 functions: lookup_email_by_phone, request_password_reset)  # NO CHANGE.
│   ├── approve_listing/
│   │   └── index.ts                                                       # NEW — ~80 lines TS/Deno. JWT-bound permission check + service-role UPDATE + session-var setter + audit attribution. (FR-001, SC-022, SC-029.)
│   └── reject_listing/
│       └── index.ts                                                       # NEW — ~110 lines TS/Deno. Preset validator + detail length cap + Q4=A JSON build + session-var setters + UPDATE. (FR-002, SC-024, SC-027, SC-029.)
├── policies/                                                              # (existing dir) NO CHANGE — Phase 10's listings policies + Phase 11's listing_media / storage.objects policies all consumed unchanged.
└── docs/
    ├── (existing per-table docs)                                          # NO CHANGE except the 3 named below.
    ├── listings.md                                                        # UPDATE — note Phase 12 approve_listing writer + Q2=A NULL expires_at default + no policy edits.
    ├── listing_status_history.md                                          # UPDATE — note Q4=A JSON-encoded reason storage rep + amended trigger function body (FR-024) + Q7=A session-variable handoff.
    └── audit_logs.md                                                      # UPDATE — enumerate the 2 new action keys (listing.approved, listing.rejected) + the Q7=A actor-source amendment + the R-05 narrow relaxation.

lib/
├── core/
│   ├── routing/
│   │   └── app_router.dart                                                # UPDATE — 3 new routes: /admin/listing-review/pending, /admin/listing-review/preview/:id, /publisher/listings/:id/moderation-history. Each gated by auth_redirect + PermissionChecker.any([...]).
│   ├── security/
│   │   └── permission_checker.dart                                        # NO CHANGE — Phase 6 + Phase 11 implementation consumed verbatim.
│   ├── errors/
│   │   └── failure.dart                                                   # UPDATE — add 5 new Failure subtypes for the Edge Function error codes: PermissionDeniedFailure, InvalidStatusTransitionFailure, AlreadyActedOnFailure, InvalidReasonPresetFailure, ReasonDetailTooLongFailure (R-53 mapping).
│   ├── listing/
│   │   └── rejection_reason.dart                                          # NEW per analysis finding C2 — feature-neutral Dart enum carrying the six Q3=A keys. Imported by both admin/listing_review AND publisher_dashboard features.
│   └── network/
│       └── supabase_client.dart                                           # NO CHANGE — Phase 1 wrapper consumed verbatim; the new datasources call .from() and .functions.invoke() through this wrapper.
├── features/
│   ├── admin/
│   │   ├── account_approvals/                                             # (Phase 5 existing) NO CHANGE.
│   │   ├── listing_review/                                                # NEW FEATURE FOLDER
│   │   │   ├── data/
│   │   │   │   ├── datasources/
│   │   │   │   │   └── supabase_listing_review_datasource.dart            # NEW — only Phase 12 admin/listing_review file importing package:supabase_flutter.
│   │   │   │   ├── dtos/
│   │   │   │   │   └── pending_listing_summary_dto.dart                   # NEW — DTO for the queue card join.
│   │   │   │   └── repositories/
│   │   │   │       └── listing_review_repository_impl.dart                # NEW.
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   │   # (rejection_reason.dart RELOCATED — see lib/core/listing/ below per C2)
│   │   │   │   │   ├── pending_listing_summary.dart                       # NEW.
│   │   │   │   │   └── listing_preview.dart                               # NEW — aggregate entity for the preview page.
│   │   │   │   ├── repositories/
│   │   │   │   │   └── listing_review_repository.dart                     # NEW.
│   │   │   │   └── usecases/
│   │   │   │       ├── load_pending_queue.dart                            # NEW.
│   │   │   │       ├── load_listing_preview.dart                          # NEW.
│   │   │   │       ├── approve_listing.dart                               # NEW.
│   │   │   │       └── reject_listing.dart                                # NEW.
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       │   ├── pending_queue_bloc.dart                            # NEW.
│   │   │       │   └── listing_preview_bloc.dart                          # NEW.
│   │   │       ├── pages/
│   │   │       │   ├── pending_queue_page.dart                            # NEW — FR-009.
│   │   │       │   └── listing_preview_page.dart                          # NEW — FR-011.
│   │   │       └── widgets/
│   │   │           ├── pending_queue_card.dart                            # NEW — FR-010.
│   │   │           ├── reject_reason_dialog.dart                          # NEW — FR-013 with Q5=A gate.
│   │   │           └── approve_confirmation_dialog.dart                   # NEW.
│   │   └── presentation/
│   │       └── pages/
│   │           └── admin_home_page.dart                                   # UPDATE — add "Pending review" tile (Phase 6 file extended in place).
│   ├── publisher_dashboard/                                               # EXTEND existing feature folder
│   │   ├── data/
│   │   │   ├── datasources/
│   │   │   │   └── supabase_publisher_dashboard_datasource.dart           # EXTEND — gains loadModerationHistory(listingId).
│   │   │   └── repositories/
│   │   │       └── publisher_dashboard_repository_impl.dart               # EXTEND.
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── moderation_history_entry.dart                          # NEW.
│   │   │   ├── repositories/
│   │   │   │   └── publisher_dashboard_repository.dart                    # EXTEND.
│   │   │   └── usecases/
│   │   │       └── load_moderation_history.dart                           # NEW.
│   │   └── presentation/
│   │       ├── bloc/
│   │       │   └── moderation_history_cubit.dart                          # NEW — lightweight Cubit.
│   │       ├── pages/
│   │       │   ├── my_listings_page.dart                                  # EXTEND — Rejected filter section gets the rejection-reason banner + Resubmit + View moderation history link.
│   │       │   └── listing_moderation_history_page.dart                   # NEW — FR-017.
│   │       └── widgets/
│   │           ├── rejection_reason_banner.dart                           # NEW — FR-015.
│   │           └── resubmit_button.dart                                   # NEW — FR-016 (or inline OutlinedButton — research decides).
│   └── (existing Phase 10 listing_form, Phase 11 etc.)                    # NO CHANGE.
├── shared/
│   └── presentation/
│       └── widgets/
│           ├── (existing admin_list_item.dart, listing_card.dart, price_display.dart)  # NO CHANGE.
│           └── listing_display/                                           # NEW DIR per Q8=A
│               ├── listing_gallery.dart                                   # NEW — FR-011 + Q8=A.
│               ├── listing_price_block.dart                               # NEW — FR-011 + Q8=A.
│               ├── listing_location_block.dart                            # NEW — FR-011 + Q8=A.
│               ├── listing_amenities_block.dart                           # NEW — FR-011 + Q8=A.
│               └── listing_description_block.dart                         # NEW — FR-011 + Q8=A.
└── l10n/
    ├── app_ar.arb                                                         # UPDATE — ~32 new ARB keys per FR-018.
    └── app_en.arb                                                         # UPDATE — ~32 new ARB keys per FR-018.

# NO CHANGE: pubspec.yaml, pubspec.lock, android/app/src/main/AndroidManifest.xml, analysis_options.yaml, .github/workflows/.
```

**Structure Decision**: This feature lives across the Supabase backend tree (`supabase/migrations/`, `supabase/functions/`, `supabase/docs/`) AND the Flutter app tree (`lib/features/admin/listing_review/`, `lib/features/publisher_dashboard/`, `lib/shared/presentation/widgets/listing_display/`, `lib/core/routing/`, `lib/l10n/`). Phase 12 is the first phase to ship Edge Functions for the listings domain (Phase 5 shipped Edge Functions for auth lookups; Phase 12 extends the pattern). The shared-widget subdirectory at `lib/shared/presentation/widgets/listing_display/` is a new Phase 12 surface but follows the existing `lib/shared/presentation/widgets/` convention from Phase 2.

## Complexity Tracking

> No Constitution Check violations. Section intentionally empty.
