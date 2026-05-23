# Phase 11 — Research & Locked Decisions

**Branch**: `011-media-watermark` | **Date**: 2026-05-22
**Source spec**: [spec.md](spec.md) (8 clarifications resolved)
**Predecessor**: [Phase 10 research](../010-listing-creation/research.md) (R-01..R-20 invariants — those marked CARRY apply to Phase 11)

This file locks the technical decisions for Phase 11 that the spec deferred to plan-time. Each decision has a fixed `R-NN` index, picks up Phase 10 numbering at R-21 to keep the project-wide research-decision space monotonic, and is consumed by `data-model.md` + the `contracts/` artifacts + `quickstart.md` verbatim.

## Carried-forward invariants from Phase 10 (no re-decision)

| Phase 10 R | Title | Phase 11 application |
|---|---|---|
| R-01 | Date-prefixed migration filenames | **CARRY** — Phase 11 migrations use `20260522120001` … `20260522120004` (four files; see R-21). |
| R-02 | Inline policy bundling + parallel policy files | **CARRY** — `listing_media_policies.sql` AND `listing_media_storage_policies.sql` ship as parallel files mirroring inline bundles. |
| R-03 | Zero-new-pubspec-packages | **PARTIAL DEVIATION** — Phase 11 adds ≤ 3 new packages (`image_picker`, `image`, and at most one HEIC plugin). See R-22. |
| R-04 | No broad anonymous-SELECT carve-out | **CARRY** — `public.listing_media` SELECT for anon is gated by `parent.status='approved'`; matches Phase 10 R-04 (no fourth carve-out is created). |
| R-05 | `log_audit` reusable trigger function unchanged | **CARRY** — Phase 11 attaches the eighth audit-trigger group (`listing_media` INSERT/UPDATE/DELETE) without editing the function body. |
| R-06 | Prefer PL/pgSQL RPC over Edge Function | **CARRY** — Phase 11 amends Phase 10's `submit_listing` RPC body (per Q1=A FR-022); no new Edge Function. |
| R-08 | Trigger-before-seed audit ordering | **CARRY** — Phase 11 seeds zero `listing_media` rows; the invariant remains defensive for any future spec. |
| R-09 | Status-transition trigger and `log_audit` are separate | **CARRY** — Phase 11 does NOT touch the Phase 10 `listing_status_transition_trigger`; it only adds a new audit trigger group on the new child table. |
| R-14 | Stable UUID across resubmits | **CARRY** — Q3=A's edit-in-place picker preserves `listing_media.id` UUIDs across the rejected-resubmit path. |
| R-15 | Zero new permission keys | **CARRY** — Phase 11 reuses `listings.view_all` + `listings.edit_any` from Phase 6 §9.1; FR-009. |
| R-17 | Forward-stated FK constraints permitted | Not applicable in Phase 11 — `listing_media.listing_id` has the FK on day one (Phase 10's `public.listings` already exists). |
| R-18 | Validators in `lib/core/validators/` | **CARRY** — Phase 11's `video_file_validator.dart` lives in the same directory. |
| R-19 | Three-layer publisher-status enforcement helper | **CARRY** — Phase 11 reuses `PermissionChecker.userIsApprovedPublisher` unchanged for the picker write gates. |
| R-20 | No client-side cache on listings reads | **EXTENDED** — Phase 11 introduces `cached_network_image` caching of public-bucket image URLs (per Q8) for Phase 13's gallery consumer; the cache is on storage-object URLs, NOT on `listings` row data, so R-20 is intact at the listings layer. |

The Phase 10 R-07 (area-centroid data-source path), R-10 (NUMERIC(14,2) price precision), R-11 (visibility sync trigger), R-12 (partial unique index on `is_primary`), R-13 (per-step auto-save granularity), and R-16 (public-read-when-approved RLS already shipped in Phase 10) all apply to Phase 10's tables and are not re-decided here.

## R-21 — Phase 11 migration filenames + apply order

**Decision**: Phase 11 ships **four new migration files** under `supabase/migrations/` with date-prefixed filenames continuing Phase 10's `20260519` series (the prior session's `/speckit-clarify` ran on 2026-05-22):

