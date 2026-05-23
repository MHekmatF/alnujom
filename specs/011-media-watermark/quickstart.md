# Phase 11 — Quickstart (Manual Verification Recipe)

**Branch**: `011-media-watermark` | **Date**: 2026-05-22
**Source**: [spec.md](spec.md) + [plan.md](plan.md) + [data-model.md](data-model.md) + [contracts/](contracts/)

This file is the end-to-end manual-verification checklist for Phase 11. Every Functional Requirement (FR-001..FR-023) and every Success Criterion (SC-001..SC-029) is covered by at least one step below. Per Constitution X + `feedback_no_new_tests.md`, this is the project's testing surface — no automated tests are added.

The walk runs on **two devices** per R-34:
- **Primary**: Infinix Note 8 (Helio G80, 6 GB RAM, Android 10/11) — exercises the legacy `READ_EXTERNAL_STORAGE` permission code path AND establishes the SC-001 timing baseline.
- **Secondary**: Pixel 8 Pro emulator (Android 14, API 34) — exercises the granular `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` code path per Q5 = A. Per `project_android_emulator_window_offscreen.md`, run the SetWindowPos PowerShell recipe if the emulator window is off-screen.

Both devices need Supabase env (`.env.json`) and the publisher test account from Phase 10's quickstart (the user whose `publisher_status='approved'` AND `account_status='approved'` already exists per spec 010 DEFERRED.md walk).

---

## Step 0 — Pre-flight check

| Check | Command | Expected |
|---|---|---|
| Branch is correct | `git branch --show-current` | `011-media-watermark` |
| Working tree is clean | `git status` | nothing to commit |
| Phase 10 migrations are applied | Supabase MCP: `list_migrations` | last migration name is `20260519120012_fix_submit_listing_array_append` (or whichever Phase 10 closed at — verify via `specs/010-listing-creation/baseline-pre-migration.txt` or `SELECT max(version) FROM supabase_migrations.schema_migrations`) |
| Pubspec has Phase 11 deps | `grep -E "image_picker|^  image:|flutter_image_compress" pubspec.yaml` | 3 hits |
| Watermark asset exists | `ls assets/images/watermark/logo_watermark.png` | file exists, non-empty |
| AndroidManifest declares Phase 11 permissions | `grep -E "READ_EXTERNAL_STORAGE\|READ_MEDIA_IMAGES\|READ_MEDIA_VIDEO" android/app/src/main/AndroidManifest.xml` | 3 hits (covers SC-026) |

---

## Step 1 — Apply Phase 11 migrations via Supabase MCP

Via `mcp__supabase__apply_migration` (or `mcp__plugin_supabase_supabase__apply_migration`), apply each migration in order. Capture any advisor warnings.

| # | Migration name | Verification SQL | Expected |
|---|---|---|---|
| 1 | `20260522120001_create_listing_media` | `SELECT count(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='listing_media'` | 1 (FR-001) |
| 1 | (same) | `SELECT conname FROM pg_constraint WHERE conrelid='public.listing_media'::regclass AND contype='c'` | includes `listing_media_path_xor_url_chk` AND `listing_media_main_only_when_image_chk` (FR-002) |
| 1 | (same) | `SELECT indexname FROM pg_indexes WHERE tablename='listing_media' AND indexdef LIKE '%WHERE%is_main%'` | `listing_media_one_main_idx` (FR-003) |
| 1 | (same) | `SELECT tgname FROM pg_trigger WHERE tgrelid='public.listing_media'::regclass` | `listing_media_cap_trigger`, `audit_listing_media_insert`, `audit_listing_media_update`, `audit_listing_media_delete`, `set_updated_at_on_listing_media` (FR-004, FR-005) |
| 1 | (same) | `SELECT relrowsecurity FROM pg_class WHERE relname='listing_media'` | `true` (SC-007) |
| 1 | (same) | `SELECT count(*) FROM pg_policies WHERE schemaname='public' AND tablename='listing_media'` | 7 (FR-006) |
| 2 | `20260522120002_create_listing_media_storage_buckets` | `SELECT id, public, file_size_limit, allowed_mime_types FROM storage.buckets WHERE id IN ('listing-images','listing-videos')` | 2 rows: both `public=true`; image=10485760+['image/jpeg']; video=31457280+['video/mp4'] (FR-008, SC-029 part 1) |
| 3 | `20260522120003_create_listing_media_storage_policies` | `SELECT count(*) FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname LIKE '%listing-%'` | 14 (FR-007, SC-029 part 2) |
| 4 | `20260522120004_amend_submit_listing_rpc_for_media_minimum` | `SELECT prosrc FROM pg_proc WHERE proname='submit_listing'` | includes the substring `listing_media.images_below_minimum` (FR-022) |

