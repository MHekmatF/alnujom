# Phase 1 Quickstart — Phase 12: Listing Approval Workflow

**Date**: 2026-05-23
**Branch**: `012-listing-approval`
**Spec**: [spec.md](spec.md) • **Plan**: [plan.md](plan.md) • **Research**: [research.md](research.md) • **Data model**: [data-model.md](data-model.md)

> **Purpose**: 19 sequential manual-verification steps that a reviewer or new agent runs against the remote Supabase project + the Pixel 8 Pro emulator (admin device) + the Infinix Note 8 (publisher device) to confirm Phase 12 is shipped correctly. Per `feedback_no_new_tests.md`, this replaces an automated test suite.

## Prerequisites

- Phase 1–11 deployed to remote Supabase project (verified via `list_migrations` MCP call).
- Local repository on branch `012-listing-approval` with the Phase 12 implementation merged into the working tree (FR-024 migration file + 2 Edge Function files + Dart additions + ARB key updates).
- Supabase MCP server reachable.
- `.env.local` at `supabase/functions/` carrying `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` (already provisioned per ADR-0001).
- Two Phase 5 approved-publisher accounts in the database (let's call them `publisher_alice` and `publisher_bob`).
- Two admin accounts holding `listings.approve` AND `listings.reject` (let's call them `admin_carol` and `admin_dave`).
- One existing draft listing owned by `publisher_alice` ready to submit; another existing draft owned by `publisher_bob` (for the parallel publisher-side verification).

## Step 1 — Apply the FR-024 migration

```
apply_migration(
  name="20260523120004_amend_phase10_phase4_triggers_for_session_var",
  query=<full body from data-model.md §1.1–1.4>
)
```

Verify: `execute_sql("SELECT proname FROM pg_proc WHERE proname IN ('set_app_user_id_for_session', 'set_app_rejection_reason_for_session', 'listing_status_transition_trigger_fn', 'listings_audit_trigger_fn', 'log_audit')")` returns 5 rows.

Verify R-05 narrow relaxation: `execute_sql("SELECT position('coalesce(nullif(current_setting(''app.current_user_id''' IN pg_get_functiondef(p.oid)) > 0 AS amended FROM pg_proc p WHERE proname = 'log_audit'")` returns one row with `amended = true`.

## Step 2 — Deploy the two Edge Functions

```
deploy_edge_function(name="approve_listing", source=<file body from supabase/functions/approve_listing/index.ts>)
deploy_edge_function(name="reject_listing",  source=<file body from supabase/functions/reject_listing/index.ts>)
```

Verify via Supabase Dashboard Edge Functions panel: both functions listed with status "Active".

## Step 3 — Confirm zero permission-seed gap (R-45 audit)

```sql
execute_sql(
  "SELECT key FROM public.permissions WHERE key IN ('listings.approve', 'listings.reject') ORDER BY key"
)
```

Expected: 2 rows (`listings.approve`, `listings.reject`). The conditional FR-004 migration is NOT applied.

```sql
execute_sql(
  "SELECT r.key AS role_key, p.key AS perm_key
   FROM public.role_permissions rp
   JOIN public.roles r ON r.id = rp.role_id
   JOIN public.permissions p ON p.id = rp.permission_id
   WHERE p.key IN ('listings.approve', 'listings.reject')
     AND r.key IN ('moderator', 'admin', 'super_admin')
   ORDER BY r.key, p.key"
)
```

Expected: 6 rows (3 roles × 2 perms).

## Step 4 — Admin queue first load (SC-010)

Sign in on the **Pixel 8 Pro emulator** as `admin_carol`. Navigate to admin home → tap "Pending review" tile.

Verify: page lists ≥ 2 listings (Alice's + Bob's pending submissions, plus any other pre-existing). Ordering is oldest-first. Each card shows main image thumbnail + title + property type chip + location names + price + publisher name + time-since-submit.

If ≥ 21 pending listings exist, scroll to the bottom → confirm next page loads (20-per-page cursor pagination).

## Step 5 — Listing preview page (SC-011)

Tap Alice's pending listing card.

Verify: preview page renders gallery (Phase 11 media), price block (Phase 9 MoneyFormatter), location block (Phase 8), amenities, description. Gallery carousel scrolls; main image is first. Approve / Reject buttons sticky at the bottom.

Cross-check by Q8=A: the same widgets MUST be importable from `lib/shared/presentation/widgets/listing_display/` — verify via `ls lib/shared/presentation/widgets/listing_display/` returning 5 files.

## Step 6 — Reject path (SC-004, SC-012, SC-027, SC-028)

Tap "Reject". Dialog opens.

Verify: 6 preset radio options visible with localized labels. Free-text field label is "Additional details (optional)". Confirm button disabled.

Select "Photos missing or low quality". Detail field label stays "optional". Confirm enables (the chosen preset is non-Other).

Now select "Other". Detail field label flips to "(required)" and the hint appears. Confirm DISABLES again (Q5=A gate).

Type "The main photo appears to be a stock image; please re-upload." into the detail field. Confirm enables. Counter shows "{n}/500" updating live.

Switch back to "Photos missing or low quality" preset, then tap Confirm.

Watch the network panel / Edge Function logs: `reject_listing` invoked. Returns HTTP 200 within ≤ 2 seconds (SC-029).

Verify via SQL (Q4=A JSON shape — SC-027):

```sql
execute_sql(
  "SELECT
     reason,
     (reason::jsonb)->>'preset' AS preset,
     (reason::jsonb)->>'detail' AS detail
   FROM public.listing_status_history
   WHERE listing_id = '<alice-listing-id>' AND new_status = 'rejected'
   ORDER BY changed_at DESC LIMIT 1"
)
```

Expected:
- `reason` is `{"preset":"missing_or_low_quality_photos","detail":"The main photo appears to be a stock image; please re-upload."}`
- `preset = 'missing_or_low_quality_photos'`
- `detail = 'The main photo appears to be a stock image; please re-upload.'`

## Step 7 — Audit + attribution (SC-003, SC-004, SC-005, SC-030)

```sql
execute_sql(
  "SELECT
     action,
     actor_user_id,
     target_id,
     before_state,
     after_state
   FROM public.audit_logs
   WHERE action IN ('listing.approved', 'listing.rejected')
     AND target_id = '<alice-listing-id>'
   ORDER BY created_at DESC LIMIT 1"
)
```

Expected: 1 row. `action = 'listing.rejected'`. `actor_user_id` equals `admin_carol`'s UID (NOT NULL, NOT the service-role UID). `before_state` shows `{status:'pending_review'}`. `after_state` carries the preset + detail.

```sql
execute_sql(
  "SELECT changed_by FROM public.listing_status_history
   WHERE listing_id = '<alice-listing-id>' AND new_status = 'rejected'
   ORDER BY changed_at DESC LIMIT 1"
)
```

Expected: `changed_by` equals `admin_carol`'s UID.

## Step 8 — Public read RLS, draft path (SC-002)

From a DESKTOP terminal with an anonymous Supabase client (no auth):

```js
supabase.from('listings').select('id, status').limit(10);
```

Verify: only `status='approved'` rows are returned. Alice's just-rejected listing is NOT visible. Bob's draft is NOT visible. Any pre-existing approved listings ARE visible.

## Step 9 — Approve path (SC-003, SC-009, SC-023, SC-029)

Back on the Pixel 8 Pro emulator. Tell Alice to fix her listing (or do it for her via SQL). Re-submit (the rejection → resubmit chain — Phase 10 form's edit-in-place per Phase 11 Q3=A). The listing returns to `pending_review`.

In the admin queue, tap Alice's listing card. Preview page opens. Tap "Approve". Confirmation dialog appears. Tap Confirm.

`approve_listing` Edge Function invoked. Returns HTTP 200 within ≤ 2 seconds (SC-029 warm path).

Verify (SC-003 + SC-023):

```sql
execute_sql(
  "SELECT status, published_at, expires_at
   FROM public.listings WHERE id = '<alice-listing-id>'"
)
```

Expected: `status='approved'`, `published_at` ≈ now() (within last few seconds), `expires_at IS NULL`.

Verify (SC-009): from the anonymous desktop client:

```js
supabase.from('listings').select('*').eq('id', '<alice-listing-id>').single();
// Expected: row returned (RLS permits — status='approved').

supabase.storage.from('listing-images').getPublicUrl('<alice-listing-id>/0_xxxxx.jpg');
// Open the URL in a browser. Expected: image bytes returned (Phase 11 storage RLS permits).
```

## Step 10 — Reject dialog UX (Pixel 8 Pro emulator visual check; SC-012, SC-028 UX side)

Already exercised in Step 6. Re-confirm the dialog renders correctly in both `ar` and `en` locales by toggling locale in user preferences and re-opening the dialog on a pending listing. The Q3=A six preset labels MUST render in the active locale.

## Step 11 — Publisher rejection banner (SC-013)

On the **Infinix Note 8**, sign in as `publisher_alice`. Open `MyListingsPage` → Rejected filter.

Hmm — by now Alice's listing is approved again. So either reject Alice's listing AGAIN (using the resubmit-reject loop) OR use a separate test listing.

For this step, do a fresh reject on a different listing. Then on the Infinix Note 8 as the owning publisher, navigate to the Rejected filter.

Verify: rejection banner above the card shows:
- "Reviewed by admin team • {time-since}" attribution
- Localized preset label
- Free-text detail in a quoted block (with the `>` style)
- Resubmit button
- "View moderation history" link

Confirm the admin's identity (`admin_carol` name) is NOT exposed anywhere on the banner — only "Admin team".

## Step 12 — Resubmit deep-link (FR-016)

Tap "Resubmit". Phase 10's edit route opens, pre-populated. Phase 11's Q3=A `listing_media` rows are preserved (Phase 11 spec contract).

Walk through the form. Reach the Review step. Tap Submit. Listing transitions back to `pending_review`. Status-history shows the chain `pending_review → rejected → pending_review`.

## Step 13 — Moderation history page (SC-014)

Tap "View moderation history" on the rejection banner.

Verify: page renders every `listing_status_history` row for this listing in chronological order. Each row shows previous_status → new_status (localized labels via the ARB keys). Rejection rows show the preset + detail. Admin identity NEVER exposed (only "Admin team").

For a multi-cycle history (rejected → resubmitted → rejected again → resubmitted → approved), confirm all rows render in order.

## Step 14 — Route guard for unpermitted (SC-026)

Sign in as a basic `user` role account (no admin permissions). Manually navigate to `/admin/listing-review/pending` via the URL bar (or via `flutter run`'s deep-link `--launch-url`).

Verify: redirected to admin home (or publisher home) with a localized "Insufficient permissions" toast.

Repeat for `/admin/listing-review/preview/<some-id>` → same redirect.

## Step 15 — Non-admin invokes Edge Function directly (SC-006)

From the desktop with a `user`-role JWT (not admin):

```bash
curl -X POST "${SUPABASE_URL}/functions/v1/approve_listing" \
  -H "Authorization: Bearer <user JWT>" \
  -H "Content-Type: application/json" \
  -d '{"listing_id":"<some-pending-listing-id>"}'
```

Expected response: HTTP 403, body `{"code":"permission_denied"}`. No state change. No audit row. Verify via:

```sql
execute_sql(
  "SELECT count(*) FROM public.audit_logs
   WHERE action = 'listing.approved' AND target_id = '<some-pending-listing-id>'
     AND created_at > '<just-now>'"
)
-- Expected: 0
```

## Step 16 — Concurrent admin race (SC-007 + R-54)

Sign in as `admin_carol` on the Pixel 8 Pro emulator. Sign in as `admin_dave` on a desktop browser using the same admin app. Both admins navigate to the same pending listing's preview page.

Both admins tap Approve nearly simultaneously. Both Confirm in their respective dialogs.

Expected:
- One admin (the first to commit) sees the success toast.
- The other admin sees an `already_acted_on` error toast keyed by `admin.error.already_acted_on`.
- Only ONE `audit_logs` row of `action='listing.approved'` for the listing.
- Only ONE `listing_status_history` row of `new_status='approved'`.

Verify:

```sql
execute_sql(
  "SELECT count(*) FROM public.audit_logs
   WHERE action = 'listing.approved' AND target_id = '<that-listing-id>'
     AND created_at > '<just-now>'"
)
-- Expected: 1
```

## Step 17 — Media inaccessible on status revert (SC-008)

Take the just-approved listing. Flip its status back to `paused` via direct SQL (or a future-spec admin tool):

```sql
execute_sql("UPDATE public.listings SET status = 'paused' WHERE id = '<that-listing-id>'")
```

From the anonymous desktop client:

```js
supabase.from('listings').select('*').eq('id', '<that-listing-id>').single();
// Expected: { data: null } or 0 rows.

supabase.storage.from('listing-images').download('<that-listing-id>/0_xxxxx.jpg');
// Expected: 403 / NoAccess.
```

Flip status back to `approved`:

```sql
execute_sql("UPDATE public.listings SET status = 'approved' WHERE id = '<that-listing-id>'")
```

Re-issue both queries → anonymous SELECT returns the row AND storage download returns the bytes.

## Step 18 — Reject-resubmit-reject chain (SC-020)

Use Alice's listing (or a fresh test listing).

1. Pending → admin rejects → `listing_status_history` has 1 row with `new_status='rejected'`, `audit_logs` has 1 row with `action='listing.rejected'`.
2. Publisher resubmits → Pending again. Status-history adds a row `new_status='pending_review'`.
3. Admin rejects again → status-history adds another `new_status='rejected'` row, audit-logs adds another `action='listing.rejected'` row.

```sql
execute_sql(
  "SELECT count(*) FROM public.listing_status_history
   WHERE listing_id = '<that-listing-id>' AND new_status = 'rejected'"
)
-- Expected: 2

execute_sql(
  "SELECT count(*) FROM public.audit_logs
   WHERE action = 'listing.rejected' AND target_id = '<that-listing-id>'"
)
-- Expected: 2
```

Each row carries the rejection reason from its respective Phase 12 invocation. The publisher banner reflects the MOST RECENT rejection (per FR-015).

## Step 19 — Approve-revert-approve chain (SC-021)

Use a listing approved in Step 9 or 17.

1. Already approved with `published_at` = T1.
2. Direct SQL revert: `UPDATE listings SET status='paused' WHERE id='...'`. Status-history adds `approved → paused` row (with `changed_by = auth.uid()` of whoever's running the SQL).
3. Resubmit via Phase 12: this requires the listing to be in `pending_review`, NOT `paused`. So flip back to pending: `UPDATE listings SET status='pending_review' WHERE id='...'`. Status-history adds `paused → pending_review`.
4. Admin approves again via the Phase 12 UI. Status-history adds `pending_review → approved` with `changed_by = admin_carol`.

```sql
execute_sql(
  "SELECT new_status, changed_at, changed_by
   FROM public.listing_status_history
   WHERE listing_id = '<that-listing-id>'
   ORDER BY changed_at ASC"
)
```

Expected: a chronological chain showing every transition. Two `new_status='approved'` rows with different `published_at` timestamps on the parent listing — verify the second `published_at` is later than the first.

```sql
execute_sql(
  "SELECT count(*) FROM public.audit_logs
   WHERE action = 'listing.approved' AND target_id = '<that-listing-id>'"
)
-- Expected: 2
```

---

## SC matrix coverage (final check)

| SC | Verified in Step | Status |
|---|---|---|
| SC-001 | Manual stopwatch during Steps 4–6 | ⬜ |
| SC-002 | Step 8 | ⬜ |
| SC-003 | Step 9 | ⬜ |
| SC-004 | Step 6 | ⬜ |
| SC-005 | Step 1 | ⬜ |
| SC-006 | Step 15 | ⬜ |
| SC-007 | Step 16 | ⬜ |
| SC-008 | Step 17 | ⬜ |
| SC-009 | Step 9 | ⬜ |
| SC-010 | Step 4 | ⬜ |
| SC-011 | Step 5 | ⬜ |
| SC-012 | Step 6 + Step 10 | ⬜ |
| SC-013 | Step 11 | ⬜ |
| SC-014 | Step 13 | ⬜ |
| SC-015 | `grep -R "package:supabase_flutter" lib/features/admin/listing_review/presentation/` returns 0 | ⬜ |
| SC-016 | Phase 3 lint guard at PR review | ⬜ |
| SC-017 | grep for inline hex / EdgeInsets.only | ⬜ |
| SC-018 | Code review of Edge Function bodies (Step 2 sources) | ⬜ |
| SC-019 | Step 3 | ⬜ |
| SC-020 | Step 18 | ⬜ |
| SC-021 | Step 19 | ⬜ |
| SC-022 | `ls supabase/functions/` shows approve_listing AND reject_listing | ⬜ |
| SC-023 | Step 9 SQL | ⬜ |
| SC-024 | Code review of `lib/features/admin/listing_review/domain/entities/rejection_reason.dart` + Edge Function input validator | ⬜ |
| SC-025 | `grep -R "notifications" supabase/migrations/` returns 0 + `grep -R "Realtime\|channel.subscribe" lib/features/admin/listing_review/` returns 0 | ⬜ |
| SC-026 | Step 14 | ⬜ |
| SC-027 | Step 6 SQL | ⬜ |
| SC-028 | Step 6 UX side + Step 6 SQL (UI side gate; server permissive contract is OK) | ⬜ |
| SC-029 | Supabase Edge Function logs `duration_ms` over Steps 6 + 9 invocations | ⬜ |
| SC-030 | Step 7 | ⬜ |
| SC-031 | `git diff` against the prior commit showing zero edits to Phase 4 and Phase 10 migration files | ⬜ |
| SC-032 | `ls lib/shared/presentation/widgets/listing_display/` returns 5 files | ⬜ |

Mark each ⬜ → ✅ as the verification step passes.

## Rollback procedure (if any step fails)

1. If the FR-024 migration applied but a function body is wrong: re-apply the migration with corrected SQL (Supabase MCP `apply_migration` is idempotent on function bodies via `CREATE OR REPLACE`).
2. If an Edge Function deployed broken: re-deploy via `deploy_edge_function` with corrected source.
3. If the Flutter app has a runtime crash on the queue / preview / banner: pull the branch back to the prior commit AND re-investigate via `flutter logs` + `flutter run --debug`.
4. Phase 4's + Phase 10's original migration files are untouched, so reverting Phase 12 changes does NOT require migration rollback — the COALESCE amendments fall back to `auth.uid()` for every prior phase caller, so even if Phase 12 is partially deployed (migration applied but Edge Functions not yet deployed), Phase 5–11 audit / status-history flows continue to function correctly.
