# Phase 13 — Quickstart Verification

**Purpose**: Manual verification checklist for Phase 13. Run after `/speckit-implement` completes. Covers all 35 SCs.

**Setup**:

- Supabase MCP server connected.
- Two devices: Infinix Note 8 (primary anonymous-browse) + Pixel 8 Pro emulator (secondary newer-Android edge cases).
- App built with `flutter build apk --debug --dart-define-from-file=.env.json` (per user memory `project_dart_defines.md`).
- App installed on both devices.
- Phase 12 prior session has produced ≥ 25 `status='approved'` listings in the database (else seed via direct SQL bypassing Edge Functions for test setup).

---

## Step 0 — Pre-flight

### 0.1 Confirm Phase 13 migration is unapplied

```sql
-- Via Supabase MCP execute_sql:
SELECT name FROM supabase_migrations.schema_migrations WHERE name LIKE '%listings_indexes%';
-- Expected: 0 rows. (If 1 row, the migration has already been applied; skip step 1.)
```

### 0.2 Confirm Phase 12 produced approved listings

```sql
SELECT COUNT(*) FROM public.listings WHERE status='approved';
-- Expected: ≥ 25. (If fewer, seed via direct SQL OR run Phase 12's quickstart to create more.)
```

### 0.3 Confirm `lib/shell/` still exists (pre-deletion baseline)

```bash
ls H:/alnujom-project/lib/shell/
# Expected: shell_home_page.dart (Phase 1's file, to be deleted by Sub-Phase F).
```

---

## Step 1 — Apply the index migration (Sub-Phase A)

```
Supabase MCP apply_migration:
  name: create_listings_indexes
  query: <body of 20260524120001_create_listings_indexes.sql>
```

**Verify**:

```sql
SELECT indexname FROM pg_indexes
WHERE tablename='listings' AND indexname LIKE 'idx_listings_%'
ORDER BY indexname;
-- Expected output:
-- idx_listings_governorate_status
-- idx_listings_property_type_status
-- idx_listings_status_created_at
-- idx_listings_status_published_at
```

**SC-009 EXPLAIN check** (FR-002):

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM public.listings
WHERE status='approved'
ORDER BY published_at DESC, id DESC
LIMIT 20;
-- Expected: plan contains "Index Scan using idx_listings_status_published_at"
--           AND total execution time < 100 ms at v1 row counts (< 1000 approved listings).
```

**Pass criteria**: SC-009 ✓.

---

## Step 2 — Confirm Phase 13 grep gates (FR-003 / FR-004 / FR-006 / FR-007 / FR-008 / SC-017 / SC-018 / SC-019 / SC-020 / SC-021)

```bash
# FR-003 + SC-018 — no RLS policy edits:
grep -E "CREATE POLICY|ALTER POLICY|DROP POLICY" supabase/migrations/20260524120001_create_listings_indexes.sql
# Expected: 0 matches.

# FR-004 + SC-019 — no schema edits on listings-domain tables:
grep -E "ALTER TABLE|CREATE TABLE|DROP TABLE" supabase/migrations/20260524120001_create_listings_indexes.sql
# Expected: 0 matches.

# FR-005 + SC-020 — no new Edge Functions:
ls supabase/functions/
# Expected: 4 dirs exactly — lookup_email_by_phone, request_password_reset (Phase 5),
#           approve_listing, reject_listing (Phase 12). NO Phase 13 dir.

# FR-006 + SC-017 — no new permission keys:
grep -E "INSERT INTO public.permissions" supabase/migrations/20260524120001_create_listings_indexes.sql
# Expected: 0 matches.

# FR-007 + SC-021 — no new log_audit() call sites:
grep -R "log_audit" supabase/migrations/20260524120001_create_listings_indexes.sql supabase/functions/
# Expected: 0 NEW matches beyond Phase 12.
```

**Pass criteria**: SC-017, SC-018, SC-019, SC-020, SC-021 ✓.

---

## Step 3 — Confirm pubspec + AndroidManifest (Sub-Phase B)

```bash
grep "url_launcher:" pubspec.yaml
# Expected: 1 match (e.g., "url_launcher: ^6.x.y").

grep "share_plus" pubspec.yaml
# Expected: 0 matches (per FR-033).

grep -A 5 "<queries>" android/app/src/main/AndroidManifest.xml
# Expected: <queries> element containing the https: scheme entry.
```

---

## Step 4 — Confirm ARB delta (Sub-Phase C / FR-028 / SC-014)

```bash
grep -E "home_search_coming_soon|home_property_shortcut_coming_soon" lib/l10n/app_ar.arb lib/l10n/app_en.arb
# Expected: 2 entries in each file.

