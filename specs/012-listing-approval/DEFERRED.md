# Phase 12 — Deferred Work

Tracks intentional gaps and human-gated verifications for the Phase 12
Listing Approval Workflow spec. Per `project_deferred_work.md`, an item here
means the spec is NOT fully shipped until either the item is closed or
explicitly downgraded to forward-state for a later phase.

## Human-Gated Verifications (Phase 2)

- [ ] **T012** — Smoke-verify Phase 10 `submit_listing` still attributes
      correctly under the amended trigger.

      A worktree agent cannot operate the emulator. Manual on Infinix Note 8:

      1. Sign in as a publisher on the Infinix Note 8 emulator.
      2. Submit a fresh draft via the existing Phase 10 listing form.
      3. Run via Supabase MCP `execute_sql`:
         ```sql
         SELECT changed_by
         FROM public.listing_status_history
         WHERE listing_id = '<new id>' AND new_status = 'pending_review';
         ```
      4. Expect a non-NULL UUID matching the publisher's `auth.users.id`.

      **Why this matters**: verifies the FR-024 amendment's
      `coalesce(...session var..., auth.uid())` fallback works for direct-JWT
      callers — `submit_listing` runs as the publisher under their own JWT
      with the session variable UNSET, so `auth.uid()` must populate
      `changed_by`. A NULL `changed_by` would indicate the COALESCE order is
      wrong or the auth.uid() resolution broke.

      **Blocks**: SC-030 (correct admin UID in `changed_by` + `actor_user_id`).
      Do not declare SC-030 closed until this verification is recorded.

## Human-Gated Verifications (Phase 3)

- [ ] **T019** — Smoke-test `approve_listing` happy path.

      The Phase 3 worktree agent deployed the Edge Function via Supabase MCP
      but cannot hand-craft an admin JWT. Manual verification:

      1. Obtain a valid admin JWT (sign in via the AlNujom app as a user
         holding `listings.approve`, then read the access token from the
         Supabase session — e.g. via the Flutter DevTools Network tab or
         `Supabase.instance.client.auth.currentSession?.accessToken`).
      2. Have a `pending_review` listing's UUID handy (create one via the
         Phase 10 publisher form on the Infinix Note 8 if needed).
      3. Run:
         ```bash
         curl -X POST "$SUPABASE_URL/functions/v1/approve_listing" \
              -H "Authorization: Bearer <admin JWT>" \
              -H "Content-Type: application/json" \
              -d '{"listing_id":"<the pending_review listing id>"}'
         ```
      4. Expect HTTP 200 with body
         `{"status":"approved","published_at":"<ISO>","expires_at":null}`.
      5. Retrieve the Edge Function logs via Supabase MCP
         `get_logs(service="edge-function")` and capture the
         `duration_ms` for the SC-029 latency baseline (target: ≤ 2000ms p95
         across ≥ 10 invocations).

      **Blocks**: SC-029 baseline (formal p95 latency probe runs in Phase 9
      / T101 once the UI path has produced ≥ 10 real invocations).

