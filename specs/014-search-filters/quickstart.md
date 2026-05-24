# Quickstart: Phase 14 Search & Filters — Manual Verification Recipe

**Feature**: `014-search-filters`
**Created**: 2026-05-24
**Success Criteria Coverage**: SC-001 through SC-011 (all 11)

This recipe verifies Phase 14 end-to-end. Follow the steps in order. Each step names the SC(s) it covers. Steps marked **[DB]** use Supabase MCP tools. Steps marked **[CODE]** are grep/file checks. Steps marked **[UI]** require the Flutter app running on device.

---

## Prerequisites

1. Phase 13 is merged and the home feed shows approved listings on device.
2. Branch `014-search-filters` is checked out.
3. At least 5 approved listings exist in the database with varied: property types, purposes, governorates, prices (some USD, some SYP), and room counts.
4. At least 2 approved listings have Arabic keywords in their title (e.g., "شقة" and "فيلا").
5. Pixel 8 Pro emulator: window visible (see `docs/dev/android-emulator-windows.md` if off-screen).

---

## Step 1 — Apply migrations (Sub-Phase A)

**[DB]** Apply the three migrations via Supabase MCP `apply_migration` in order:

```
1. 20260525120001_listings_search_vector.sql
2. 20260525120002_create_v_listings_public.sql
3. 20260525120003_create_search_listings_rpc.sql
```

**Warning**: Before applying each, read the migration file and confirm it has not already been applied (per `project_supabase_mcp_apply_migration.md` — re-applying re-runs SQL and adds a duplicate tracker row).

---

## Step 2 — Verify `search_vector` column + GIN index (SC-001 precondition)

**[DB]** Run via `execute_sql`:

```sql
SELECT attname, atttypid::regtype
FROM pg_attribute
WHERE attrelid = 'public.listings'::regclass
  AND attname = 'search_vector';
```

Expected: one row with `atttypid = tsvector`.

```sql
SELECT indexname FROM pg_indexes
WHERE tablename = 'listings'
  AND indexname = 'idx_listings_search_vector';
```

Expected: one row `idx_listings_search_vector`.

```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT id FROM public.listings
WHERE search_vector @@ plainto_tsquery('simple', 'شقة')
  AND status = 'approved';
```

Expected: plan includes `Bitmap Index Scan on idx_listings_search_vector` (or `Index Scan on idx_listings_search_vector`). Not a bare `Seq Scan` (acceptable on tiny dev tables — re-check with production data).

---

## Step 3 — Smoke test the `search_listings` RPC

**[DB]** Run six smoke tests from `contracts/phase14-search-listings-rpc.md §Smoke Test Queries`:

```sql
-- Arabic keyword
SELECT id, title FROM public.search_listings(p_query => 'شقة', p_limit => 5);
-- Should return only listings whose title/address contains 'شقة' exactly.

-- Property type facet
SELECT id, property_type FROM public.search_listings(p_property_type => 'apartment', p_limit => 5);
-- All rows must have property_type = 'apartment'.

-- Rooms exactly 3
SELECT id FROM public.search_listings(p_rooms => 3, p_rooms_mode => 'exactly', p_limit => 5);
-- All returned listings must have rooms = 3.

-- Rooms at least 2
SELECT id FROM public.search_listings(p_rooms => 2, p_rooms_mode => 'at_least', p_limit => 5);
-- All returned listings must have rooms >= 2.

-- Price sort ascending
SELECT id, primary_amount FROM public.search_listings(p_sort => 'price_asc', p_limit => 5);
-- Rows must be ordered primary_amount ASC.

-- Anonymous role check (no approved-filter bypass possible)
SET LOCAL ROLE anon;
SELECT count(*) FROM public.search_listings(p_limit => 20);
RESET ROLE;
-- Should succeed and return only approved, in-window listings.
```

All checks pass → proceed. Any failure → fix the RPC SQL before continuing.

---

## Step 4 — Grep gates

**[CODE]** Run these checks on the codebase:

```bash
# Gate 1: No app-layer status='approved' filter in search code
grep -r "status.*approved" lib/features/search/ --include="*.dart"
# Expected: zero matches

# Gate 2: Only one file in search/ imports package:supabase_flutter
grep -rl "package:supabase_flutter" lib/features/search/ --include="*.dart"
# Expected: exactly ONE file — supabase_search_datasource.dart

# Gate 3: No hardcoded hex colors or sizes in search widgets
grep -r "#[0-9A-Fa-f]\{6\}" lib/features/search/presentation/ --include="*.dart"
# Expected: zero matches

# Gate 4: All user-visible strings in search/ go through AppLocalizations
grep -r '"[^"]\{3,\}"' lib/features/search/presentation/ --include="*.dart" | grep -v "//.*\"" | grep -v "l10n\." | grep -v "ARB\|key\|_\|test"
# Expected: zero matches for user-visible strings not using l10n
```

---

## Step 5 — Launch app on Infinix Note 8 (primary device)

```bash
flutter run --dart-define-from-file=.env.json
```

Home screen should load with approved listings. Proceed to UI verification.

---

## Step 6 — Hero search bar entry point (SC-011 part 1)

**[UI]**
1. Tap the hero search bar on the Home screen.
2. Verify: `SearchPage` opens.
3. Verify: keyboard is visible and focused on the text field.
4. Verify: no snackbar appears.
5. Verify: no filters are pre-applied (filter sheet, when opened, shows all dimensions empty).

**Covers**: SC-011 (hero search bar entry point), US1 scenario 2.

---

## Step 7 — Property-type chip entry point (SC-011 part 2)

**[UI]**
1. Press Back to return to Home.
2. Tap one of the property-type chips (e.g., "Apartments").
3. Verify: `SearchPage` opens with results already filtered to apartments.
4. Verify: keyboard is NOT auto-focused.
5. Verify: no snackbar appears.
6. Open filter sheet → verify `PropertyType.apartment` chip/dropdown is selected.

**Covers**: SC-011 (chip entry point), US1 scenario 3.

---

## Step 8 — Arabic keyword search (SC-001)

**[UI]**
1. In the search bar, type "شقة" and submit (tap keyboard submit / search button).
2. Verify: only listings whose title or address contains "شقة" appear.
3. If any listing containing only "شقق" (not "شقة") appears → **FAIL** (exact-token contract violated).
4. If result count < 3: verify the Arabic hint message appears below the results (FR-019).
5. Clear the search bar (tap ×) → verify all approved listings return (US1 scenario 4).

**Covers**: SC-001.

---

## Step 9 — Latin keyword search (SC-002)

**[UI]**
1. Type "Damascus" (or any Latin keyword present in a listing address) and submit.
2. Verify: only listings with "Damascus" (case-insensitive) in title, address, or description appear.
3. Clear the search bar → verify full listing list returns.

**Covers**: SC-002.

---

## Step 10 — Facet filters (SC-003)

**[UI]**
1. Open the filter sheet (tap "Filters" button).
2. Verify: sheet opens as a bottom sheet (draggable).
3. Select purpose = "For Rent" and property type = "Apartment". Tap "Apply".
4. Verify: only approved rent-apartment listings appear.
5. Re-open filter sheet. Change rooms to "Exactly 3" (SegmentedButton on "تماماً", stepper to 3). Tap "Apply".
6. Verify: only listings with exactly 3 rooms remain.
7. Re-open filter sheet. Change rooms mode to "At least 2" (SegmentedButton on "على الأقل", stepper to 2). Tap "Apply".
8. Verify: listings with 2, 3, 4+ rooms all appear (none with 1 room).
9. Re-open filter sheet. Tap "Reset". Verify all filter controls clear (purpose, property type, rooms all unset). Sheet remains open.
10. Tap "Apply" with all cleared. Verify full approved listing set returns.

**Covers**: SC-003 (and US2 scenarios 1, 2, 7, 8, 9).

---

## Step 11 — Sort order inline control (SC-004)

**[UI]**
1. In search results (no filters), find the inline sort control (DropdownButton above results).
2. Default should be "الأحدث / Newest" — verify results are ordered by published date descending.
3. Select "السعر: من الأقل / Price: Low to High" — verify results reorder to ascending price.
4. Verify: active filters are not cleared after sort change.
5. Select "السعر: من الأعلى / Price: High to Low" — verify results reorder to descending price.
6. Return to "Newest" — verify results reorder back.
7. Each reorder should be visibly instant (within ~1 second per SC-004).