After all four apply, run `mcp__supabase__get_advisors` (mode `security` then `performance`) and capture any new warnings — annotate in DEFERRED.md if any are introduced.

---

## Step 2 — Anonymous-read deny on a Phase-10-created `draft` listing's media

Setup: take a Phase-10 `draft` listing (use one created during the Phase 10 quickstart walk, or create a fresh one via the app on the Infinix Note 8 — Phase 10 spec US1 path).

Via Supabase MCP `execute_sql` with the anonymous JWT (no signed-in user):

```sql
SELECT * FROM public.listing_media WHERE listing_id = '<draft listing id>';
```

| Expected | Why |
|---|---|
| 0 rows | FR-006: anon SELECT denied for `draft` parent (SC-008) |

Even if a `listing_media` row exists (admin-inserted), anon cannot see it. Verify both before AND after Step 3 inserts media into the draft.

---

## Step 3 — Three-layer non-approved-publisher deny (UX + RLS)

| Layer | Test | Expected |
|---|---|---|
| UX | Sign in on Infinix Note 8 as a user with `publisher_status='pending'` (or revoke an approved user's publisher_status via direct SQL); navigate to the listing form `step 6` (media) — actually, the publisher dashboard's "Create listing" tile is already hidden per Phase 10 — the picker is never reachable | Phase 10 US2 already verified — Phase 11 adds no new UI gate; the picker inherits |
| RLS | With the pending-publisher's JWT, attempt direct SQL `INSERT INTO public.listing_media (listing_id, kind, storage_path, ordering, is_main, watermarked) VALUES ('<their draft listing id>', 'image', '<that id>/x.jpg', 1, false, true)` | 0 rows affected — RLS denies per FR-006 composite write-gate |
| Storage RLS | With the pending-publisher's JWT, attempt `supabase.storage.from('listing-images').uploadBinary('<their draft id>/x.jpg', <bytes>)` | 403 — storage policy rejects per phase11-storage-policies.md owner_insert composite |

---

## Step 4 — Happy-path image upload on Infinix Note 8 (FR-010..FR-016, SC-001..SC-005, SC-011, SC-012)

Setup: Sign in as the approved publisher. Open the form on a `draft` listing (the existing Phase-10 draft, or create a fresh one and walk through steps 1-5 with the Phase 10 happy-path payload). Arrive at step 6 (Media).

| Action | Expected |
|---|---|
| Tap "Add images"; on Android 10/11, the system gallery permission dialog appears once requesting `READ_EXTERNAL_STORAGE` | Accept; the gallery opens |
| Pick 4 images from a prepared gallery folder (each ≥ 2000 px on long edge so downscale is exercised; at least one HEIC if available via Telegram-shared iPhone photo per Q4 = A; one PNG; the rest JPEG) | Each thumbnail appears in the grid with a progress spinner; scrolling remains smooth (SC-011) |
| Wait for processing to complete (≤ ~30 seconds for 4 images on Helio G80) | Each thumbnail's spinner replaced by the watermarked preview; main badge appears on the first row (auto-main per Q3=A default); ordering badges read 1-4 |
| Drag the third thumbnail to position 1 | Grid re-orders; `SELECT id, ordering FROM public.listing_media WHERE listing_id='<id>' ORDER BY ordering ASC` reflects new sequence |
| Long-press the new position-3 thumbnail; tap "Set as main" | Main badge moves; `SELECT id, is_main FROM public.listing_media WHERE listing_id='<id>'` shows the new main row with `is_main=true` and all others `is_main=false`; `audit_logs` count for `listing_media.updated` on this listing increases by 2 (FR-021) |
| Long-press position 4; tap "Delete"; confirm | Thumbnail disappears (3 remain); `SELECT count(*) FROM public.listing_media WHERE listing_id='<id>'` → 3; bucket object removed (verify via `mcp__supabase__execute_sql` `SELECT name FROM storage.objects WHERE bucket_id='listing-images' AND name LIKE '<listing_id>/%'` returns 3 rows); `audit_logs` count for `listing_media.deleted` increases by 1 |
| Advance to Review (step 7); confirm the carousel shows 3 watermarked thumbnails with the main one highlighted | (FR-013 acceptance) |
| Submit | listing flips to `pending_review` (Phase 10 US1 happy path) |
| Download one bucket object via `supabase.storage.from('listing-images').download(<path>)` from desktop, open the JPEG | (SC-002) long edge = 1920 px; (SC-003) AlNujom watermark visible at bottom-end corner ~15% opacity; (SC-024) `exiftool` reports zero GPS / camera fields |

Stopwatch the journey "open dashboard → submit" — confirm ≤ 5 minutes (SC-001). Record actual time in DEFERRED.md as a baseline for future regressions.

---

## Step 5 — 10-image cap (FR-004, SC-004) AND 2-video cap (FR-005, SC-005, SC-018)

| Action | Expected |
|---|---|
| On a fresh `draft` listing, upload 10 images via the picker | All 10 commit; the "Add images" CTA disables with `media.cap.images10` label |
| Attempt to bypass by direct SQL with the owner's JWT: `INSERT INTO public.listing_media (listing_id, kind, storage_path, ordering, is_main, watermarked) VALUES ('<id>', 'image', '<id>/11_test.jpg', 11, false, true)` | SQLSTATE P0001 with MESSAGE `listing_media.cap_exceeded`; DETAIL JSON has `kind=image, current_count=10, max=10` (R-30) |
| Upload 2 videos (each MP4 ≤ 30 MB) | Both commit; the "Add video" CTA disables with `media.cap.videos2` label |
| Attempt direct SQL 3rd video INSERT | SQLSTATE P0001 with `kind=video, max=2` |
| Switch to an admin JWT with `listings.edit_any`; attempt direct SQL 11th image INSERT against any listing | Trigger still fires — admins cannot bypass (SC-018) |

---

## Step 6 — Q1 = A media-minimum check via `submit_listing` (FR-022, SC-017)

| Action | Expected |
|---|---|
| On a draft listing with all Phase 10 required fields populated but ZERO `kind='image'` rows in `listing_media`, call `submit_listing` via the app's Submit button | RPC returns HTTP 400; `missing_fields` array contains `listing_media.images_below_minimum`; `submit_failure_dialog` renders the localized message from `submit.error.imagesBelowMinimum` |
| Upload 1 image; re-submit | RPC returns HTTP 200; status flips to `pending_review` |
| On a `rejected` listing (per Phase 10 US3 — flip via admin SQL if Phase 12 hasn't shipped), delete ALL images via the picker, then tap Submit | RPC returns HTTP 400 with same `images_below_minimum` rejection (Q3=A flows through Q1=A check at submit) |

---

## Step 7 — Q3 = A resubmit edit-in-place + UUID preservation (SC-020)

Setup: from a `rejected` listing with ≥ 3 `listing_media` rows (rejection inserted via admin SQL until Phase 12 ships):

| Action | Expected |
|---|---|
| BEFORE entering step 6: `SELECT id, created_at, ordering, is_main, storage_path FROM public.listing_media WHERE listing_id='<rejected id>' ORDER BY ordering ASC` | Capture the 3 rows as baseline |
| Tap Resubmit; advance to step 6 (Media) | Picker renders 3 existing thumbnails with watermark + ordering + is_main preserved |
| AFTER mount, re-run the same SELECT | Identical row UUIDs + created_at + ordering + storage_path — no DELETE+INSERT churn (R-14) |
| Delete one image | Row removed; row count drops to 2 |
| Add a new image | New row with fresh UUID + ordering=3 |
| Re-submit | listing flips to `pending_review`; chain history `(NULL → draft → pending → rejected → pending)` preserved per Phase 10 US3 |

---

## Step 8 — Q4 = A format normalization (HEIC / PNG / WebP)

On the Infinix Note 8 (or if HEIC sources are not on device, use desktop-prepared test files via `adb push` to the Pictures folder):

| Source format | Picker behavior |
|---|---|
| `test.jpg` (JPEG 4000×3000) | Accepts; pipeline runs; uploads as JPEG ≤ 1920 long edge |
| `test.png` (PNG with transparency) | Accepts; pipeline composites against white background then re-encodes as JPEG |
| `test.heic` (iPhone-shot, ~3 MB) | Accepts; `flutter_image_compress` decodes; pipeline re-encodes as JPEG |
| `test.webp` (Telegram sticker export) | Accepts; pipeline re-encodes as JPEG |
| `test.gif` (GIF, ANY size) | Picker rejects at file-pick with `media.error.formatNotSupported` |
| `test.bmp` (BMP, ANY size) | Same rejection |
| `test.raw` (RAW camera file) | Same rejection |

For each accepted source: download the bucket object and confirm `mime='image/jpeg'` (SC-019 indirectly; Q4=A directly).

---

## Step 9 — Q5 = A Android-version permission walk (SC-026)

### 9a — Infinix Note 8 (Android 10/11): legacy code path

| Action | Expected |
|---|---|
| Fresh install of the APK on the Infinix Note 8 | App starts |
| Sign in as the approved publisher; reach step 6 (Media); tap "Add images" the FIRST time | System dialog requests `READ_EXTERNAL_STORAGE` (NOT `READ_MEDIA_IMAGES`) |
| Tap Allow | Gallery opens; pick works |
| Reboot the device / wipe app data; sign in; tap "Add images"; this time tap Deny | Picker surfaces `media.error.galleryPermissionDenied` with `media.action.openSettings` CTA |
| Tap Open settings | Android Settings opens at the app's permission page |
| Grant `Storage` permission; back to the app; retry "Add images" | Picker now opens the gallery (image_picker re-requests on next invocation per Q5 = A handling) |

### 9b — Pixel 8 Pro emulator (Android 14): granular code path

| Action | Expected |
|---|---|
| Launch Pixel 8 Pro emulator (Android 14); if window is off-screen, run the SetWindowPos PowerShell recipe from `project_android_emulator_window_offscreen.md` | Emulator visible |
| Fresh install; sign in; reach step 6; tap "Add images" the FIRST time | System dialog requests `READ_MEDIA_IMAGES` AND `READ_MEDIA_VIDEO` (NOT `READ_EXTERNAL_STORAGE`) — Android 14 uses granular permissions |
| Tap Allow | Gallery opens |
| Tap "Add video" the FIRST time | If both permissions were granted in the prior step, the video picker opens; otherwise system dialog appears |

Both walks verify FR-023's manifest declaration is correct AND the runtime requests align with the device's Android version (SC-026).

---

## Step 10 — Q6 = B pre-decode reject of oversized images (SC-027)

Prepare a 9000×9000 px test image (`test_9000x9000.jpg`, ~50 MB) — easy to generate via desktop ImageMagick: `magick -size 9000x9000 xc:red test_9000x9000.jpg`. Push to the device via `adb push`.

| Action | Expected |
|---|---|
| Pick the 9000×9000 source via the picker | Picker rejects within < 1 second (header-only read) with `media.error.imageTooLarge` |
| Confirm decode was NOT invoked: add a `print` debug log around the `decodeImage()` call before the run (or run the BLoC under a debugger with a breakpoint on `decodeImage`) | The breakpoint / log is NOT reached for the 9000-px file |
| Pick a 7999×7999 source (just under the cap) | Pipeline runs normally; downscale brings it to 1920×1920; commits |

---

## Step 11 — Q7 = B 60-second per-image timeout (SC-028)

Setup: enable Android Developer Options → Network → Throttle to ~50 kbps (or use `adb shell tc qdisc add ...` to throttle the emulator/device's outgoing bandwidth).

| Action | Expected |
|---|---|
| With network throttled to ~50 kbps, pick a single 5 MB JPEG | Pipeline runs the local steps quickly (< 5s) then enters upload phase; the per-thumbnail progress spinner continues |
| Wait ≤ ~65 seconds | At ~60s the BLoC timeout fires; the thumbnail switches to error state with the localized timeout message (`media.error.timeout`) and a Retry button |
| Confirm no row inserted: `SELECT count(*) FROM public.listing_media WHERE listing_id='<id>'` BEFORE and AFTER the timeout | Counts identical (no row inserted per FR-015) |
| Confirm no orphaned bucket object: `SELECT count(*) FROM storage.objects WHERE bucket_id='listing-images' AND name LIKE '<id>/%'` BEFORE and AFTER | Counts identical (datasource cleaned up the partial upload per FR-015) |
| Disable throttling; tap Retry on the error thumbnail | Pipeline restarts cleanly; commits |

---

## Step 12 — Q8 = A public bucket + RLS status-flip behavior (SC-025)

| Action | Expected |
|---|---|
| Note the public URL of an image on a `draft` listing via `supabase.storage.from('listing-images').getPublicUrl('<path>')` | URL is stable |
| Anonymous GET the URL (curl / browser without a session) | 403 (RLS denies; parent listing not approved) |
| Admin SQL: `UPDATE public.listings SET status='approved', published_at=now() WHERE id='<id>'` | Status flipped |
| Retry the anonymous GET | 200 + JPEG bytes |
| Admin SQL: `UPDATE public.listings SET status='rejected' WHERE id='<id>'` | Status flipped back |
| Retry the anonymous GET | 403 (RLS denies again) — confirms `storage.objects` policy reads `listings.status` at request time, not at upload time (SC-025) |

---

## Step 13 — Audit log emission completeness (FR-005, FR-021, SC-006)

| Action | Audit row emitted (action key) |
|---|---|
| Image upload | `listing_media.created` |
| Set-as-main (flips two rows) | `listing_media.updated` × 2 |
| Reorder of N rows | `listing_media.updated` × N |
| Per-thumbnail delete | `listing_media.deleted` |

After the full Step 4 walk (4 uploads → 1 reorder → 1 set-main → 1 delete), expect:
- 4 `listing_media.created`
- 2 `listing_media.updated` (set-main) + 4 `listing_media.updated` (reorder re-sequencing 4 rows) = 6 `listing_media.updated`
- 1 `listing_media.deleted`

Total = 11 audit rows. Verify:
```sql
SELECT action, count(*)
FROM audit_logs
WHERE target_type = 'listing_media'
  AND target_id IN (SELECT id FROM listing_media WHERE listing_id='<test listing>')
GROUP BY action;
```

The set-main row count emits even for the deleted row's audit lineage (audit captures before/after states; the deletion is a row in `audit_logs`).

---

## Step 14 — Constitution gate verification

| Constitution principle | SC | Verification |
|---|---|---|
| III (no opt-out, no broad anon carve-out) | SC-007 | `SELECT relrowsecurity FROM pg_class WHERE relname='listing_media'` → true; carve-out count remains 3 (Phase 8 governorates/cities/areas + Phase 9 currencies/exchange_rates — no fourth) |
| V (Arabic-first localization) | SC-015 | Phase 3 lint guard reports 0 hardcoded user-facing strings in new widgets |
| VI (theme tokens) | SC-016 | `grep -E "Color\\(0xFF\|EdgeInsets\\.only\\(left:\|SizedBox\\(height: [0-9]+" lib/features/listing_form/presentation/widgets/{step_media,media_picker,media_thumbnail}.dart` → 0 hits |
| VII (no new permission keys) | SC-022 | `git diff` against Phase 6 permissions seed migration → 0 new rows |
| IX (no Supabase in domain/widgets) | SC-014 | `grep -R "package:supabase_flutter" lib/features/listing_form/presentation/widgets lib/features/listing_form/domain` → 0 hits |
| X (R-05 invariant — log_audit unchanged) | SC-013 | `git diff` against Phase 4 migration that defines `log_audit()` → 0 edits |

---

## Step 15 — DEFERRED.md draft (close-out)

At PR squash-merge time, record in `specs/011-media-watermark/DEFERRED.md`:

- Any advisor warnings from `get_advisors` calls in Step 1.
- SC-001 actual stopwatch time for the Infinix Note 8 walk.
- Any HEIC sources that failed to decode unexpectedly.
- Any orphaned bucket objects discovered during the walk (note for the Phase 23 reconciliation job per R-28).
- The fact that the Pixel 8 Pro emulator walk was Q5-permission-focused, not a full E2E (R-34).
- Pubspec.lock new transitive entry list (R-37) — useful future regression baseline.
- Any FR / SC that was marked "covered" but could not be measured (e.g., SC-011 fps target — if Flutter's frame-time overlay was not enabled).

---

## Step Coverage Map

| FR / SC | Step |
|---|---|
| FR-001..FR-003 (table + constraints + index) | Step 1 |
| FR-004 (cap trigger) | Step 5 |
| FR-005 (audit trigger group) | Steps 4, 13 |
| FR-006 (listing_media RLS) | Steps 2, 3 |
| FR-007 (storage.objects RLS) | Steps 3, 12 |
| FR-008 (bucket config) | Step 1 |
| FR-009 (no new permission key) | Step 14 |
| FR-010..FR-013 (MediaPicker UI) | Step 4 |
| FR-014 (watermark pipeline) | Steps 4, 8, 10 |
| FR-015 (atomic-from-publisher) | Steps 5, 11 |
| FR-016 (watermarked flag) | Step 4 |
| FR-017 (video validator) | Step 5 (mid-test) |
| FR-018 (other validators unchanged) | Step 14 |
| FR-019 (ARB keys) | All UI steps (errors render localized) |
| FR-020 (design tokens) | Step 14 |
| FR-021 (audit on every mutation) | Step 13 |
| FR-022 (submit_listing media check) | Step 6 |
| FR-023 (AndroidManifest permissions) | Steps 0, 9 |
| SC-001..SC-005 | Step 4 |
| SC-006 | Step 13 |
| SC-007 | Steps 1, 14 |
| SC-008..SC-009 | Steps 2, 3, 12 |
| SC-010 | Step 4 |
| SC-011..SC-012 | Step 4 |
| SC-013..SC-014 | Step 14 |
| SC-015..SC-016 | Step 14 |
| SC-017 | Step 6 |
| SC-018 | Step 5 |
| SC-019 | Step 8 + code review for no external_link CTA |
| SC-020 | Step 7 |
| SC-021 | Migration file inspection (Step 1) |
| SC-022 | Step 14 |
| SC-023 | Step 4 (long-press video thumbnail; set-main absent) |
| SC-024 | Step 4 (exiftool on downloaded JPEG) |
| SC-025 | Step 12 |
| SC-026 | Step 9 (both 9a + 9b) |
| SC-027 | Step 10 |
| SC-028 | Step 11 |
| SC-029 | Step 1 (bucket flags + policy count) |