- [ ] **T044** — Manual UI verification of the US1 approve flow.

      The agent cannot operate the Pixel 8 Pro emulator or hold an admin
      session. Manual recipe on Pixel 8 Pro emulator:

      **Pre-flight**: grep `lib/core/routing/app_router.dart` for Phase 10's
      existing publisher-edit route path; confirm it is
      `/publisher/listings/:id/edit` (matches the value Phase 4's T058
      Resubmit button will deep-link to). If the actual route differs,
      update T058's `context.push(...)` AND the moderation-history contract's
      deep-link string before proceeding.

      **Verification** (`flutter run -d <pixel 8 pro emulator>
      --dart-define-from-file=.env.json` per `project_dart_defines.md`):

      1. Sign in as an admin holding `listings.approve`.
      2. From the home screen, navigate to Admin → confirm the new
         "Pending review" tile renders (gated by `listings.approve` OR
         `listings.reject` per T041).
      3. Tap the Pending review tile → confirm the queue page loads ≥ 1
         pending listing oldest-first.
      4. Tap a card → confirm the preview renders gallery + price +
         location + amenities + description at full fidelity.
      5. Tap Approve → confirm the dialog appears → tap Approve.
      6. Confirm the success snackbar shows and the page pops back to the
         queue.
      7. Confirm the approved listing no longer appears in the queue (the
         status guard removed it from the `pending_review` set).
      8. From an anonymous Supabase client (e.g. `curl` with the anon key,
         no `Authorization` header), confirm
         `GET /rest/v1/listings?id=eq.<that id>&select=status,published_at,expires_at`
         returns one row with `status="approved"`, `published_at` non-null,
         `expires_at=null` (SC-002 + SC-023).

      **Closes**: SC-001 (2-min admin journey timing), SC-003 (approve
      writes correct rows — paired with T070 SQL check), SC-009 (media
      anonymous-readable on approve — paired with T067), SC-011 (preview
      full-fidelity), SC-026 partial (route guard — paired with T103).

## Human-Gated Verifications (Phase 4)

- [ ] **T047** — Smoke-test `reject_listing` happy path.

      The Phase 4 worktree agent deployed the Edge Function via Supabase MCP
      (version 1, ACTIVE, verify_jwt=true) but cannot hand-craft an admin JWT
      (same reason as T019). Manual verification:

      1. Obtain a valid admin JWT (sign in via the AlNujom app as a user
         holding `listings.reject`, then read the access token from the
         Supabase session — e.g. via the Flutter DevTools Network tab or
         `Supabase.instance.client.auth.currentSession?.accessToken`).
      2. Have a `pending_review` listing's UUID handy.
      3. Run:
         ```bash
         curl -X POST "$SUPABASE_URL/functions/v1/reject_listing" \
              -H "Authorization: Bearer <admin JWT>" \
              -H "Content-Type: application/json" \
              -d '{"listing_id":"<the pending_review listing id>",
                   "reason_preset":"missing_or_low_quality_photos",
                   "reason_detail":"The main photo appears to be a stock image."}'
         ```
      4. Expect HTTP 200 with body
         `{"status":"rejected","reason_preset":"missing_or_low_quality_photos","reason_detail":"The main photo appears to be a stock image."}`.
      5. Verify Q4=A JSON shape via Supabase MCP `execute_sql`:
         ```sql
         SELECT
           reason,
           (reason::jsonb)->>'preset' AS preset,
           (reason::jsonb)->>'detail' AS detail
         FROM public.listing_status_history
         WHERE listing_id = '<id>'
           AND new_status = 'rejected'
         ORDER BY changed_at DESC
         LIMIT 1;
         ```
         Expect `preset='missing_or_low_quality_photos'` AND `detail='The main photo...'`.

      **Blocks**: SC-029 reject-side latency baseline.

