# Quickstart: Listing Creation & Submit-for-Review

**Owner**: Phase 10 (`specs/010-listing-creation/`).
**Created**: 2026-05-18
**Status**: Manual verification recipe. Run end-to-end after `/speckit-implement` completes; rerun at squash-merge time.

This document is the canonical end-to-end manual verification recipe. It assumes:

- The Supabase MCP server is configured against the remote AlNujom project (the same one Phases 4–9 applied migrations to).
- A reference Infinix Note 8 device is connected to the dev machine via USB (Helio G80, 6 GB RAM, Android 10/11).
- The `.env.json` file is populated with the remote project's URL + anon key (per `project_dart_defines.md`).
- At least one Phase 5 user account exists with `account_status='approved' AND publisher_status='approved'`.
- At least one Phase 5 user account exists with `account_status='approved' AND publisher_status='pending'`.
- An admin account exists with `listings.view_all` permission (Phase 6 admin role).
- Phase 6's `current_user_has_permission()` helper and Phase 4's `log_audit()` / `set_updated_at()` functions are present and unchanged.

---

## Step 1 — Apply the seven migrations

Run via Supabase MCP `apply_migration` in order:

1. `20260519120001_alter_areas_add_centroids.sql` — ALTER public.areas + centroid seed.
2. `20260519120002_create_listings.sql`
3. `20260519120003_create_listing_details.sql`
4. `20260519120004_create_listing_prices.sql`
5. `20260519120005_create_listing_visibility.sql`
6. `20260519120006_create_listing_status_history.sql` (creates the triggers)
7. `20260519120007_create_submit_listing_rpc.sql`

Total apply time: under 90 seconds.

Verify via Supabase MCP `list_migrations` — confirm all seven entries are present, ordered after Phase 9 (final Phase 9 migration on remote per T005 baseline: `20260518120007_phase9_fk_index_hardening`).

Run `get_advisors` — expect zero new warnings (the RPC EXECUTE grants are REVOKEd from `PUBLIC, anon` and GRANTed to `authenticated` per FR-010).

## Step 2 — Verify schema

Via Supabase MCP `execute_sql`:

```sql
-- 5 new tables exist with RLS enabled
SELECT relname, relrowsecurity FROM pg_class
WHERE relnamespace=(SELECT oid FROM pg_namespace WHERE nspname='public')
  AND relname IN ('listings','listing_details','listing_prices','listing_visibility','listing_status_history');
-- Expected: 5 rows, all relrowsecurity=t

-- areas centroids non-null on every existing row
SELECT count(*) FROM public.areas WHERE centroid_lat IS NULL OR centroid_lng IS NULL;
-- Expected: 0

-- listings columns count
SELECT count(*) FROM information_schema.columns WHERE table_schema='public' AND table_name='listings';
-- Expected: 25

-- partial unique index on listing_prices
SELECT indexname FROM pg_indexes WHERE indexname='listing_prices_one_primary_idx';
-- Expected: 1 row

-- submit_listing function exists, SECURITY DEFINER
SELECT proname, prosecdef FROM pg_proc WHERE proname='submit_listing';
-- Expected: 1 row, prosecdef=t

-- EXECUTE permissions
SELECT grantee FROM information_schema.routine_privileges
WHERE routine_name='submit_listing' AND privilege_type='EXECUTE';
-- Expected: includes 'authenticated'; does NOT include 'anon' or 'PUBLIC'
```

## Step 3 — Anonymous read deny test

Via Supabase MCP `execute_sql` AS `anon`:

```sql
SELECT count(*) FROM public.listings;
-- Expected: 0 (no approved listings exist yet)

SELECT count(*) FROM public.listing_status_history;
-- Expected: 0 (RLS denies anon SELECT entirely)
```

## Step 4 — Run the Flutter app on the reference device

```
flutter run --dart-define-from-file=.env.json --release
```

Open the app on the Infinix Note 8.

## Step 5 — Non-approved publisher gate (US2)

1. Sign in as the `publisher_status='pending'` user.
2. Open the publisher-dashboard surface.
3. **Verify**: the "Create listing" tile is HIDDEN (not dimmed).
4. **Verify**: the existing Phase 5 pending-approval messaging is shown.
5. Hand-type the deep link `app://publisher/listings/create` (or use the dev menu to navigate by URL).
6. **Verify**: the router guard refuses; the device renders the publisher-approval-pending screen.
7. From the desktop with this user's JWT (via the Supabase MCP `execute_sql` against `auth`):

   ```sql
   INSERT INTO public.listings (publisher_user_id, purpose, property_type, title, governorate_id)
   VALUES ('<this user id>', 'sale', 'apartment', 'test', '<some governorate id>');
   -- Expected: ERROR / 0 rows affected (RLS deny)
   ```