grep -E "contact_call_coming_soon|contact_whatsapp_coming_soon|contact_inquiry_coming_soon|action_favorite_coming_soon|action_share_coming_soon|action_report_coming_soon" lib/l10n/app_ar.arb lib/l10n/app_en.arb
# Expected: 6 entries in each file.

grep -E "auth_required_please_sign_in|auth_required_sign_in_action" lib/l10n/app_ar.arb lib/l10n/app_en.arb
# Expected: 2 entries in each file (Q3=A reserved keys).

grep -E "listing_details_not_found_title|listing_details_not_found_return_home" lib/l10n/app_ar.arb lib/l10n/app_en.arb
# Expected: 2 entries in each file.
```

**Pass criteria**: SC-031 ✓ (Q3=A keys present), partial SC-014.

---

## Step 5 — Confirm Constitution-IX / VI / V grep gates (Sub-Phases D + E / SC-013 / SC-014 / SC-015)

```bash
# SC-013 — Supabase isolation:
grep -R "package:supabase_flutter" lib/features/home/presentation/ lib/features/home/domain/ lib/features/listing_details/presentation/ lib/features/listing_details/domain/
# Expected: 0 matches.

# SC-015 — design tokens:
grep -RE "Color\(0xFF" lib/features/home/presentation/ lib/features/listing_details/presentation/
grep -RE "EdgeInsets\.only\(left" lib/features/home/presentation/ lib/features/listing_details/presentation/
# Expected: 0 matches each.

# SC-014 — hardcoded strings:
grep -RE "Text\('[^\$]" lib/features/home/presentation/ lib/features/listing_details/presentation/
# Expected: 0 matches outside legitimate placeholder text.

# FR-018 + SC-008 — RLS-only filter discipline:
grep -RE "\.eq\('status'" lib/features/home/data/ lib/features/listing_details/data/
# Expected: 0 matches.

# SC-016 — Phase 12 Q8=A widget reuse:
git diff main -- lib/shared/presentation/widgets/listing_display/
# Expected: 0 file changes (zero edits to Phase 12's widgets).
```

**Pass criteria**: SC-013, SC-014, SC-015, SC-008, SC-016 ✓.

---

## Step 6 — Confirm router + shell deletion (Sub-Phase F / SC-010 / SC-011 / SC-012 / SC-032)

```bash
ls H:/alnujom-project/lib/shell/ 2>&1
# Expected: error "No such file or directory" (per FR-009 + SC-010).

grep "HomePage()" lib/core/routing/app_router.dart
# Expected: at least 1 match (in the / route builder).