- [ ] **T062** — Manual UI verification of the US2 reject + publisher banner flow.

      The agent cannot operate the Pixel 8 Pro emulator or the Infinix Note 8.
      Manual recipe on Pixel 8 Pro emulator (admin) + Infinix Note 8 (publisher):

      **Admin side (Pixel 8 Pro emulator)** via
      `flutter run -d <pixel 8 pro emulator> --dart-define-from-file=.env.json`:

      1. Sign in as an admin holding `listings.reject`.
      2. Open the Pending review queue (Phase 3 page) → tap a pending listing.
      3. Tap Reject → confirm the dialog renders with:
         - 6 localized preset radio options (in enum order from
           `RejectionReason`).
         - A multi-line text field with `0/500` counter.
         - Confirm button DISABLED initially.
      4. Select one of the first 5 presets → confirm Confirm becomes ENABLED.
      5. Type into the detail field → confirm counter updates (e.g., `12/500`).
      6. Tap the "Other" radio → confirm:
         - Field label flips from "Additional details (optional)" to
           "Additional details (required)".
         - Hint appears above the field.
         - Confirm becomes DISABLED until non-empty detail is typed.
      7. Type some detail under Other → confirm Confirm enables.
      8. Switch back to a non-Other preset → confirm Confirm stays enabled.
      9. Tap Confirm → confirm:
         - Success snackbar appears ("Listing rejected").
         - Page pops back to queue.
         - Rejected listing no longer appears in the pending queue.
      10. Verify SQL via Supabase MCP `execute_sql`:
          `SELECT (reason::jsonb)->>'preset' AS preset, (reason::jsonb)->>'detail' AS detail FROM public.listing_status_history WHERE listing_id='<id>' AND new_status='rejected' ORDER BY changed_at DESC LIMIT 1;`
          Expect the chosen preset key + detail text.

      **Publisher side (Infinix Note 8)**:

      11. Sign in on the Infinix Note 8 as the publisher who created the
          rejected listing above.
      12. Open My Listings → tap the Rejected filter chip.
      13. Confirm the rejection banner renders above the rejected card with:
          - "Reviewed by admin team • {time-ago}" attribution (NEVER the
            admin's actual name).
          - Localized preset label (matches the admin's selection).
          - Detail text in a quoted block.
          - Resubmit button.
          - "View moderation history" text button.
      14. Tap Resubmit → confirm Phase 10 listing-edit form opens at
          `/publisher/listings/<id>/edit` pre-populated.
      15. Switch the device locale to AR → return to My Listings →
          confirm banner renders in Arabic with the same preset label/detail.
      16. Tap "View moderation history" — Phase 8 has not yet shipped the page;
          the route will dead-end with a 404/blank (expected, Phase 8 T087 wires it).

      **Closes**: SC-004 (reject writes correct rows — paired with T072/T073),
      SC-012 (reject dialog), SC-013 (publisher banner),
      SC-027 (Q4=A JSON shape persisted), SC-028 UX side (Other-required gate).

## Verification Results (Phase 5 — US3 RLS)

Executed 2026-05-23 via Supabase MCP `execute_sql` against project `hczsgceagommznjaohyk`.

### Seed Dataset (T063)

| ID | Status |
|---|---|
| `5a58a9e8-09a9-4ab5-ae32-b63eddd2d0d7` | approved (pre-existing) |
| `4ec51a27-153b-49ca-b128-2f2df1db18f6` | draft (pre-existing) |
| `aaaaaaaa-0001-0001-0001-000000000001` | pending_review (seeded) |
| `aaaaaaaa-0001-0001-0001-000000000002` | rejected (seeded) |
| `aaaaaaaa-0001-0001-0001-000000000003` | paused (seeded) |
| `aaaaaaaa-0001-0001-0001-000000000004` | sold (seeded) |
| `aaaaaaaa-0001-0001-0001-000000000005` | rented (seeded) |
| `aaaaaaaa-0001-0001-0001-000000000006` | expired (seeded) |
| `aaaaaaaa-0001-0001-0001-000000000007` | deleted (seeded) |

All 9 statuses seeded via direct INSERT as postgres role (bypasses RLS).
Publisher for all rows: `6583a883-123c-4c62-a1ad-00e11b124c8b`.

### Results Table

| Task | Query | Expected | Actual | Status |
|---|---|---|---|---|
| T063 | Seed 9 listings (1 per status) via direct INSERT | 9 rows, one per status | 9 rows confirmed via `SELECT id, status FROM public.listings ORDER BY status` | PASS |
| T064 | Anonymous SELECT all 9 IDs (`SET LOCAL ROLE anon`) | 1 row — the `approved` one | `[{"id":"5a58a9e8...","status":"approved"}]` — exactly 1 row | PASS |
| T065 (owner) | Publisher (`6583a883`) SELECT via `SET LOCAL ROLE authenticated` + JWT claims | All 9 own listings visible | All 9 rows returned — owner policy grants access to all own rows | PASS |
| T065 (non-owner) | Non-owner user (`11111111`, role=`user`) SELECT same 9 IDs | Only `approved` row visible | Only `approved` row returned — 1 row | PASS |
| T066 | Admin user (`33333333`, role=`admin`, has `listings.view_all`) SELECT same 9 IDs | All 9 statuses visible | All 9 rows returned | PASS |
| T067 (policy) | Storage RLS policy `listing_images_anon_select_when_approved` predicate evaluated | `true` for approved listing, `false` for non-approved | `anon_would_see_approved_listing_media=true`, `anon_would_see_paused_listing_media=false` | PASS |
| T067 (HTTP) | Anonymous HTTP GET public URL for media object | HTTP 200 + image bytes | Deferred to human — no real bucket object exists (synthetic listing_media row only) | HUMAN-GATED |
| T068 (revert) | Flip approved to paused; anon SELECT + storage predicate | 0 rows; predicate=false | 0 rows from anon SELECT; `anon_would_see_paused_listing_media=false` | PASS |
| T068 (restore) | Flip paused back to approved; anon SELECT + storage predicate | 1 row; predicate=true | 1 row returned; `anon_would_see_restored_listing_media=true` | PASS |
| T069 (expired) | Set `expires_at = now() - 1h`; anon SELECT | 0 rows | 0 rows returned | PASS |
| T069 (reset) | Reset `expires_at = NULL`; Q2=A invariant restored | `expires_at=NULL`, `status='approved'` | `expires_at=null`, `status='approved'` confirmed | PASS |

### Human Follow-Up Required (Phase 5)

- [ ] **T067-HTTP** — Real anonymous HTTP GET against the storage bucket to confirm HTTP 200 + image bytes.

  No actual bucket object was uploaded during Phase 12 verification. The `listing_media` row inserted during T067 is synthetic (`storage_path='5a58a9e8-09a9-4ab5-ae32-b63eddd2d0d7/main.jpg'`) but no real byte payload exists in the `listing-images` bucket.

  The RLS policy predicate (`listing_images_anon_select_when_approved`) was verified to evaluate correctly via SQL simulation. The real HTTP test requires a listing whose media was uploaded via the Phase 10/11 publisher flow.

  **Reproduction recipe** (run after a real publisher upload + Phase 12 UI approval):
  ```bash
  # Replace <storage_path> with the actual storage_path from public.listing_media
  # for a listing in status='approved'
  curl -s "https://hczsgceagommznjaohyk.supabase.co/storage/v1/object/public/listing-images/<storage_path>" \
       -o /dev/null -w "%{http_code}"
  # Expected: 200

  # After flipping the listing to status='paused' via SQL or admin UI:
  curl -s "https://hczsgceagommznjaohyk.supabase.co/storage/v1/object/public/listing-images/<storage_path>" \
       -o /dev/null -w "%{http_code}"
  # Expected: 403 (bucket object inaccessible to anon after status revert)
  ```

  **Blocks**: SC-009 (anonymous-readable media on approve) full end-to-end closure.
  SC-008 HTTP side (storage 403 on status revert). The SQL-predicate simulation confirms policy correctness; this test confirms the Supabase Storage HTTP gateway honours the RLS at request time.

### RLS Policy Inventory Verified

| Policy | Predicate summary | Verified via |
|---|---|---|
| `listings_select_public` | `status='approved' AND (published_at IS NULL OR published_at<=now()) AND (expires_at IS NULL OR expires_at>now())` | T064, T068, T069 |
| `listings_select_owner` | `auth.uid() = publisher_user_id` | T065 (owner sees all 9 own listings) |
| `listings_select_admin` | `current_user_has_permission('listings.view_all')` | T066 (admin sees all 9 statuses) |
| `listing_images_anon_select_when_approved` | `bucket_id='listing-images' AND EXISTS (listing where id=split_part(name,'/',1) AND status='approved' AND window open)` | T067 SQL predicate; T068 revert/restore |

## Plan-Time Deferrals

### D-12-01 — Fullscreen viewer affordance on ListingGallery

Phase 12 ships a horizontal carousel only. Pinch-to-zoom and a fullscreen overlay for media are deferred to Phase 13's listing-details enhancement. The `ListingGallery` widget's public API is forward-compatible — Phase 13 can wrap or extend it without breakage.

### D-12-02 — Listing price display currency choice on admin preview

Phase 12 displays the publisher's stored currency. Admin-side currency conversion (showing the price in the admin's preferred display currency) is deferred. The `ListingPriceBlock` widget accepts a `displayCurrency` parameter; Phase 12 always passes the publisher's stored currency.

### D-12-03 — Audit-log detail surface on the moderation history page

The publisher-facing moderation history page shows `preset` + `detail` only (from `listing_status_history.reason`). The full `audit_logs` JSONB surface (`before_state`, `after_state`, `ip`, `user_agent`) is deferred to a future super-admin spec. All data is captured in `audit_logs`; only the surface is not exposed in Phase 12.

---

## Human-Gated Verifications (Phase 7)

All six tasks below require a running Pixel 8 Pro emulator (admin device). A worktree agent cannot operate an emulator. Seed data is ready: 26 `pending_review` listings exist in the remote DB (25 seeded by T078 + 1 pre-existing), with `created_at` values staggered 1 hour apart going back from 2026-05-23T18:57 UTC.

**Seed listing IDs (T078 — inserted 2026-05-23, staggered created_at hourly):**

| # | Listing ID | created_at (UTC) |
|---|-----------|-----------------|
| 1 | f2337123-00a1-4ea0-8fef-28c17a5584bc | 2026-05-23 17:57:44 |
| 2 | e141dd54-9731-41f2-8f9c-5fefba908e56 | 2026-05-23 16:57:44 |
| 3 | efea80bf-1b08-45ef-aa87-e943e836052f | 2026-05-23 15:57:44 |
| 4 | fdcae444-2644-411f-a56d-331aa65c444d | 2026-05-23 14:57:44 |
| 5 | b6d4a374-8326-49e1-a338-1ee47e2fc4b2 | 2026-05-23 13:57:44 |
| 6 | 7a312441-ccd6-400d-9776-66aaf4f8c124 | 2026-05-23 12:57:44 |
| 7 | f8d75112-410f-414d-b5c0-52768892c876 | 2026-05-23 11:57:44 |
| 8 | d9d91557-8289-4fdc-8054-60133670e29a | 2026-05-23 10:57:44 |
| 9 | cb1a8ff5-1709-4177-910e-d3162effd377 | 2026-05-23 09:57:44 |
| 10 | 643e185c-40fc-47d5-acb3-b842e49bfaf5 | 2026-05-23 08:57:44 |
| 11 | 4ae76332-46b5-466e-bcf4-d78be6aa7427 | 2026-05-23 07:57:44 |
| 12 | 7f6aee9b-5073-4cf4-83fd-afbc6b2d208f | 2026-05-23 06:57:44 |
| 13 | 6516e21c-6bcf-4d7a-9984-e20eef91a49a | 2026-05-23 05:57:44 |
| 14 | c14c0644-c735-4ab5-9bff-a20794d6c494 | 2026-05-23 04:57:44 |
| 15 | e2c3e7e2-bf2b-47bf-ae37-0abae98653bc | 2026-05-23 03:57:44 |
| 16 | 87a2b28a-4c37-490e-b9f9-f4c08a586361 | 2026-05-23 02:57:44 |
| 17 | ea01ff25-ee39-4ed9-b51a-e67645944f05 | 2026-05-23 01:57:44 |
| 18 | f683741e-247a-423e-9186-02f50b1cec47 | 2026-05-23 00:57:44 |
| 19 | dbee972e-048c-435f-b7bd-385c5b2e26eb | 2026-05-22 23:57:44 |
| 20 | 20d80a0d-749a-4463-b668-9f01b23dd44a | 2026-05-22 22:57:44 |
| 21 | 5dd49c98-dc80-4b5f-b321-195c0a4ec277 | 2026-05-22 21:57:44 |
| 22 | 7d7c5da6-a329-4960-b5d3-ce68abfe5c93 | 2026-05-22 20:57:44 |
| 23 | 2545b417-ed3c-45a1-b4db-3bc2604b5a25 | 2026-05-22 19:57:44 |
| 24 | 727326d1-9bbf-46d9-8a8f-0daafbeda869 | 2026-05-22 18:57:44 |
| 25 | ce1c32c8-e817-46c1-97f4-b33164021247 | 2026-05-22 17:57:44 |

Note: All 25 rows were seeded with `publisher_user_id=11111111-1111-1111-1111-111111111111`. No `listing_details`, `listing_prices`, or `listing_media` child rows exist for these seed listings — the queue card thumbnail will show the Phase 2 placeholder for all of them, which intentionally covers T083.

**Oldest-first ordering expected by the queue for page 1:** The 20 oldest seed rows (2026-05-22 17:57 through 2026-05-23 12:57) should appear on page 1. The 5 newest (2026-05-23 13:57 through 2026-05-23 17:57) load on page 2 scroll.

**Verify seed intact before T079:**
```sql
SELECT count(*) FROM public.listings WHERE status='pending_review';
-- expect >= 26
```

---

- [ ] **T079** — First-page load verification (SC-010).

      A worktree agent cannot operate the Pixel 8 Pro emulator. Manual on Pixel 8 Pro emulator:

      1. `flutter run -d <pixel 8 pro emulator> --dart-define-from-file=.env.json`
      2. Sign in as admin. Navigate to Admin → Pending review.
      3. Confirm exactly 20 cards render on first load.
      4. Run via Supabase MCP to confirm expected order:
         ```sql
         SELECT id FROM public.listings
         WHERE status='pending_review'
         ORDER BY created_at ASC, id ASC
         LIMIT 20;
         ```
      5. Compare the returned IDs top-to-bottom against the rendered cards.
      6. Confirm no crash, no stuck loading spinner.

      **Closes**: SC-010 (oldest-first ordering + page size = 20).

- [ ] **T080** — Infinite-scroll verification.

      A worktree agent cannot operate the Pixel 8 Pro emulator. Manual on Pixel 8 Pro emulator (continuation from T079):

      1. With queue showing 20 cards, scroll to the bottom.
      2. Confirm a loading indicator appears briefly.
      3. Confirm the remaining cards (page 2) load and append.
      4. Confirm the order continues chronologically from page 1's last card — no gap, no duplicate, no reorder.
      5. The cursor passed to page 2 is `created_at` + `id` of the last page-1 card per `contracts/phase12-admin-queue-page.md` C8.

      **Closes**: SC-010 cursor pagination correctness.

- [ ] **T081** — Pull-to-refresh verification.

      A worktree agent cannot operate the Pixel 8 Pro emulator. Manual on Pixel 8 Pro emulator:

      1. With the queue loaded, pull down from the top.
      2. Confirm the `RefreshIndicator` spinner appears.
      3. Confirm the queue re-fetches from the first cursor (oldest 20).
      4. Confirm the list resets to page 1 — page-2 cards discarded.
      5. No crash; list consistent with live DB state.

      **Closes**: SC-010 pull-to-refresh.

- [ ] **T082** — On-pop refresh verification.

      A worktree agent cannot operate the Pixel 8 Pro emulator. Manual on Pixel 8 Pro emulator:

      1. From the queue page, tap a seed listing to open its preview.
      2. Tap Approve (requires `approve_listing` Edge Function deployed + listing still `pending_review`).
      3. After the success toast, the page pops back to the queue.
      4. Confirm the approved listing no longer appears without manual pull-to-refresh.
      5. No crash, no stale data.

      **Closes**: SC-010 on-pop refresh.

- [ ] **T083** — Missing-main-image placeholder verification.

      A worktree agent cannot operate the Pixel 8 Pro emulator. Manual on Pixel 8 Pro emulator:

      The 25 T078 seed listings have NO `listing_media` rows — every seed card hits the no-main-image placeholder path.

      1. Load the queue page and observe the seed listing cards.
      2. Each card must show a Phase 2 placeholder thumbnail — NOT a broken-image icon, NOT a network error, NOT a crash.
      3. Confirm visual consistency with the Phase 2 design token for empty-image states.
      4. To restore a real main-image row after the test (optional):
         ```sql
         INSERT INTO public.listing_media (listing_id, storage_path, kind, is_main, ordering)
         VALUES ('<seed-id>', 'test/placeholder.jpg', 'image', true, 0);
         ```

      **Closes**: SC-010 missing-main-image placeholder rendering.

## Human-Gated Verifications (Phase 8)

- [ ] **T090** — Reject-resubmit-reject chain on a single listing (SC-020).
  Manual recipe on Pixel 8 Pro emulator (admin) + Infinix Note 8 (publisher):
  1. Identify a pending_review listing.
  2. As admin: open preview → Reject with preset=missing_or_low_quality_photos, detail="First reject".
  3. As publisher: My Listings → Rejected → tap Resubmit → makes a trivial edit → submit again.
  4. As admin: re-open the now-pending listing → Reject with preset=other, detail="Second reject reason".
  5. As publisher: tap "View moderation history" on the banner.
  6. Confirm exactly 4 chronological entries: created → pending_review (submit) → rejected (1st preset+detail) → pending_review (resubmit) → rejected (2nd preset+detail).
  7. Both rejection entries show preset label + detail.
  8. Admin identity NEVER displayed (only "Admin team").
  9. Run via MCP: `SELECT count(*) FROM public.audit_logs WHERE target_id='<id>' AND action='listing.rejected'` — expect exactly 2.
  Closes: SC-020 reject-resubmit-reject chain audit completeness.

- [ ] **T091** — Approve-revert-approve chain on a single listing (SC-021).
  Manual recipe on Pixel 8 Pro emulator (admin):
  1. Identify a pending_review listing.
  2. As admin: open preview → Approve via UI. Note the `published_at` timestamp.
  3. Via Supabase MCP `execute_sql`: `UPDATE public.listings SET status='paused' WHERE id='<id>'` (simulates future-spec moderation revert).
  4. Resubmit/re-queue the listing as publisher (My Listings → tap resubmit or direct SQL `UPDATE ... SET status='pending_review'`).
  5. As admin: re-open the now-pending listing → Approve via UI again.
  6. Run via MCP: `SELECT count(*) FROM public.audit_logs WHERE target_id='<id>' AND action='listing.approved'` — expect exactly 2.
  7. Confirm both audit rows have `published_at` non-NULL AND the second's `published_at` is later than the first's.
  8. Open the publisher moderation history page — confirm the approve entries appear chronologically.
  Closes: SC-021 approve-revert-approve chain audit completeness.

---

- [ ] **T084** — Scroll-position retention verification.

      A worktree agent cannot operate the Pixel 8 Pro emulator. Manual on Pixel 8 Pro emulator:

      1. With queue loaded (at least 20 cards), scroll down ~10 cards.
      2. Tap a listing card to open its preview.
      3. Tap back (without approving/rejecting) to return to the queue.
      4. Confirm the queue retains its scroll position — NOT snapped back to top.
      5. No crash, no flicker, no list reset.

      **Closes**: SC-010 scroll-position retention.