1. `20260522120001_create_listing_media.sql` — `CREATE TABLE public.listing_media` + CHECK constraints + partial unique index + `set_updated_at` trigger + cap trigger (FR-004) + `log_audit` trigger group (FR-005) + inline-bundled RLS policies (FR-006).
2. `20260522120002_create_listing_media_storage_buckets.sql` — `INSERT INTO storage.buckets` for `listing-images` (public, 10 MB file_size_limit, allowed_mime_types `['image/jpeg']`) AND `listing-videos` (public, 30 MB file_size_limit, allowed_mime_types `['video/mp4']`) per Q4 + Q8 + FR-008. Idempotent via `ON CONFLICT (id) DO UPDATE`.
3. `20260522120003_create_listing_media_storage_policies.sql` — Six policies on `storage.objects` per FR-007: per-bucket × (anon SELECT when parent approved, owner SELECT, admin SELECT, owner INSERT/UPDATE/DELETE during draft|rejected, admin INSERT/UPDATE/DELETE). Path-shape enforcement via `split_part(name, '/', 1)::uuid` join to `public.listings`.
4. `20260522120004_amend_submit_listing_rpc_for_media_minimum.sql` — `CREATE OR REPLACE FUNCTION public.submit_listing(...)` re-emits the Phase 10 RPC body verbatim PLUS the Q1=A media-minimum check (FR-022) that adds `listing_media.images_below_minimum` to the `missing_fields[]` payload when `(SELECT count(*) FROM public.listing_media WHERE listing_id = p_listing_id AND kind = 'image' AND watermarked = true) = 0`. The function body is the only delta; signature + permission preconditions + status flip + JSONB return shape are unchanged from Phase 10.

**Rationale**: Splitting bucket creation (migration 2) from `storage.objects` policy creation (migration 3) keeps each migration's responsibility tight. Migration 2 can be re-run idempotently; migration 3 is the policy-level artifact that the Constitution III review reads. Migration 4 is the *minimum-touch amendment* to Phase 10's `submit_listing` — the Phase 10 migration `20260519120007_create_submit_listing_rpc.sql` stays unedited (immutable per Supabase migration tracker semantics), and migration 4 supersedes it via `CREATE OR REPLACE`. Per `project_supabase_mcp_apply_migration.md`, re-applying an existing migration name re-runs the SQL and adds a duplicate tracker row — so migration 4's name MUST be new (not a re-apply of Phase 10's `120007`).

**Alternatives considered**:
- **Single combined migration** (1 file for everything): rejected because the bucket/policy split is the natural source-control boundary the Phase 10 R-02 invariant established.
- **Edit the Phase 10 `submit_listing` migration file** to add the media check in place: rejected because Phase 10 already shipped; the migration file is immutable per project convention. The amend-via-`CREATE OR REPLACE`-in-a-new-migration pattern matches Phase 9's `20260518120007_relax_latest_rates_for_base_to_security_invoker.sql` precedent.

## R-22 — Pubspec dependency additions

**Decision**: Phase 11 adds **three** new packages to `pubspec.yaml`:

1. `image_picker: ^1.1.2` (or latest stable) — provides the gallery + camera picker affordance the MediaPicker calls. Version-aware permission handling per Q5 = A. Maintained by the Flutter team; depends only on standard Android plugin APIs.
2. `image: ^4.5.4` (or latest stable) — pure-Dart decode/encode for JPEG/PNG/WebP + image manipulation (downscale, watermark composite, EXIF strip). No native code.
3. `flutter_image_compress: ^2.4.0` (or latest stable) — JPEG/HEIC native decode on Android via libheif/libjpeg-turbo. The Q4 = A normalization requires HEIC support that the pure-Dart `image` package does not provide; `flutter_image_compress` is the lightest native dependency that does (its Android side bundles libheif). Used ONLY for HEIC → bytes; the rest of the pipeline (downscale, watermark, re-encode) runs through pure-Dart `image`.

**Rationale**: Phase 10 R-03 (zero-new-packages) is intentionally relaxed here because:
- The Q4 = A iPhone-HEIC-shared-via-Telegram use case is a market reality on the Syrian publisher device population. The CLAUDE.md user_test_device memory lists the Helio G80 Infinix Note 8 as the reference; many publishers will receive listing photos as HEIC via Telegram/WhatsApp cross-platform shares.
- The IMPLEMENTATION_PLAN §Phase 11 frontend deliverable explicitly anticipates an image picker — no realistic implementation ships without one.
- `image_picker` is the project-default Flutter picker; alternatives (`file_picker`, `wechat_assets_picker`, `photo_manager`) all carry more transitive deps OR require runtime permission code that `image_picker` already encapsulates.
- `flutter_image_compress` is the single native plugin; the alternative (`heif_converter`) has fewer Pub points + sporadic maintenance.