8. Sign out.

## Step 6 — Approved publisher happy path (US1 + US5)

1. Sign in as the `publisher_status='approved' AND account_status='approved'` user.
2. **Verify**: the "Create listing" tile is VISIBLE.
3. Tap "Create listing".
4. **Verify**: the multi-step form opens at step 1 (basics).
5. Fill basics: title="شقة فاخرة في المالكي", purpose=sale, property_type=apartment. Continue.
6. Fill location: governorate=Damascus, city=Damascus, area=Al-Maliki, address_text="شارع المتنبي، بناء رقم 12". Continue.
7. **Verify (Q2)**: via Supabase MCP `execute_sql`:
   ```sql
   SELECT latitude, longitude FROM public.listings WHERE publisher_user_id='<this user id>' ORDER BY created_at DESC LIMIT 1;
   -- Expected: latitude≈33.5102, longitude≈36.2913 (centroid of Al-Maliki)
   ```
8. Fill details: description (optional), area_size=180, rooms=3, bathrooms=2, floor=4. Continue.
9. **Verify (Q3)**: the prices step has ONE currency picker + ONE amount field. NO "Add another currency" button.
10. Pick currency=USD, amount=50000. **Verify**: the inline `MoneyFormatter` preview reads `$50,000` (English locale) or `٥٠٬٠٠٠ $` (Arabic locale). Continue.
11. Fill visibility: location_visibility=approximate, contact_name_visibility=public, phone=0991234567 → auto-normalized to +963991234567. Continue.
12. **Verify**: the media-placeholder step shows the localized "media upload coming in the next release" banner. Continue.
13. On Review: verify all entered fields show. Tap Submit.
14. **Verify**: success toast appears; the form dismisses; the publisher dashboard re-renders with the listing under "Pending review" filter.

## Step 7 — Schema state after happy path

Via Supabase MCP `execute_sql`:

```sql
SELECT id, status FROM public.listings WHERE publisher_user_id='<this user id>' ORDER BY created_at DESC LIMIT 1;
-- Expected: status='pending_review'

SELECT count(*) FROM public.listing_prices WHERE listing_id='<that listing id>';
-- Expected: 1 (single-currency per Q3)

SELECT is_primary FROM public.listing_prices WHERE listing_id='<that listing id>';
-- Expected: true

SELECT count(*) FROM public.listing_details WHERE listing_id='<that listing id>';
-- Expected: 1 (1:1 row created via per-step save)

SELECT count(*) FROM public.listing_visibility WHERE listing_id='<that listing id>';
-- Expected: 1 (the sync trigger created this when location_visibility was set)

SELECT previous_status, new_status FROM public.listing_status_history
WHERE listing_id='<that listing id>' ORDER BY changed_at ASC;
-- Expected: 2 rows: (NULL, 'draft') and ('draft', 'pending_review')

SELECT action FROM public.audit_logs WHERE target_id='<that listing id>' ORDER BY created_at ASC;
-- Expected: at minimum: listing.created, listing.updated (one per per-step save), listing.updated + listing.submitted (on submit)
```

## Step 8 — Q1 validation deny test

1. On the device, start a new listing.
2. On the basics step, fill title only; leave purpose blank → form blocks Continue (client-side check).
3. Bypass the form via desktop: INSERT a draft directly via `execute_sql` with `auth.uid()` set, leaving `governorate_id` and `area_size` NULL.
4. Call `submit_listing('<this draft id>')` via `supabase.rpc(...)` (or via execute_sql with `SELECT public.submit_listing(...)`).
5. **Verify**: ERROR 22023 with DETAIL carrying `{ "missing_fields": ["listings.governorate_id","listings.city_id","listings.area_id","listings.address_text","listings.area_size","listings.phone_or_whatsapp","listing_prices.primary","listings.rooms","listings.bathrooms"] }`.

## Step 9 — Append-only listing_status_history

```sql
UPDATE public.listing_status_history SET previous_status='approved' WHERE id='<any row id>';
-- Expected: ERROR / 0 rows affected (no UPDATE policy)

DELETE FROM public.listing_status_history WHERE id='<any row id>';
-- Expected: ERROR / 0 rows affected (no DELETE policy)
```

## Step 10 — Rejected-resubmit loop (US3)