grep "/listings/:id" lib/core/routing/app_router.dart
# Expected: at least 1 match (the new deep-link route).
```

**Pass criteria**: SC-010, SC-011, SC-012, SC-032 ✓.

---

## Step 7 — HomePage cold launch on Infinix Note 8 (SC-001 / SC-025 / SC-026)

1. Wipe Supabase session on Infinix Note 8 via "Clear data" in app settings.
2. Launch the app from cold via the launcher icon.
3. Start a stopwatch at tap.
4. Observe HomePage rendering: AppBar + hero search + 8 property-type chips + "Latest listings" header + first 20 cards (text + image placeholders, then images filling in).
5. Stop the stopwatch when text+placeholders render.

**Expected**: ≤ 3 sec. SC-001 ✓.

**Confirm anonymous browsing has no auth wall** (SC-025): scroll through 20 cards; no "please sign in" prompt.

**Confirm signed-in publisher's draft/pending/rejected absent** (SC-026): sign in as a publisher with at least one listing in each non-approved status; reload HomePage; confirm none of those listings appear in the feed.

---

## Step 8 — Q1=A stub snackbars (SC-029)

1. On HomePage, tap the hero search bar.
   - **Expected**: localized `home_search_coming_soon` snackbar; NO navigation.
2. Tap each of the 8 property-type chips.
   - **Expected**: localized `home_property_shortcut_coming_soon` snackbar embedding the type label (e.g., "Apartment listings filter is coming soon"); NO navigation.
3. Repeat in `ar` AND `en`.
4. `grep -RE "context\.(go|push)\(" lib/features/home/presentation/widgets/hero_search_bar.dart lib/features/home/presentation/widgets/property_type_shortcut_row.dart` → expected 0 matches.

**Pass criteria**: SC-029 ✓.

---

## Step 9 — Infinite-scroll pagination (SC-002 / SC-022 / SC-034)

1. Scroll to the bottom of the visible cards on HomePage.
2. Start a stopwatch when the bottom card crosses the viewport.
3. Observe next-page load.
4. Stop the stopwatch when new cards' text appears.
5. Repeat 10 times across the loaded feed.

**Expected**: each interaction ≤ 2 sec; p95 ≤ 2 sec across the 10 samples. SC-034 (infinite-scroll path) ✓.

Also: scroll through all 50 seeded listings continuously; confirm zero duplicates AND zero skipped rows. SC-002 + SC-022 ✓.

---

## Step 10 — Pull-to-refresh (SC-003 / SC-023 / SC-034)

1. Scroll back to top of HomePage.
2. Start a stopwatch.
3. Pull down on the feed.
4. Stop the stopwatch when the first 20 cards re-render.
5. Repeat 10 times.

**Expected**: each ≤ 2 sec; p95 ≤ 2 sec. SC-034 (pull-to-refresh path) ✓.

Now the two-device test:

1. On Infinix Note 8: scroll past page 1 of the home feed (cursor advanced).
2. On Pixel 8 Pro emulator: sign in as admin, approve a new listing via Phase 12's queue → listing's `published_at = now()` is LATER than every card on the Infinix.
3. On Infinix: scroll further into pagination. **Expected**: the new listing does NOT appear (SC-023 ✓).
4. On Infinix: pull-to-refresh. **Expected**: the new listing appears at position 0 (SC-003 ✓).

---

## Step 11 — Card tap → ListingDetailsPage (SC-004)

1. Tap any home-feed card.
2. Start a stopwatch at tap.
3. Stop when text content (title + price + location) renders on details page.

**Expected**: ≤ 1 sec. SC-004 ✓.

Confirm composition order per FR-021:

1. AppBar (back arrow only — NO share icon).
2. `ListingGallery` carousel.
3. Title.
4. `ListingPriceBlock`.
5. `ListingLocationBlock`.
6. `_ContactBlock` (3 CTAs).
7. `ListingAmenitiesBlock`.
8. `ListingDescriptionBlock`.
9. `_PerListingActionBlock` (3 CTAs).

---

## Step 12 — Gallery swipe + video tap (SC-005 / SC-027)

1. On `ListingDetailsPage` with ≥ 2 media items, swipe left-right on the gallery → confirm carousel advances.
2. If the listing has a video media item, tap the video → confirm OS external player launches (VLC OR Chrome on Infinix Note 8; Chrome on Pixel 8 Pro emulator).
3. Verify Phase 11 FR-022 zero-image defensive case (if any test listing has 0 images): gallery shows localized "no media available" placeholder.

**Pass criteria**: SC-005, SC-027 ✓.

---

## Step 13 — Q2=A stub snackbars (SC-030)

For each of the 6 CTAs on `ListingDetailsPage` (Call / WhatsApp / Send inquiry / Favorite / Share / Report):

1. Tap the CTA.
2. Confirm the corresponding localized Coming-soon snackbar appears.
3. Confirm NO functional behavior: no phone-app launch, no WhatsApp launch, no OS share sheet, no Supabase write to `favorites` / `inquiries` / `reports`.
4. Repeat in `ar` AND `en`.

Then grep:

```bash
grep -RE "url_launcher\.launch.*tel:" lib/features/listing_details/presentation/
grep -RE "url_launcher\.launch.*wa\.me|url_launcher\.launch.*api\.whatsapp" lib/features/listing_details/presentation/
grep -R "share_plus" pubspec.yaml
grep -RE "from\('favorites'\)|from\('inquiries'\)|from\('reports'\)" lib/features/listing_details/
# Expected: 0 matches each.
```

**Pass criteria**: SC-030 ✓.

---

## Step 14 — Q4=D back-button deep-link (SC-033)

### In-app navigation case

1. Launch app to HomePage, tap any listing card, observe details page.
2. Tap AppBar back arrow → confirm return to HomePage at prior scroll position.
3. Repeat with Android system back gesture (swipe from edge OR hardware button).

### Deep-link entry case

1. Kill the app via app switcher.
2. From a desktop terminal (with `adb` configured + device connected):
   ```bash
   adb shell am start -a android.intent.action.VIEW \
     -d "alnujom://listings/<a-real-approved-uuid>" \
     com.alnujom.app
   ```
   (Replace `alnujom://` scheme + `com.alnujom.app` package per the actual manifest. If no custom URL scheme exists in v1, simulate by directly launching the app with a route argument via `flutter run --route /listings/<uuid>`.)
3. Confirm app launches directly to `ListingDetailsPage`.
4. Tap AppBar back arrow → confirm route to HomePage (NOT app exit).
5. Repeat with Android system back gesture.

**Pass criteria**: SC-033 ✓.

---

## Step 15 — Q6=A background→foreground resume (SC-035)