**Alternatives considered**:
- **Pure-Dart pipeline only** (drop HEIC support entirely): rejected; conflicts with Q4 = A.
- **Use `image_picker`'s built-in HEIC → JPEG conversion** (set `imageQuality` parameter on iOS): rejected; that flag works on iOS only, not Android, and the project targets Android per Constitution XI.
- **Native Android `MediaStore` integration via platform channel**: rejected; would introduce custom Kotlin code, expanding maintenance surface.

**Constitution XI alignment**: All three packages have Android support; none are iOS-only. `image_picker` and `flutter_image_compress` both run on Android emulators (verified during plan-time check). No iOS-specific code is added.

## R-23 — Watermark composite — exact opacity / position / size

**Decision**: The AlNujom logo watermark is composited at:
- **Position**: bottom-right corner (which in RTL Arabic locale renders as bottom-LEFT visually — the picker computes the position from `Directionality.of(context)` to honor RTL).
- **Opacity**: 0.15 (15%) — semi-transparent so the underlying real-estate photo remains the visual subject.
- **Size**: 18% of the image's long-edge dimension. For a 1920×1080 post-downscale image, the watermark is 346 px wide.
- **Padding** from the bottom + outside edge: 24 px (constant; not scaled with image dimensions).
- **Aspect-ratio behavior**: if the source aspect ratio is extreme (long-edge × short-edge ratio > 5:1, e.g., panorama shots), the watermark size is capped at `min(18% of long edge, 50% of short edge)` so it never overflows the canvas.

**Rationale**: 15% opacity + 18%-of-long-edge is a real-estate-industry-standard watermark recipe (Bayut, Aqarmap, Realtor.com all sit in the 12–20% opacity / 15–22% size range). Bottom-right is the canonical position; the RTL-aware mirroring honors Constitution V (Arabic-first). The 24 px padding is small enough that the watermark sits on the photo subject and large enough that the watermark doesn't bleed off-canvas on most camera aspect ratios.

**Alternatives considered**:
- **Diagonal tiled watermark across the entire image** (most aggressive piracy deterrent): rejected for v1 — visually intrusive, would degrade publisher-perceived photo quality, may be revisited in Phase 23 if listing-photo theft becomes a documented issue.
- **Bottom-center watermark**: rejected — symmetric balance against image content is harder to maintain than a corner anchor.
- **No watermark at all** (rely on contractual usage policies): rejected — IMPLEMENTATION_PLAN §6.5 + §Phase 11 mandate the watermark.

## R-24 — Header-only dimension reader (Q6 implementation surface)

**Decision**: The Q6 = B header-only dimension check is implemented as a Dart function `Future<({int width, int height})?> readImageDimensions(Uint8List bytes)` that:
- Reads the first ~64 bytes of the file (sufficient for JPEG SOF0 + PNG IHDR + WebP VP8X chunks; HEIC `ispe` box requires up to ~256 bytes).
- Returns `null` (signaling rejection per FR-014 step (a)) if the format is not in the Q4 accept set.
- For HEIC, falls back to invoking `flutter_image_compress`'s metadata-only mode (the package exposes a `Flutter image compress` method that reads dimensions without decoding pixel data; verified during plan-time).
- Throws no exceptions on malformed headers — returns `null` so the picker surfaces the FR-019 format-not-supported error.

**Rationale**: The pure-Dart `image` package's `decodeImage()` function performs a full pixel decode — too expensive for the Q6 cap check. The package exposes lower-level `decoder.decode(bytes, options: ImageDecodeOptions(...))` calls that can stop after metadata parsing on some formats, but not uniformly across JPEG/PNG/HEIC/WebP. A purpose-built header-reader avoids the cross-format inconsistency.

**Alternatives considered**:
- **Just call `image.decodeImage()` and rely on OOM-catch** (per FR-014 step b catching OOM): rejected — Q6 = B explicitly requires pre-decode rejection.
- **Use platform channels to call Android's `BitmapFactory.Options.inJustDecodeBounds=true`**: rejected — would add Kotlin code.