1. From the desktop with admin SQL access, simulate Phase 12's reject:
   ```sql
   UPDATE public.listings SET status='rejected' WHERE id='<this listing id>';
   INSERT INTO public.listing_status_history (listing_id, previous_status, new_status, changed_by, reason)
   VALUES ('<this listing id>', 'pending_review', 'rejected', NULL, 'الموقع غير دقيق');
   ```
   (In real Phase 12, the trigger writes the history row; this manual INSERT supplements with the rejection reason which Phase 12's RPC will populate. The Phase 10 trigger writes the row with `reason=NULL`.)
2. On the device, open the publisher dashboard → My Listings → Rejected filter.
3. **Verify**: the rejected card shows the rejection reason "الموقع غير دقيق" + a "Resubmit" CTA.
4. Tap "Resubmit". **Verify**: the multi-step form opens at step 1 pre-populated.
5. Tap through to Review, tap Submit.
6. **Verify**: the listing's status flips back to `pending_review`.
7. Query `listing_status_history`:
   ```sql
   SELECT previous_status, new_status, reason FROM public.listing_status_history
   WHERE listing_id='<id>' ORDER BY changed_at ASC;
   ```
   **Expected**: 4 rows showing the full chain (`NULL→draft`, `draft→pending_review`, `pending_review→rejected` with `reason='الموقع غير دقيق'`, `rejected→pending_review` with `reason=NULL`).

## Step 11 — Full status walk (audit emission)

From the desktop with admin SQL:

```sql
-- Simulate Phase 12 approve:
UPDATE public.listings SET status='approved', published_at=now() WHERE id='<id>';

-- Simulate publisher self-pause (forward-stated to a future spec — used here to exercise the audit chain):
UPDATE public.listings SET status='paused' WHERE id='<id>';

-- Verify history + audit counts
SELECT count(*) FROM public.listing_status_history WHERE listing_id='<id>';
-- Expected: 6 rows total over the lifecycle

SELECT action, count(*) FROM public.audit_logs WHERE target_id='<id::text>' GROUP BY action;
-- Expected:
--   listing.created     1
--   listing.updated     N (one per per-step save + one per status flip = many)
--   listing.submitted   2 (one per submit; first submit + resubmit)
--   listing.rejected    1
--   listing.approved    1
--   listing.paused      1
```

## Step 12 — Anonymous public-read of approved listing

Via Supabase MCP `execute_sql` AS `anon`:

```sql
SELECT id, title, status FROM public.listings WHERE status='approved';
-- Expected: at least 1 row (the listing we just approved)

SELECT count(*) FROM public.listing_prices lp
JOIN public.listings l ON lp.listing_id=l.id
WHERE l.status='approved';
-- Expected: matches the count of approved listings (anonymous SELECT on child tables works through parent gate)
```

## Step 13 — Single-currency invariant (SC-022)

```sql
SELECT listing_id, count(*) FROM public.listing_prices
GROUP BY listing_id HAVING count(*) <> 1;
-- Expected: 0 rows (every Phase-10-created listing has exactly one price row per Q3)

SELECT listing_id, count(*) FROM public.listing_prices WHERE is_primary=true
GROUP BY listing_id HAVING count(*) <> 1;
-- Expected: 0 rows (the partial unique index enforces exactly one primary)
```

## Step 14 — Mid-session publisher_status approval propagation (SC-020)

1. Sign in on the device as the `publisher_status='pending'` user.
2. Verify: no "Create listing" tile.
3. From the desktop with admin SQL, flip the user's status:
   ```sql
   UPDATE public.profiles SET publisher_status='approved' WHERE user_id='<that user id>';
   ```
4. On the device, foreground-resume the app (lock the screen, unlock; or background it via the Recents button and re-tap the icon).
5. **Verify**: the "Create listing" tile appears WITHOUT a sign-out (Phase 6 PermissionChecker cache-refresh invariant carried forward to the publisher-status helper).

---

## Validator manual goldens (FR-018)

Per [validators.md](contracts/validators.md), exercise each validator's golden inputs on the device by attempting to fill each field with the listed value and observing the displayed error string. All goldens documented in the contract file; ar AND en locales should each produce the locale-correct error.

## Per-FR / Per-SC verification map

See [data-model.md § Per-FR verification map](data-model.md) and [data-model.md § Per-SC verification map](data-model.md) for the full coverage matrix linking every FR / SC back to a step in this quickstart.

---

## Acceptance gate

All 14 steps pass + all validator goldens pass + zero `get_advisors` warnings = Phase 10 is verifiably complete.