1. On HomePage, scroll past page 1 (load page 2 via infinite scroll; observe ≥ 25 cards loaded).
2. Note the current scroll position + the topmost-visible card.
3. Press the Android Home button to background the app.
4. Open WhatsApp (or another app) for ≥ 1 minute.
5. Return to AlNujom via the recent-apps switcher.
6. Confirm the HomePage renders the SAME ≥ 25 cards at the SAME scroll position. NO spinner. NO scroll-jump to top.
7. Repeat with 30-minute background interval — confirm identical behavior.
8. Pull-to-refresh manually → confirm cursor discarded, first page re-fetches, any newly-approved listings appear at position 0.

Grep:

```bash
grep -R "AppLifecycleState\|WidgetsBindingObserver\|didChangeAppLifecycleState" lib/features/home/presentation/
# Expected: 0 matches (no lifecycle observer registered).
```

**Pass criteria**: SC-035 ✓.

---

## Step 16 — RLS verification end-to-end (SC-006 / SC-007)

### SC-006 (deep-link to non-approved listing)

1. From SQL workspace: obtain a `draft` listing's UUID:
   ```sql
   SELECT id FROM public.listings WHERE status='draft' LIMIT 1;
   ```
2. On Infinix Note 8, navigate via `adb shell am start` (per step 14) to `/listings/<that-draft-uuid>`.
3. Confirm the page renders the localized "Listing not found" + "Return to home" CTA (NOT a leak of draft data).
4. Repeat for each non-approved status (pending_review, rejected, paused, sold, rented, expired, deleted).

### SC-007 (deep-link to non-existent UUID)

1. Generate a random UUID (e.g., `uuidgen` or `python -c "import uuid; print(uuid.uuid4())"`).
2. Navigate to `/listings/<that-random-uuid>`.
3. Confirm the page renders the IDENTICAL "Listing not found" state (indistinguishable from SC-006).

### Anonymous Storage fetch on non-approved listing's image

1. From SQL: obtain a draft listing's main image `storage_path`:
   ```sql
   SELECT lm.storage_path FROM public.listing_media lm
   JOIN public.listings l ON l.id = lm.listing_id
   WHERE l.status='draft' AND lm.is_main=true LIMIT 1;
   ```
2. From a desktop terminal (anonymous Supabase client OR `curl`):
   ```bash
   curl -I "https://<project>.supabase.co/storage/v1/object/public/listing-images/<that-storage-path>"
   ```
3. Confirm 404 OR 403 response (Phase 11 storage RLS denies anonymous reads on non-approved listings' media).

**Pass criteria**: SC-006, SC-007 ✓.

---

## Step 17 — 4-combination visual check (SC-024)

For each combination — (light, dark) × (ar, en) — on each device:

1. Toggle theme + locale in Phase 2 / Phase 3 settings.
2. Inspect HomePage: AppBar + hero search + property-type chips + section header + cards render without clipped text / overlap / inverted direction defects.
3. Inspect ListingDetailsPage: AppBar + gallery + title + price + location + contact block + amenities + description + per-listing-action block render correctly.

Total: 4 combinations × 2 devices × 2 pages = 16 visual checks.

**Pass criteria**: SC-024 ✓.

---

## Step 18 — RLS-revert propagation (SC of US4 scenario 5)

1. On admin device: pick an `approved` listing; flip its status to `paused` via direct SQL:
   ```sql
   UPDATE public.listings SET status='paused' WHERE id='<that-uuid>';
   ```
2. On Infinix Note 8 (anonymous): pull-to-refresh HomePage. Confirm the listing disappears.
3. Navigate to `/listings/<that-uuid>`. Confirm page renders "Listing not found".
4. Revert: `UPDATE public.listings SET status='approved' WHERE id='<that-uuid>';`
5. Pull-to-refresh HomePage. Confirm the listing reappears at position 0.

---

## Step 19 — Final SC matrix sweep

Walk through every SC in spec.md SC-001..SC-035 and confirm each is ✓ above OR explicitly deferred (with rationale captured in `DEFERRED.md`).

If any SC is unverified at this point, create a `DEFERRED.md` entry with:

- SC number
- Why deferred (hardware not available, time constraint, blocking external decision)
- When to revisit (next QA cycle / pre-launch gate / follow-up phase)
- Pointer to the proxy evidence (code inspection in lieu of manual walk)

---

## Squash-merge readiness

PR is ready to squash-merge when:

- ✅ Steps 1–18 all pass.
- ✅ DEFERRED.md captures any deferred SCs with rationale.
- ✅ Constitution Check in plan.md remains all-Pass.
- ✅ No new analyzer warnings or errors in `flutter analyze --no-fatal-infos --no-fatal-warnings`.
- ✅ `flutter build apk --debug --dart-define-from-file=.env.json` succeeds.
- ✅ Existing Phase 1–12 tests still pass (or are unchanged).