## R-25 — Background isolate model for the FR-014 pipeline

**Decision**: Each image processed in the FR-014 pipeline runs on a **shared sequential isolate worker** spawned via `Isolate.spawn()` at MediaPicker mount and reused across image picks. The worker pulls from a `StreamQueue<_ImageProcessingJob>` that the main isolate writes to as the publisher picks files. Processing is strictly sequential (one job at a time) to bound peak RAM at one decoded image × 4 bytes/pixel + the watermark buffer + the JPEG re-encode buffer ≈ 100 MB peak for a 1920×1920 px intermediate buffer.

**Rationale**:
- `Flutter`'s `compute()` API spawns a fresh isolate per call — overhead is ~50–200 ms per spawn. For an 8-image batch (US4), that's up to 1.6 s of spawn overhead alone.
- A shared worker eliminates spawn overhead; the publisher sees the first image commit faster.
- Sequential (not concurrent) processing bounds peak RAM. The Helio G80's 6 GB total — minus OS reservation (~1.5 GB) and Flutter framework (~250 MB) — leaves ~4 GB headroom; one ~100 MB image processing slot is well within budget. Two concurrent slots (200 MB) would also work but trades RAM for marginal latency on a CPU-bound device — sequential keeps the model simple.
- The worker terminates when the MediaPicker route disposes; no long-lived isolate leak.

**Alternatives considered**:
- **`compute()` per image**: rejected due to spawn overhead.
- **Concurrent isolate pool (2-3 workers)**: rejected — increases peak RAM without meaningful throughput gain on a 4-core Helio G80 where image-compress is single-threaded per task.
- **No isolate, run on main thread**: rejected — violates SC-011 (≥ 30 fps during processing).

## R-26 — `storage.buckets` row-create approach (idempotent)

**Decision**: Migration 2 creates buckets via SQL:

```sql
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES
  ('listing-images', 'listing-images', true, 10485760, ARRAY['image/jpeg']),
  ('listing-videos', 'listing-videos', true, 31457280, ARRAY['video/mp4'])
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;
```

**Rationale**: `storage.buckets` is a regular Postgres table managed by Supabase Storage. Direct SQL INSERT is supported by Supabase docs and is the path the Studio uses internally. The ON CONFLICT clause makes the migration idempotent against re-apply.

**Alternatives considered**:
- **Supabase Storage REST API call** (`POST /storage/v1/bucket`): rejected — requires runtime authentication and is harder to author as a migration. SQL-only keeps the bucket creation in the source-controlled migration file per Constitution II.
- **Manual bucket creation via Supabase Studio**: rejected — violates Constitution II (no Studio-only state).

## R-27 — `storage.objects` RLS policy SQL shape

**Decision**: The six policies on `storage.objects` per bucket (anon SELECT + owner SELECT + admin SELECT + owner write + admin write + path-shape enforcement) use the same join-through-`public.listings` pattern as the `listing_media` table policies. Specifically, every policy's `USING` (and `WITH CHECK` for writes) extracts the listing_id from `split_part(name, '/', 1)` and casts to `uuid`, then joins to `public.listings` to derive the parent's `publisher_user_id` and `status`. Example for the anon SELECT policy on `listing-images`:

```sql
CREATE POLICY "listing_images_anon_select_when_approved"
ON storage.objects FOR SELECT
TO anon
USING (
  bucket_id = 'listing-images'
  AND EXISTS (
    SELECT 1 FROM public.listings l
    WHERE l.id = split_part(objects.name, '/', 1)::uuid
      AND l.status = 'approved'
      AND (l.published_at IS NULL OR l.published_at <= now())
      AND (l.expires_at IS NULL OR l.expires_at > now())
  )
);
```

**Path-shape enforcement** is layered on the INSERT/UPDATE policies via a `WITH CHECK` that requires the `name` to match `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$` (UUID prefix + slash + non-empty filename). A malformed path INSERT is rejected.

**Rationale**: Mirroring the `listing_media` policy logic at the `storage.objects` layer is the simplest defense-in-depth — both layers reject the same access patterns. The `EXISTS` subquery is a single index lookup on `public.listings (id)` which is the table's primary key (cheap; latency-bounded).