**Covers**: SC-004.

---

## Step 12 — Back-navigation filter state restoration (SC-005)

**[UI]**
1. Apply a filter (e.g., purpose = "For Sale") and sort = "Price: Low to High".
2. Tap a result card → `ListingDetailsPage` opens.
3. Press Back.
4. Verify: `SearchPage` is restored with:
   - Same filter (purpose = "For Sale") active.
   - Same sort order ("Price: Low to High") active.
   - Same result list visible (no re-fetch spinner).

**Covers**: SC-005, FR-012.

---

## Step 13 — Empty state (SC-006)

**[UI]**
1. Search for a keyword that matches no listings (e.g., "zzzzzzz").
2. Verify: empty-state message appears with body text and "Clear all filters" button.
3. Verify: empty state appears quickly (within ~1 second per SC-006).
4. Tap "Clear all filters" → verify full listing list returns (all filters cleared).

**Covers**: SC-006, FR-010.

---

## Step 14 — Price-range validation (SC-009)

**[UI]**
1. Open filter sheet → scroll to Price Range section.
2. Enter min = 1000, max = 500 (min > max).
3. Tap "Apply".
4. Verify: inline error message appears below the price fields ("الحد الأدنى يجب أن يكون أقل من الأعلى").
5. Verify: filter sheet does NOT close; no query is submitted.
6. Correct to min = 500, max = 1000 → tap "Apply" → verify sheet closes and results are filtered.

**Covers**: SC-009, FR-017.

---

## Step 15 — Pagination (SC-010)

**[UI]**
1. Clear all filters and sort by "Newest".
2. Scroll to the bottom of the result list.
3. Verify: a loading indicator appears briefly at the bottom, then the next page of results is appended.
4. Scroll to the bottom again (if more pages exist) → verify the next page loads.
5. When no more pages: verify the loading indicator disappears and no duplicate results appear.

**Covers**: SC-010, FR-014.

---

## Step 16 — Anonymous access (SC-008)

**[UI]**
1. Sign out from the app (if signed in).
2. Navigate to Home → tap hero search bar → verify `SearchPage` opens without a login prompt.
3. Perform a keyword search → verify results appear.
4. Open filter sheet → apply a filter → verify results appear.
5. No sign-in prompt at any point.

**Covers**: SC-008, FR-015.

---

## Step 17 — RTL / LTR layout (SC-007)

**[UI]**
1. Verify app is in Arabic (RTL) mode.
2. Open `SearchPage` → verify text field, results list, filter sheet all render RTL.
3. Switch app locale to English (LTR) in device settings or app language toggle.
4. Open `SearchPage` → verify text field, results list, filter sheet all render LTR.
5. Verify no truncated labels, no overflow, and correct button/icon alignment in both locales.

**Covers**: SC-007, FR-013.

---

## Step 18 — Pixel 8 Pro emulator secondary verification

Launch `flutter run --dart-define-from-file=.env.json` on the Pixel 8 Pro emulator (see `docs/dev/android-emulator-windows.md` for window positioning).

Repeat steps 8, 10, 12, 16 on the secondary device. Both devices should see identical results from the shared Supabase backend.

---

## Step 19 — SC Matrix Final Check

| SC | Covered in Step | Pass/Fail |
|----|----------------|-----------|
| SC-001 | Step 8 | |
| SC-002 | Step 9 | |
| SC-003 | Step 10 | |
| SC-004 | Step 11 | |
| SC-005 | Step 12 | |
| SC-006 | Step 13 | |
| SC-007 | Step 17 | |
| SC-008 | Step 16 | |
| SC-009 | Step 14 | |
| SC-010 | Step 15 | |
| SC-011 | Steps 6 + 7 | |

Mark each row Pass or Fail. All 11 must pass before opening the Phase 14 PR.

---

## Known Deferred Items

- Arabic morphological search (FR-003 note): Phase 14 uses exact-token matching only. "شقة" does NOT match "شقق". This is intentional (Q1=A). The user-education hint (FR-019) compensates for sparse results. Morphological Arabic search is explicitly deferred to a future phase.
- Exchange-rate-unavailable path for price filter: if no exchange rate exists for the selected currency, the price filter disables with a message. This path is hard to trigger manually — verify via `execute_sql` by temporarily removing a rate row.