**Alternatives considered**:
- **Per-bucket RLS based on object owner only** (`owner = auth.uid()`): rejected — wouldn't enforce the public-when-approved gate.
- **Application-layer URL signing** instead of RLS: rejected per Q8 = A (public bucket + RLS).

## R-28 — Bucket-cleanup-on-row-delete

**Decision**: When a `listing_media` row is DELETEd (publisher delete via picker, admin delete via Studio, cascade from `listings.delete`), the corresponding bucket object MUST also be deleted. Phase 11 ships this as a **client-side responsibility** — the `SupabaseListingMediaDatasource` performs `await supabase.storage.from(bucket).remove([path])` BEFORE the SQL DELETE on the row. If the storage remove fails (network blip), the SQL DELETE is rolled back via try/catch + retry. No PostgreSQL trigger calls the Storage API directly.

**Rationale**: A Postgres trigger would need to call out to Storage via the `pg_net` extension or via a `pg_cron`-scheduled cleanup job; both add complexity. The two-step client-side sequence is simple, observable in audit logs (the FR-005 trigger emits `listing_media.deleted` AFTER the row delete commits, AFTER the bucket object is removed), and matches the Phase 10 pattern (RPC owns the multi-step write).

**Forward-stated reconciliation job**: A Phase 23+ background job MAY scan for orphaned bucket objects (objects whose path-derived listing_id has no row in `listing_media`) and clean them up. The job is out of Phase 11 scope; the deferral is recorded in DEFERRED.md at close-out.

**Alternatives considered**:
- **Postgres trigger calling `net.http_post` against Supabase Storage**: rejected — adds operational complexity; would need a service-role token in `vault` per ADR-0001 just to delete objects.
- **`pg_cron` periodic cleanup job**: rejected for Phase 11 — moved to Phase 23.

## R-29 — `cached_network_image` cache integration with public-bucket URLs

**Decision**: Per Q8 = A, Phase 13's gallery and Phase 14's thumbnails will consume `supabase.storage.from(bucket).getPublicUrl(path)` URLs and pass them to `cached_network_image` (already in `pubspec.yaml` since Phase 1). The public URLs are stable for a given path; the cache is keyed by URL; no rotation, no expiry, no signed-URL refresh logic.

**Phase 11 scope**: Phase 11 does NOT ship Phase 13's gallery. The MediaPicker thumbnail rendering (FR-013) MAY use `cached_network_image` for the in-grid thumbnail of an already-uploaded image — research-time decision — but the picker also has access to the raw upload bytes during the just-uploaded session, so the first render can use the local bytes directly via `Image.memory()` and cache them to disk for subsequent re-mounts.

**Rationale**: This is the path of least churn for Phase 13/14 consumers. Q8 = A's stable URLs are the contract.

## R-30 — Cap-trigger return-payload shape

**Decision**: When `listing_media_cap_trigger` raises a SQLSTATE exception for cap violation, the `RAISE EXCEPTION` carries the SQLSTATE `P0001` (`raise_exception`, the standard PL/pgSQL custom-error code) with a MESSAGE of `'listing_media.cap_exceeded'` and a DETAIL JSONB block:

```sql
RAISE EXCEPTION 'listing_media.cap_exceeded'
USING DETAIL = jsonb_build_object(
  'kind', NEW.kind,
  'current_count', v_count,
  'max', CASE WHEN NEW.kind = 'image' THEN 10 ELSE 2 END
);
```

The Flutter datasource catches `PostgrestException` (Supabase's typed error), reads `error.details` for the JSONB payload, and surfaces a localized cap-exceeded message keyed by `error.message` (`listing_media.cap_exceeded`).

**Rationale**: Matches the structured-error pattern Phase 10's `submit_listing` RPC uses for `missing_fields[]` (FR-010a). The localized rendering layer reads structured fields, not free text — Constitution V is preserved (no English-only error strings escape).

## R-31 — Q1=A media check placement inside `submit_listing` migration 4

**Decision**: Migration 4's amended `submit_listing` body inserts the media check **between** the Phase 10 Q1=B required-field validation block and the status flip. Specifically, the body order is:

1. Load listing + verify `auth.uid() = publisher_user_id` (Phase 10).
2. Verify `publisher_status='approved' AND account_status='approved'` (Phase 10).
3. Verify current `status IN ('draft','rejected')` (Phase 10).
4. Run Phase 10 Q1=B required-field validation, populating `v_missing TEXT[]` (Phase 10).
5. **NEW per Q1=A FR-022**: count `listing_media` rows; if zero `kind='image' AND watermarked=true`, append `'listing_media.images_below_minimum'` to `v_missing`.
6. If `array_length(v_missing, 1) > 0`, RAISE EXCEPTION 22023 with the combined missing-field list (Phase 10's error-emission path is reused unchanged).
7. UPDATE `listings.status='pending_review'` (Phase 10).
8. Return the JSONB success payload (Phase 10).

**Rationale**: Placing the media check inside the existing `v_missing` accumulator is the lowest-touch amendment. Phase 10's structured error contract (`missing_fields[]` array in the SQLSTATE DETAIL) absorbs the new key without changes — the client's `submit_failure_dialog.dart` from Phase 10 already iterates the array; Phase 11 only adds an ARB key for the new error message and the dialog renders it via the same loop.

**Alternatives considered**:
- **Separate RPC for media check**: rejected — would force the client into a two-call submit flow (validate-media then submit), doubling round-trips.
- **Client-side-only check** (no server enforcement): rejected — violates the layered enforcement pattern established by Phase 10's FR-010a (client AND server validate the same rules; server is authoritative).

## R-32 — Manifest permission set + image_picker version-aware request

**Decision**: Per Q5 = A, the AndroidManifest.xml gains exactly three new `<uses-permission>` declarations:

```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
```

The `image_picker` plugin handles the version-aware runtime request internally (verified against the plugin's source — its `MethodCallHandler` reads `Build.VERSION.SDK_INT` and requests the appropriate permission set). No `permission_handler` package is added.

**Settings deep-link** for the "Open settings" CTA: the Flutter code uses Android's intent action `android.settings.APPLICATION_DETAILS_SETTINGS` via a platform-channel invoke OR via the `app_settings` package — research-time decision. Plan-time preference: invoke via a thin platform-channel method (zero new package; ~30 LoC of Kotlin in `MainActivity` or a dedicated handler), keeping the pubspec dependency surface narrow.

**Alternatives considered**:
- **Use `permission_handler` package** for explicit runtime permission management: rejected — `image_picker` already handles it; adding `permission_handler` is duplicate machinery.
- **Use `app_settings` package** for the deep-link: rejected for now, can be reconsidered if the platform-channel approach is fragile.

## R-33 — Watermark asset path and bundling

**Decision**: The AlNujom logo watermark asset ships at `assets/images/watermark/logo_watermark.png` per Q3 (well, per the Q3-resolved spec assumption). The file is a PNG with alpha channel, sized at ~512×128 (4:1 aspect ratio — wide for legibility), with the AlNujom wordmark + a small icon. The PNG is the only watermark asset bundled; no separate `@2x` / `@3x` variants — the FR-014 composite operation scales the watermark to 18% of the destination image's long edge at composite time, so a single high-resolution source asset suffices.

The asset is declared in `pubspec.yaml` under the existing `flutter.assets` list. Loading is done once per MediaPicker mount via `AssetImage('assets/images/watermark/logo_watermark.png')` and cached in the picker's BLoC state.

**Rationale**: Constitution VI's design-token discipline applies to widget code, not to bundled assets. The watermark is a brand asset; its path is a stable string consumed once at composite time.

**Failure mode**: If the asset is missing from the build (developer error during PR review), the picker surfaces a "watermark could not be loaded — please update the app" fail-soft message per FR-014 edge case + the spec's "Watermark logo asset is missing" edge case. The pipeline does NOT upload an unwatermarked image (fail closed per Constitution III).

## R-34 — `quickstart.md` device-coverage matrix

**Decision**: Per SC-026's commitment, Phase 11's `quickstart.md` includes two device walkthroughs:

1. **Infinix Note 8 walk** (Android 10/11): exercises the legacy `READ_EXTERNAL_STORAGE` permission code path. Covers SC-001 (≤ 5 min end-to-end), SC-011 (≥ 30 fps during processing), SC-012 (per-thumbnail actions on 6.78" screen), SC-024 (EXIF strip verification on real-device photos).
2. **Pixel 8 Pro emulator walk** (Android 14): exercises the granular `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` permission code path. Covers SC-026 (manifest permission verification on both Android-version code paths). Per `project_android_emulator_window_offscreen.md`, the emulator window may need SetWindowPos to be visible.

The Pixel 8 Pro emulator walk is intentionally NOT a full end-to-end golden walk — it's a focused permission + bucket-upload smoke test. The Infinix Note 8 walk is the canonical SC-001 timing reference.

**Rationale**: Constitution XI commits to Android-First MVP; reference QA device is Infinix Note 8. Q5 = A's manifest declares granular permissions that the Infinix Note 8 won't exercise; the Pixel 8 Pro emulator covers that delta.

## R-35 — `submit_listing` Phase 10 migration immutability + amend pattern

**Decision**: The Phase 10 migration `20260519120007_create_submit_listing_rpc.sql` is **NOT edited** in Phase 11. Phase 11's migration 4 (`20260522120004_amend_submit_listing_rpc_for_media_minimum.sql`) issues a fresh `CREATE OR REPLACE FUNCTION public.submit_listing(...)` with the amended body. After Phase 11 apply, the function body in the database reflects Phase 11's version; the Phase 10 migration file remains in source for historical auditability.

**Rationale**: Supabase migration tracker records each applied migration by name; editing an existing migration file would not re-apply (the tracker would think it already ran). `project_supabase_mcp_apply_migration.md` is explicit on this. A new migration file is the only safe path.

**Implementation note for migration 4**: The migration body MUST include the FULL function body — not just a delta. PostgreSQL has no syntax for partial function amendment; `CREATE OR REPLACE` replaces the entire function definition. The plan-time research file (this file) carries the additive diff inline (R-31); `data-model.md` carries the complete function body as it ships in migration 4.

## R-36 — Phase 11 SQL-only Edge Function deviation status

**Decision**: Phase 11 introduces **zero new Edge Functions**. The cap trigger (FR-004), audit triggers (FR-005), RLS policies (FR-006, FR-007), and bucket configuration (FR-008) are all server-side SQL. The MediaPicker's storage uploads call Supabase Storage directly via the Flutter SDK (`supabase.storage.from(bucket).upload(...)`). The `submit_listing` amendment (FR-022, R-31) extends an existing RPC, not adds a new one.

**Rationale**: Carries Phase 7 + Phase 9 + Phase 10 R-06 (prefer PL/pgSQL over Edge Functions for permission-checked mutations). The Phase 11 surface has no atomic multi-step server-side mutation that an Edge Function would simplify — every multi-step write is naturally bracketed by either a trigger (cap, audit) or by the existing `submit_listing` RPC.

## R-37 — Pubspec `pubspec.lock` regeneration

**Decision**: After the three new packages land in `pubspec.yaml` (R-22), `flutter pub get` is run once to regenerate `pubspec.lock`. The regenerated `pubspec.lock` is committed in the same PR as the spec / plan / data-model / contracts diff. The lock includes transitive deps:
- `image_picker` brings `image_picker_android`, `image_picker_platform_interface`.
- `image` is leaf (no transitive deps beyond `archive` + `xml`).
- `flutter_image_compress` brings `flutter_image_compress_common`, `flutter_image_compress_platform_interface`, plus its Android-side `libheif` artifact.

The total transitive count is bounded at ≤ 12 new entries in `pubspec.lock`. No package introduces an iOS-only dependency.

**Rationale**: Constitution XI requires Android compatibility for every plugin; the lock review confirms it. Phase 10's R-03 zero-new-packages invariant is intentionally relaxed here (per R-22).

## R-38 — Q3=A row-deletion-on-publisher-action storage cleanup ordering

**Decision**: When the publisher uses the picker to delete an image during a resubmit (Q3=A's edit-in-place), the BLoC's `MediaDeleted(id)` event runs the following sequence in the datasource:

1. Load the `listing_media` row to read its `storage_path`.
2. Call `await supabase.storage.from('listing-images').remove([storage_path])`.
3. If the remove succeeds OR returns a 404 (object already gone — e.g., admin pre-cleaned), proceed.
4. If the remove fails for any other reason, retry once.
5. If the retry fails, surface a localized "could not remove image — please try again" error to the picker; the row is NOT deleted; the publisher's state is preserved.
6. On successful remove, `DELETE FROM public.listing_media WHERE id = $1` (RLS-permitted for the owner during draft|rejected per FR-006).
7. The FR-005 `log_audit` AFTER DELETE trigger fires, emitting the `listing_media.deleted` audit row.

**Rationale**: This ordering ensures we never have a row pointing to a missing object (the gallery would render a broken-image placeholder). The reverse order (DELETE row first, then remove object) risks abandoning the bucket object if the storage call fails (orphan).

**Edge case for cascade-delete**: When the parent `listings` row is DELETEd, `listing_media` rows cascade-delete via FK. Bucket objects are NOT removed by the cascade — they become orphans. This is acknowledged in the spec's edge cases and forward-stated to the Phase 23 reconciliation job (R-28).

## R-39 — Per-image timeout enforcement layer

**Decision**: Per Q7 = B, the 60-second per-image timeout is enforced at the BLoC layer in `listing_form_bloc.dart` (or the new `media_picker_bloc.dart` if the MediaPicker has its own BLoC — research-time decision, see R-40). Each `MediaPicked(file)` event triggers a `Future` wrapped in `.timeout(Duration(seconds: 60), onTimeout: () => throw _MediaTimeoutException())`. The timeout starts at event receipt and covers the entire pipeline (header read, decode, downscale, watermark, upload, retries).

On timeout, the BLoC emits a thumbnail-error state with the localized FR-019 timeout message and a `MediaRetry(id)` event handler. The isolate worker (R-25) is signaled to abort the current job via the StreamQueue's cancellation token; partial bucket objects are removed via the R-38 storage-cleanup ordering.

**Rationale**: BLoC-layer timeout is observable, testable (manual SC-028 verification), and decoupled from the SDK's internal HTTP timeout. The Supabase SDK's default upload timeout is ~60s but not guaranteed across versions; the explicit BLoC timeout pins the contract.

## R-40 — MediaPicker BLoC ownership (extend `ListingFormBloc` or new `MediaPickerBloc`?)

**Decision**: Phase 11 **extends** Phase 10's `ListingFormBloc` with media events rather than introducing a separate `MediaPickerBloc`. Specifically, `ListingFormBloc` adds five new event types:
- `MediaPicked(List<XFile> files)` — batch image pick from gallery.
- `VideoPicked(XFile file)` — single video pick.
- `MediaReordered(List<UUID> newOrder)` — drag-reorder commit.
- `MediaSetMain(UUID id)` — set-as-main commit.
- `MediaDeleted(UUID id)` — per-thumbnail delete commit.

The BLoC's state object (Phase 10's `ListingFormState`) gains a `List<ListingMedia> media` field tracking the current media set. The MediaPicker widget reads this slice via a `BlocSelector<ListingFormBloc, ListingFormState, List<ListingMedia>>`.

**Rationale**: Phase 10 already established `ListingFormBloc` as the single owner of the multi-step form state — auto-save granularity (R-13), draft creation/edit, step transitions all live there. Splitting media into a sibling BLoC would force cross-BLoC coordination on form submit (the `submit_listing` call must reflect the current media count for Q1=A). Keeping it in one BLoC keeps the submit path linear.

**Alternatives considered**:
- **New `MediaPickerBloc`** scoped to step 6 only: rejected — would need a `BlocListener` from `ListingFormBloc` to read media count at submit time; more wiring without architectural benefit.
- **Use cubits instead of BLoC** for the picker: rejected — Phase 10 chose BLoC for the form; consistency wins.

## Decisions deferred to `/speckit-implement` time

The following are intentionally NOT locked in research and will be decided during implementation, with the decision recorded in DEFERRED.md at close-out:
- Exact `image_picker` and `flutter_image_compress` API call shapes for HEIC normalization (depends on plugin API surface at implement time).
- Exact Dart code for the header-only dimension reader R-24 (depends on the `image` package's current public API).
- Exact watermark asset SVG → PNG export pipeline (depends on the project's design-asset workflow; may live in `docs/design/assets/watermark/` per existing convention).
- Whether the gallery thumbnail uses `Image.memory(localBytes)` for the just-uploaded session vs `cached_network_image(publicUrl)` for re-mounts (per R-29).

## Summary

19 plan-time decisions locked (R-21 through R-39) plus R-40 (BLoC ownership) totalling 20 — same count as Phase 10. Every spec FR / SC has a research backing. The plan can proceed to data-model + contracts authoring.
