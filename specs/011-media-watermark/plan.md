# Implementation Plan: Listing Media Upload, Client-Side Watermark & Storage Policies

**Branch**: `011-media-watermark` | **Date**: 2026-05-22 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/011-media-watermark/spec.md`

## Summary

Phase 11 introduces the project's first user-managed binary-asset surface on top of Phase 10's listing-status engine. **One new table** (`public.listing_media` — 1:N from `public.listings`) with full RLS coverage; **two new Supabase Storage buckets** (`listing-images` configured as `public: true` with mime allowlist `['image/jpeg']` + 10 MB file_size_limit; `listing-videos` configured as `public: true` with mime allowlist `['video/mp4']` + 30 MB file_size_limit per Q4 + Q8 resolutions); **six new RLS policies on `storage.objects`** mirroring the listing-status gate (anon SELECT when parent `status='approved'` + publish-window open; owner read/write during draft|rejected; admin via `listings.view_all`/`edit_any`); **one new `BEFORE INSERT` cap trigger** `listing_media_cap_trigger` enforcing the 10-image / 2-video caps server-side with a structured `SQLSTATE P0001` payload (R-30); **one new audit-trigger group** on `public.listing_media` emitting `listing_media.created/.updated/.deleted` via Phase 4's `log_audit()` reused unchanged for an **eighth time** (R-05 invariant preserved across Phases 4/5/6/7/8/9/10/11); **one amended Phase 10 RPC** — `submit_listing` body extended with the Q1=A media-minimum check (FR-022) producing the `listing_media.images_below_minimum` key in `missing_fields[]` when zero `kind='image' AND watermarked=true` rows exist; **eight Q1=A / Q2=D / Q3=A / Q4=A / Q5=A / Q6=B / Q7=B / Q8=A clarifications** all folded into the spec and consumed verbatim here. The Flutter side adds a single new presentation widget set under `lib/features/listing_form/presentation/widgets/` (`step_media.dart` replacing the Phase 10 `step_media_placeholder.dart`, plus a reusable `media_picker.dart`) backed by a new datasource `lib/features/listing_form/data/datasources/supabase_listing_media_datasource.dart` + a new abstract repository + entity + six use cases (`UploadImage`, `UploadVideo`, `ReorderMedia`, `SetMainImage`, `DeleteMedia`, `LoadMediaForListing`); **one new validator** under `lib/core/validators/` (`video_file_validator.dart`); **one extended existing BLoC** — Phase 10's `ListingFormBloc` gains five media events per R-40 (no new BLoC); **three new pubspec packages** per R-22 (`image_picker`, `image`, `flutter_image_compress` — the first relaxation of Phase 10's R-03 zero-new-packages invariant, justified by Q4=A HEIC support requirements); **one updated AndroidManifest.xml** declaring the Q5=A version-aware permission set per FR-023; **a tightly bounded ARB-key delta** (~20 new keys covering picker CTAs, action-sheet labels, cap-exceeded messages, format/size/decode errors including the Q4 + Q6 + Q7 messages, the Q1=A `images_below_minimum` rejection text, the storage-bucket-403 messages, and the carousel preview label); **a watermark asset bundle** at `assets/images/watermark/logo_watermark.png` declared in `pubspec.yaml` + composited at the FR-014 default position (R-23). All backend artifacts apply via Supabase MCP `apply_migration`. **No new automated tests** per the durable session feedback rule (`feedback_no_new_tests.md`); verification is manual SQL via Supabase MCP `execute_sql` + `get_advisors` + a two-device manual UI walk (Infinix Note 8 for the legacy permission code path + Pixel 8 Pro emulator for the Q5 granular permission code path per R-34 + SC-026).

**Technical approach**: The eight Q-resolutions from the spec close the design space — Q1=A (`submit_listing` minimum ≥1 image check via FR-022), Q2=D (no `external_link` UI in Phase 11; schema enum retains the value for forward-compat), Q3=A (edit-in-place picker on the rejected-resubmit path preserving row UUIDs per R-14), Q4=A (broad source-format accept set — JPEG/PNG/HEIC/HEIF/WebP — normalized to JPEG via FR-014 pipeline; bucket allowlist tightened to `['image/jpeg']`), Q5=A (AndroidManifest declares both legacy `READ_EXTERNAL_STORAGE` AND granular `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO`; `image_picker` plugin handles version-aware runtime requests), Q6=B (8000×8000 px header-only pre-decode cap), Q7=B (60-second per-image hard timeout enforced at the BLoC layer per R-39), Q8=A (`public: true` buckets with RLS on `storage.objects` as the access filter; stable `getPublicUrl()` URLs for Phase 13 gallery consumption per R-29). Phase 11's backend deliverables collapse into **four new migration files** (synthetic-monotonic 14-digit timestamps `20260522120001` through `20260522120004`), **two new policy files** (`listing_media_policies.sql` for the table; `listing_media_storage_policies.sql` for the `storage.objects` rows — both source-of-truth files per the Phase 6 R-02 invariant inline-bundle-plus-parallel-file pattern), **one new SQL view-less data path** (the picker queries `listing_media` directly; no Phase 11 view is needed because the picker reads at most 10–12 rows per listing — Phase 13's gallery view ships in Phase 13 not here), **zero new Edge Functions** (R-36 carrying forward Phases 7/9/10 R-06), **zero new permission keys** (R-15 / FR-009), **one storage-cleanup-on-row-delete client-side sequence** (R-28 + R-38), and **two device-coverage walkthroughs** in `quickstart.md` per SC-026 / R-34. The Flutter side adds one new presentation widget set inside Phase 10's `lib/features/listing_form/` (NOT a new feature folder — the picker is a step inside the existing form), one new validator, one new datasource + repository + 6 use cases under the same feature folder, and extends Phase 10's `ListingFormBloc` with five media events per R-40. The R-22 pubspec deviation is the single material new-package commitment of this phase — three packages totaling ~12 new transitive deps in `pubspec.lock`, all Android-compatible per Constitution XI. **No new automated tests** per the durable rule; verification is manual SQL + the two-device walk.

## Technical Context

**Language/Version**: Dart 3.x on Flutter (latest stable channel) for the app additions; PostgreSQL (Supabase remote, Postgres 15+) for the SQL migrations and the amended `submit_listing` RPC; AndroidManifest XML for FR-023's manifest declaration. **No Edge Function in Phase 11** per R-36 — every server-side enforcement is achieved via RLS, the cap trigger, the audit triggers, or the amended Phase 10 RPC. **No new TypeScript code anywhere in Phase 11.**

**Primary Dependencies**: Existing packages consumed unchanged — `supabase_flutter` (already in `pubspec.yaml`; Phase 11 uses its `storage.from(bucket).upload/remove/getPublicUrl` API surface for the first time in the project), `flutter_bloc` (already in — Phase 10's `ListingFormBloc` is extended per R-40, not replaced), `equatable`, `get_it` + `injectable`, `go_router` (already in — Phase 11 does NOT register new routes; the picker mounts inside Phase 10's `/publisher/listings/<id>/edit` route), `intl`, `cached_network_image` (already in from Phase 1 — Phase 11's picker MAY use it for thumbnail re-mounts per R-29; Phase 13 will use it for the public gallery), `decimal` (unused in Phase 11). **Three new packages** per R-22:
- `image_picker: ^1.1.2` — gallery + camera picker (camera-capture not in Phase 11 scope).
- `image: ^4.5.4` — pure-Dart decode/encode/composite for JPEG/PNG/WebP.
- `flutter_image_compress: ^2.4.0` — native HEIC decode on Android via bundled libheif (the only realistic path to Q4=A's iPhone-HEIC-via-Telegram support).

All three are Android-compatible (verified during plan-time package vetting); none introduce iOS-only transitive deps.

**Tooling**: Supabase MCP server (`apply_migration`, `execute_sql`, `list_tables`, `list_migrations`, `get_advisors`) is the canonical migration-apply / inspection mechanism — same as Phases 4–10.

**Storage**: Remote Supabase Postgres project. Phase 11 adds:

- **One new table** in the `public` schema:
  - `public.listing_media` — the 1:N child carrying `id UUID PK DEFAULT gen_random_uuid()`, `listing_id UUID NOT NULL REFERENCES public.listings(id) ON DELETE CASCADE`, `kind TEXT NOT NULL CHECK (kind IN ('image','video','external_link'))` (per Q2=D the enum retains `external_link` for forward-compat; Phase 11 UI inserts only `image` + `video`), `storage_path TEXT NULL`, `external_url TEXT NULL`, `ordering INTEGER NOT NULL DEFAULT 0`, `is_main BOOLEAN NOT NULL DEFAULT false`, `watermarked BOOLEAN NOT NULL DEFAULT false`, `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`, `updated_at TIMESTAMPTZ NOT NULL DEFAULT now()`. RLS enabled. CHECK constraints per FR-002 (mutual exclusivity between `storage_path` and `external_url`; `is_main` permitted only when `kind = 'image'`). Partial unique index `(listing_id) WHERE is_main = true AND kind = 'image'` per FR-003. Phase 4's `set_updated_at` trigger attached unchanged.

- **Two new Supabase Storage buckets** in `storage.buckets`:
  - `listing-images` — `public: true` (per Q8 = A; RLS on `storage.objects` is the access filter); `file_size_limit: 10485760` (10 MB); `allowed_mime_types: ['image/jpeg']` (per Q4 = A — the FR-014 pipeline normalizes broader source formats to JPEG before upload, so the bucket never sees PNG/HEIC/WebP).
  - `listing-videos` — `public: true`; `file_size_limit: 31457280` (30 MB per IMPLEMENTATION_PLAN §Phase 11 cap); `allowed_mime_types: ['video/mp4']`.

- **One new BEFORE INSERT cap trigger**: `listing_media_cap_trigger` on `public.listing_media` per FR-004. The function counts existing rows for `(NEW.listing_id, NEW.kind)` and raises `SQLSTATE P0001` with MESSAGE `'listing_media.cap_exceeded'` + a DETAIL JSONB payload `{kind, current_count, max}` per R-30 when the cap would be exceeded. Caps: 10 for `kind='image'`; 2 for `kind IN ('video','external_link')` combined (Q2=D's defense-in-depth — the combined predicate readies the trigger for the future-spec external-link UI).

- **One new audit-trigger group** on `public.listing_media` via Phase 4's `log_audit()` unchanged (R-05 invariant preserved an **EIGHTH** time across Phases 4/5/6/7/8/9/10/11) emitting `listing_media.created` / `listing_media.updated` / `listing_media.deleted` action keys for row-level mutations. The `before_state` / `after_state` JSONB payloads include `{listing_id, kind, ordering, is_main, watermarked, storage_path, external_url}`.

- **One amended Phase 10 RPC**: `public.submit_listing(p_listing_id UUID) RETURNS JSONB` is re-emitted via migration 4's `CREATE OR REPLACE FUNCTION` with the Q1=A media-minimum check folded into the existing `v_missing` accumulator per R-31. The Phase 10 migration `20260519120007_create_submit_listing_rpc.sql` is NOT edited (immutability per R-35); migration 4 supersedes the function body. The amend places the new check between steps 4 and 6 of the Phase 10 body: `IF (SELECT count(*) FROM public.listing_media WHERE listing_id = p_listing_id AND kind = 'image' AND watermarked = true) = 0 THEN v_missing := array_append(v_missing, 'listing_media.images_below_minimum'); END IF;` — folded into the same `v_missing[]` array Phase 10 already populates, so the structured error payload absorbs the new key without an additional emission path. Q3=A's resubmit path also runs through this check at submit time.

- **Two new RLS policy bundles**: one per new policy domain, following Phase 6 R-02 inline-bundle-plus-parallel-file pattern.
  - `supabase/policies/listing_media_policies.sql` — mirror of the inline policies in migration 1: anon SELECT when `parent.status='approved'` + publish-window open; owner SELECT for any status of own listing; admin SELECT via `current_user_has_permission('listings.view_all')`; owner INSERT/UPDATE/DELETE during `draft|rejected` (composite check with `publisher_status='approved' AND account_status='approved'`); admin INSERT/UPDATE/DELETE via `listings.edit_any`.
  - `supabase/policies/listing_media_storage_policies.sql` — mirror of the inline policies in migration 3: six policies × two buckets = twelve total policies on `storage.objects` with the path-shape-enforcing `WITH CHECK` per R-27.

- **Zero new SQL views**. Phase 11's picker reads at most 10–12 `listing_media` rows per listing — direct SELECT against the table is cheaper than a view + LATERAL join. Phase 13's gallery view ships in Phase 13.

- **One new pubspec.yaml asset declaration**: `assets/images/watermark/logo_watermark.png` (PNG with alpha, ~512×128, the AlNujom wordmark + icon) bundled via the existing `flutter.assets` list. The SVG source lives at `docs/design/assets/watermark/logo_watermark.svg` for re-export at higher DPI.

- **One updated AndroidManifest.xml** at `android/app/src/main/AndroidManifest.xml` per Q5=A + FR-023: three new `<uses-permission>` declarations (`READ_EXTERNAL_STORAGE` with `android:maxSdkVersion="32"`, `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`). No CAMERA permission. No `permission_handler` package added (R-32 — `image_picker` handles version-aware runtime requests internally).

**Testing**: **Manual SQL inspection against the remote Supabase project via Supabase MCP `execute_sql` + `get_advisors` after each migration + manual UI verification on two devices (Infinix Note 8 for the legacy `READ_EXTERNAL_STORAGE` path + Pixel 8 Pro emulator for the granular `READ_MEDIA_IMAGES`/`READ_MEDIA_VIDEO` path per Q5 + SC-026 + R-34).** Per the durable session feedback (`feedback_no_new_tests.md`) and the spec's assumptions, this phase introduces NO new automated tests of any kind — including for the new `video_file_validator.dart`. The validator golden cases AND the watermark visual-confirmation cases AND the cap-trigger cases AND the storage-RLS deny cases are codified in `quickstart.md` as a manual-verification checklist. Build-time validation is preserved: Supabase's static SQL parser at `apply_migration` time catches syntax errors; Flutter's analyzer + the existing Phase 3 localization lint guard validate the new Dart files. Existing Phase 1–10 tests remain in source unchanged. The pubspec lock additions are verified via `flutter pub get` running cleanly.

**Target Platform**: Android 7.0+ (API 24+) for the Flutter side (Constitution XI); Supabase remote Postgres + Supabase Storage for the backend. iOS, Web, desktop NOT a target. The Q5 = A permission set spans API 24 through API 34+ via version-aware runtime requests.

**Project Type**: Mobile app + backend. Phase 11 does NOT introduce any new feature folders — every Flutter change lives inside Phase 10's existing `lib/features/listing_form/` (the MediaPicker is a step inside the existing seven-step form). The phase introduces one new file under `lib/core/validators/` (per R-18, validators continue to live there). It extends one existing BLoC (`ListingFormBloc` per R-40), one existing AndroidManifest.xml, one existing pubspec.yaml (per R-22 + R-37). It adds two new files under `assets/images/watermark/` + `docs/design/assets/watermark/`.

**Performance Goals**:

- MediaPicker mount on entering step 6: under 500 ms on the reference Infinix Note 8 (loads existing `listing_media` rows for the active listing — at most 12 rows per FR-005 caps; single round-trip).
- Image processing pipeline per image (Q4-resolved source-format normalization + Q6-resolved 8000×8000 cap check + EXIF strip + downscale + watermark composite + JPEG re-encode at quality 85): under 4 seconds on the Helio G80 for a 5 MB / 12 MP source JPEG. Per Q7=B, the per-image hard timeout is 60 seconds (covers the slow-network edge case where upload dominates the budget).
- Image upload to `listing-images` bucket: under 8 seconds per 5 MB image on a typical Syrian mobile data link (~700 kbps sustained). Sequential processing per R-25 means 8 images = ~45 seconds wall-clock matching US4's SC-001 budget.
- 10-image cap trigger fire latency: under 5 ms server-side (a single `SELECT count(*) FROM public.listing_media WHERE listing_id = NEW.listing_id AND kind = 'image'` against the existing `listing_id` index).
- Set-as-main + reorder UPDATE round-trip: under 200 ms server-side; under 500 ms total observed on device.
- Per-thumbnail Delete (storage remove + SQL DELETE per R-38): under 1.5 seconds on the reference device.
- Migration apply (four migrations) against the remote project: under 30 seconds total (bucket creation is the heaviest step; ~5 seconds per bucket as Supabase provisions the storage table rows; policies + trigger are negligible).
- `submit_listing` amended-RPC latency: under 250 ms server-side (Phase 10's body + one additional `SELECT count(*) FROM public.listing_media WHERE listing_id = ... AND kind='image' AND watermarked=true` against the existing `listing_id` index); under 1 second total observed on device.

**Constraints**:

- Constitution II (Source-Controlled Backend) binding: every backend artifact is a checked-in `.sql` file under `supabase/migrations/` or `supabase/policies/`. No Studio-only edits — including the bucket rows (Migration 2 issues SQL INSERTs against `storage.buckets` per R-26). Bucket policies are checked-in SQL per R-27. The watermark asset is checked into the repo at `assets/images/watermark/`.
- Constitution III (Security-First Supabase, NON-NEGOTIABLE): `public.listing_media` has RLS enabled. The `storage.objects` rows for both buckets have six policies per bucket per R-27 (twelve total Phase 11 storage policies). The cap trigger is a structural enforcement layer beyond RLS — admins cannot bypass the 10-image / 2-video caps. The Q4 = A pipeline fail-closes on watermark-asset-missing (FR-014 edge case). The Q5 = A AndroidManifest permission declaration is the only manifest change; no other permissions are added (no CAMERA, no INTERNET-changes — the latter is already declared by the base Flutter app). The Q6 = B pre-decode cap closes the OOM vector. The Q7 = B 60-second timeout closes the stuck-pipeline UX vector. The Q8 = A bucket public-mode is paired with strict RLS — the public flag alone is not the access boundary.
- Constitution V (Arabic-First Localization): every user-visible chrome string flows through `AppLocalizations`. ~20 new ARB keys cover picker CTAs, action-sheet labels, cap-exceeded messages, format/size/decode errors, the Q1=A `images_below_minimum` rejection message, the Q5 = A gallery-permission-denied message + "Open settings" CTA, the Q6 = B image-too-large message, the Q7 = B timeout message. No external-link / URL-host strings ship in Phase 11 per Q2 = D. Bilingual brand names (the AlNujom wordmark in the watermark asset) live as bundled binary assets, not ARB strings — the asset itself is locale-neutral.
- Constitution VI (Theme System & Design Tokens): every new widget under `lib/features/listing_form/presentation/widgets/` consumes Phase 2 design tokens. No inline hex / font-size / padding. The status-badge / chip styles for the picker grid reuse Phase 10's `status_badge.dart` / `chip_row.dart` if applicable.
- Constitution VII (Dynamic Roles & Permissions) preserved: no new permission key (FR-009 / R-15). Existing Phase 6 keys (`listings.view_all`, `listings.edit_any`) cover every admin surface; owner-default capabilities cover the publisher's own listings. The publisher-status three-layer enforcement helper at `lib/core/security/permission_checker.dart` from R-19 is consumed unchanged for the MediaPicker mount.
- Constitution VIII (Approval Workflow & Publisher Identity): the picker write-gate enforces the same composite as Phase 10's `listings` write policy — `auth.uid()=parent.publisher_user_id` AND `publisher_status='approved'` AND `account_status='approved'` AND `parent.status IN ('draft','rejected')`. Non-approved publishers cannot upload media (UX tile hide + datasource RLS deny). The picker is hidden / read-only when `parent.status NOT IN ('draft','rejected')`.
- Constitution IX (Future Backend Portability): `lib/features/listing_form/domain/` continues to be Supabase-free; the new use cases (`UploadImage`, `UploadVideo`, etc.) are abstract Dart classes. Only `lib/features/listing_form/data/datasources/supabase_listing_media_datasource.dart` (new) and `data/repositories/listings_repository_impl.dart` (extended) touch Supabase types. The three new pubspec packages (`image_picker`, `image`, `flutter_image_compress`) are framework-agnostic Dart/Flutter packages; the FR-014 pipeline does not import `package:supabase_flutter`.
- Migrations apply to the **remote** Supabase project via Supabase MCP `apply_migration` (inherited from Phase 4 R-01).
- Migrations MUST be idempotent (`CREATE TABLE IF NOT EXISTS`, `CREATE OR REPLACE FUNCTION`, `DROP TRIGGER IF EXISTS ... CREATE TRIGGER`, `DROP POLICY IF EXISTS ... CREATE POLICY`, bucket creation via `ON CONFLICT (id) DO UPDATE` per R-26). The project memory `project_supabase_mcp_apply_migration.md` is binding — re-applying a migration name re-runs the SQL AND adds a duplicate tracker row, so each Phase 11 migration name is unique.
- The `log_audit()` reusable trigger function is invoked unchanged for the new audit-trigger group on `public.listing_media` (R-05 invariant preserved an **EIGHTH** time across Phases 4/5/6/7/8/9/10/11).
- **Three new packages** in `pubspec.yaml` per R-22 — the first relaxation of Phase 10's R-03 zero-new-packages invariant. Justified by Q4=A's HEIC normalization requirement.
- No new permission keys (FR-009 / R-15).
- No iOS-only code (Constitution XI).

**Scale/Scope**:

- **Four new SQL migration files** under `supabase/migrations/` named with synthetic-monotonic 14-digit timestamps `20260522120001` through `20260522120004`, ordered after Phase 10 (final Phase 10 migration on remote per spec 010 DEFERRED.md walk-through: `20260519120012_fix_submit_listing_array_append`). The four migrations:

  1. `20260522120001_create_listing_media.sql` — `CREATE TABLE public.listing_media` per the 10-column shape; `ENABLE ROW LEVEL SECURITY`; attach Phase 4's `set_updated_at` trigger; attach `listing_media_cap_trigger` (BEFORE INSERT, the body per R-30); attach Phase 4's `log_audit` audit-trigger group emitting `listing_media.created/.updated/.deleted` per R-05; create the partial unique index `listing_media_one_main_idx` per FR-003; bundle inline + parallel-file RLS policies per FR-006. (FR-001, FR-002, FR-003, FR-004, FR-005, FR-006.)
  2. `20260522120002_create_listing_media_storage_buckets.sql` — `INSERT INTO storage.buckets` per R-26 for `listing-images` AND `listing-videos` with `public: true`, `file_size_limit`, `allowed_mime_types` per FR-008. Idempotent via `ON CONFLICT (id) DO UPDATE`. (FR-008, SC-029.)
  3. `20260522120003_create_listing_media_storage_policies.sql` — Twelve policies on `storage.objects` per R-27 (six per bucket × two buckets): anon SELECT when parent approved + publish-window open; owner SELECT; admin SELECT; owner INSERT/UPDATE/DELETE during draft|rejected; admin INSERT/UPDATE/DELETE. The owner INSERT policy carries a `WITH CHECK` enforcing the path-shape `^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/.+$` per R-27. (FR-007, SC-008, SC-009, SC-025.)
  4. `20260522120004_amend_submit_listing_rpc_for_media_minimum.sql` — `CREATE OR REPLACE FUNCTION public.submit_listing(p_listing_id UUID) RETURNS JSONB LANGUAGE plpgsql VOLATILE SECURITY DEFINER SET search_path=public,auth` with the full Phase 10 body + the R-31 media-minimum check inserted between Phase 10's `v_missing` accumulator and the IF-RAISE block. Phase 10's migration `20260519120007_create_submit_listing_rpc.sql` is NOT edited per R-35. (FR-022, SC-017.)

- **Two new policy files** under `supabase/policies/`: `listing_media_policies.sql` (mirror of migration 1's inline policies) and `listing_media_storage_policies.sql` (mirror of migration 3's inline policies). Per the Phase 6 R-02 invariant — policies live in both source-of-truth files AND inline in the migration. Phase 4/5/6/7/8/9/10 policy files are NOT edited.

- **One new doc file** + **two updated doc files** under `supabase/docs/`:
  - `listing_media.md` — NEW — describes the new table, RLS posture, cap trigger, audit-trigger emission, two-step storage-cleanup pattern (R-28 / R-38).
  - `audit_logs.md` — UPDATE — enumerate the three new action keys (`listing_media.created/.updated/.deleted`).
  - `listings.md` — UPDATE — note that `submit_listing` now performs the Q1=A media-minimum check (cross-reference Phase 11 FR-022); the underlying table is unchanged in Phase 11.

- **One updated existing feature folder** under `lib/features/listing_form/`:
  - `data/datasources/supabase_listing_media_datasource.dart` — NEW — only Phase 11 file importing `package:supabase_flutter` from the feature side. Exposes `loadMediaForListing`, `uploadImage(file, listingId)`, `uploadVideo(file, listingId)`, `reorder(listingId, newOrder)`, `setMain(id)`, `delete(id)` — all of which delegate to the Supabase Storage SDK + the table CRUD.
  - `data/dtos/listing_media_dto.dart` — NEW — DTO matching the table column shape.
  - `data/repositories/listings_repository_impl.dart` — EXTEND — gains six new method implementations corresponding to the new use cases. The Phase 10 file is edited in place.
  - `domain/entities/listing_media.dart` — NEW — entity carrying `id`, `listingId`, `kind`, `storagePath`, `externalUrl`, `ordering`, `isMain`, `watermarked`, `createdAt`. Two enum values for `kind` ship: `image`, `video` (per Q2=D the `external_link` enum value is documented in the data-model.md but NOT in the Dart entity to keep the surface narrow; admin direct SQL inserts of `external_link` rows would deserialize as an unknown enum value — handled gracefully in the picker as a broken-image placeholder).
  - `domain/repositories/listings_repository.dart` — EXTEND — gains the six new abstract methods. Phase 10 file edited in place.
  - `domain/usecases/upload_image.dart`, `upload_video.dart`, `reorder_media.dart`, `set_main_image.dart`, `delete_media.dart`, `load_media_for_listing.dart` — SIX NEW use case files.
  - `presentation/bloc/listing_form_bloc.dart` — EXTEND per R-40 — gains five new event types (`MediaPicked`, `VideoPicked`, `MediaReordered`, `MediaSetMain`, `MediaDeleted`) and the state object gains a `List<ListingMedia> media` field. Phase 10 file edited in place.
  - `presentation/widgets/step_media_placeholder.dart` — DELETE (replaced by `step_media.dart` which mounts the MediaPicker).
  - `presentation/widgets/step_media.dart` — NEW — the step-6 container widget; mounts the `MediaPicker` reusable widget plus the upload-affordances row ("Add images" + "Add video" CTAs per FR-010).
  - `presentation/widgets/media_picker.dart` — NEW — the reusable picker grid widget with per-thumbnail actions (set-main, delete, drag-reorder); reads media state from `ListingFormBloc` via `BlocSelector`.
  - `presentation/widgets/media_thumbnail.dart` — NEW — per-thumbnail card widget with the main badge, ordering badge, action sheet, error/progress states.
  - `presentation/util/watermark_pipeline.dart` — NEW — the FR-014 pipeline runner (header read, decode, EXIF strip, downscale, watermark composite, re-encode). Pure Dart; runs on the R-25 shared isolate worker.
  - `presentation/util/image_isolate_worker.dart` — NEW — the R-25 shared isolate worker entry point; pulls jobs from a `StreamQueue` and runs `watermark_pipeline` per job.
  - `presentation/util/image_header_reader.dart` — NEW — the R-24 header-only dimension reader.

- **One new directory addition under `lib/core/validators/`**:
  - `video_file_validator.dart` — NEW — validates MP4 mime + ≤ 30 MB byte count per FR-017.

- **One updated existing routing file**:
  - The MediaPicker mounts inside the existing Phase 10 `/publisher/listings/<id>/edit` route — no new go_router route is registered in Phase 11. The Phase 10 `auth_redirect.dart` publisher-status guard already covers the picker access. NO change to `lib/app.dart` or `lib/core/routing/`.

- **One updated `lib/core/security/permission_checker.dart`**: NO CHANGE — Phase 10's `userIsApprovedPublisher` helper is consumed unchanged per R-19.

- **One updated AndroidManifest.xml** at `android/app/src/main/AndroidManifest.xml` per Q5=A + FR-023 (R-32): three new `<uses-permission>` declarations. No other manifest changes.

- **Two new asset files** + **one updated existing asset declaration**:
  - `assets/images/watermark/logo_watermark.png` — NEW — the bundled watermark asset (R-23 + R-33).
  - `docs/design/assets/watermark/logo_watermark.svg` — NEW — source SVG for re-export.
  - `pubspec.yaml` — UPDATE — adds the three new packages per R-22 AND adds `assets/images/watermark/` (or the broader `assets/images/`) to the existing `flutter.assets` list if not already covered. The `pubspec.lock` is regenerated per R-37.

- **ARB key delta** on `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb`: approximately 20 new strings — picker CTAs (`media.addImages`, `media.addVideo`); action-sheet labels (`media.action.setMain`, `media.action.delete`, `media.action.reorderHint`); cap-exceeded messages (`media.cap.images10`, `media.cap.videos2`); format / size / decode errors (`media.error.formatNotSupported`, `media.error.imageTooLarge`, `media.error.timeout`, `media.error.uploadFailed`, `media.error.videoSizeExceeded`, `media.error.videoFormatMustBeMp4`, `media.error.galleryPermissionDenied`, `media.action.openSettings`); the `submit_listing` Q1=A error message (`submit.error.imagesBelowMinimum`); read-only-when-pending-or-approved message (`media.readOnly.pendingOrApproved`); watermark-asset-missing fail-soft (`media.error.watermarkAssetMissing`); the Q4=A image-format-not-supported message reuses `media.error.formatNotSupported`. All keys ship to both ARB files in the same commit per Phase 3's localization gate.

- **Three new packages** in `pubspec.yaml` per R-22 (first deviation from Phase 10's R-03).

- **0 new tests** (durable no-new-tests rule).

- **0 changes** to `.github/workflows/ci.yml`.

## Constitution Check

*GATE: All 12 principles evaluated. No violations.*

| Principle | Status | Notes |
|---|---|---|
| I. Spec-First Development (NON-NEGOTIABLE) | **Pass** | `spec.md` exists with 7 user stories, 23 FRs (FR-001..FR-023), 29 SCs (SC-001..SC-029); `/speckit-clarify` Session 2026-05-22 resolved 5 additional questions (Q4 image formats, Q5 Android permissions, Q6 8000×8000 cap, Q7 60s timeout, Q8 public bucket + RLS) on top of the 3 resolved during `/speckit-specify` (Q1 ≥1 image, Q2 disable external_link, Q3 edit-in-place). No implementation has begun. |
| II. Source-Controlled Backend | **Pass** | Every Phase 11 backend artifact lives as a checked-in file: 4 migrations under `supabase/migrations/`, 2 new policy files under `supabase/policies/`, 1 new + 2 updated doc files under `supabase/docs/`. Bucket creation is via SQL INSERT (R-26), not Studio. The amended `submit_listing` body is checked in as migration 4 — the Phase 10 migration file remains unedited per R-35. The watermark asset is checked into the repo at `assets/images/watermark/`. No artifact lives only in Studio. |
| III. Security-First Supabase (NON-NEGOTIABLE) | **Pass** | RLS is enabled on the new `public.listing_media` table. Twelve new policies on `storage.objects` (six per bucket × two buckets) enforce the same parent-status gate per R-27. The 10-image / 2-video caps are structural (BEFORE INSERT trigger) — admins cannot bypass. The Q4 = A pipeline fail-closes on watermark-asset-missing per FR-014 edge case. Q5 = A's permission set is the minimum necessary for the picker affordance — no `INTERNET`/`CAMERA`/`ACCESS_FINE_LOCATION` are added. Q6 = B's pre-decode cap closes the OOM-via-large-image vector. Q7 = B's 60-second timeout closes the stuck-pipeline UX vector. Q8 = A's `public: true` buckets are paired with strict RLS — the public flag is not the access boundary. No new anonymous-SELECT carve-out (Phase 10 R-04 invariant preserved — Phase 11 inherits the Phase 10 listings public-read gate via the parent join). The amended `submit_listing` re-checks every Phase 10 precondition AND the Q1=A media-minimum check inside its body — the RPC is `SECURITY DEFINER` but does not trust the caller's claimed media count. |
| IV. Clean Architecture Flutter | **Pass** | All new Dart code lives in Phase 10's `lib/features/listing_form/` honoring the three-layer split: new use cases under `domain/usecases/`, new entity under `domain/entities/`, new datasource + DTO under `data/`, new presentation widgets under `presentation/widgets/`. The FR-014 pipeline lives in `presentation/util/` because it consumes picker UI state (progress callbacks); the pure decode/encode helpers live in `image_isolate_worker.dart` which runs on a background isolate. No widget calls Supabase; no use case imports Supabase. The new validator under `lib/core/validators/` is pure Dart per R-18. The `ListingFormBloc` extension per R-40 keeps the single-owner-of-form-state invariant from Phase 10. |
| V. Arabic-First Localization | **Pass** | All ~20 new user-visible chrome strings flow through Phase 3's `AppLocalizations`. The watermark asset itself is a bundled binary asset (locale-neutral wordmark); no ARB key for the visual watermark. RTL is honored: the picker grid uses `EdgeInsetsDirectional`; the watermark is composited at the "bottom-end" corner which translates to bottom-right in LTR and bottom-left in RTL per R-23. The Phase 3 localization lint guard catches any hardcoded user-facing string at PR review. |
| VI. Theme System & Design Tokens | **Pass** | Every new widget under `lib/features/listing_form/presentation/widgets/` consumes Phase 2's design tokens. The thumbnail-error state uses Phase 2's `dangerContainer` color; the main-badge uses `successContainer`; the progress spinner uses `primaryFixed`. No inline hex / font-size / padding. |
| VII. Dynamic Roles & Permissions | **Pass** | Phase 11 introduces zero new permission keys (FR-009 / R-15). The existing Phase 6 keys (`listings.view_all`, `listings.edit_any`) cover every admin surface. The publisher-status three-layer enforcement helper at `lib/core/security/permission_checker.dart` is consumed unchanged per R-19. Audit emission is universal: three new action keys (`listing_media.created/.updated/.deleted`) cover every mutation path through the new table. |
| VIII. Approval Workflow & Publisher Identity | **Pass** | The MediaPicker write gate enforces the same composite as Phase 10's `listings` write policy: `auth.uid()=parent.publisher_user_id` AND `publisher_status='approved'` AND `account_status='approved'` AND `parent.status IN ('draft','rejected')`. Non-approved publishers cannot upload media. The Q1 = A `submit_listing` strengthening adds the media-minimum check to the publisher-side workflow — listings now require ≥1 image before reaching the Phase 12 admin queue. The Q3 = A resubmit path preserves the publisher's prior watermarked work, lowering re-upload friction. The Q5 = A permission model declares only what's needed for the gallery affordance — no over-permission. |
| IX. Future Backend Portability | **Pass** | `lib/features/listing_form/domain/` continues to import nothing from `package:supabase_flutter` — the six new use cases are abstract Dart classes. Only `data/datasources/supabase_listing_media_datasource.dart` (new) and the extended `data/repositories/listings_repository_impl.dart` touch Supabase types. The three new pubspec packages (`image_picker`, `image`, `flutter_image_compress`) are framework-agnostic; the FR-014 pipeline does not import `package:supabase_flutter`. The `image_picker` plugin returns generic `XFile` references the datasource resolves to bytes; the `image` package operates on `Uint8List`; `flutter_image_compress` operates on file paths or bytes. None of these surface Supabase types into the domain layer. |
| X. Testable AI Workflow | **Pass — Justified.** | Per `feedback_no_new_tests.md` carried forward from Phases 3–10, every FR is verifiable via a manual SQL action with expected output OR via Supabase MCP `execute_sql` / `list_tables` / `get_advisors` calls OR via a two-device manual UI walk on the Infinix Note 8 + Pixel 8 Pro emulator. The validator golden cases (`video_file_validator`) AND the watermark visual-confirmation cases AND the cap-trigger cases AND the storage-RLS deny cases AND the Q5 = A permission-path verification on both Android-version code paths are codified in `quickstart.md` as a manual-verification checklist. The constitution explicitly permits "a SQL query with expected output" or "a UI action with expected screen state" as acceptance steps. No constitutional amendment is required. |
| XI. Android-First MVP | **Pass** | All Flutter additions target the Android Flutter build only. No platform-conditional code. The three new packages (`image_picker`, `image`, `flutter_image_compress`) all have Android support; none require iOS-only configuration. `flutter_image_compress`'s Android side bundles libheif; no iOS native artifact is added. The AndroidManifest update per Q5 = A is Android-specific by definition. The R-34 two-device walk includes the Infinix Note 8 + the Pixel 8 Pro emulator (Android 14) — both Android targets; no iOS path is exercised. |
| XII. No Hidden Product Decisions | **Pass** | All eight Session 2026-05-22 clarifications (Q1 through Q8) are captured in `spec.md` `## Clarifications`. The R-22 pubspec deviation from Phase 10's R-03 zero-new-packages invariant is recorded explicitly in research with the justification (Q4 = A HEIC support). The R-23 watermark exact opacity / position is documented in research; the spec captures only the visual outcome. The R-34 two-device commitment is recorded in research; SC-026 is the verifiable mirror. The R-35 immutable-Phase-10-migration + `CREATE OR REPLACE`-via-new-migration pattern is documented in research; the data-model.md will carry the full amended function body verbatim. Every decision is in research + data-model + spec; nothing lives only in conversation. |

**Result**: All gates pass. `## Complexity Tracking` is empty.

## Project Structure

### Documentation (this feature)

```text
specs/011-media-watermark/
├── plan.md                              # This file (/speckit-plan output)
├── research.md                          # Phase 0 — 20 locked tech decisions (R-21..R-40 — picks up from Phase 10 R-20)
├── data-model.md                        # Phase 1 — the 1 new table + 2 new buckets + 6×2 storage policies + 1 cap trigger + 1 audit trigger + 1 amended RPC body + Flutter entity / DTO / use-case shapes + ARB key inventory + per-FR / per-SC verification map
├── quickstart.md                        # Phase 1 — manual verification recipe: 4-migration apply + bucket + storage-policy verification + Infinix Note 8 device walk + Pixel 8 Pro emulator walk for Q5 permission coverage + SC matrix
├── contracts/                           # Phase 1 — 10 interface contracts
│   ├── phase11-listing-media-table.md           # NEW — column shape, CHECK constraints, partial unique index, RLS-enabled state
│   ├── phase11-storage-buckets.md               # NEW — bucket configs (public: true, file_size_limit, allowed_mime_types per Q4/Q8)
│   ├── phase11-storage-policies.md              # NEW — 12 policies on storage.objects (6 per bucket × 2 buckets) with path-shape WITH CHECK enforcement per R-27
│   ├── phase11-cap-trigger.md                   # NEW — listing_media_cap_trigger contract: BEFORE INSERT; SQLSTATE P0001 + DETAIL JSONB shape per R-30
│   ├── phase11-audit-triggers.md                # NEW — log_audit() reuse for the 3 new action keys (listing_media.created/.updated/.deleted) per R-05 + the 8th-time-unchanged invariant
│   ├── phase11-rls-policies.md                  # NEW — listing_media RLS policy inventory: anon-when-approved + owner + admin + composite write-gate
│   ├── submit-listing-amendment.md              # NEW — the Q1=A FR-022 amendment via migration 4: CREATE OR REPLACE delta carrying the Phase 10 body + the media-minimum check per R-31 + R-35 immutability invariant
│   ├── media-picker-pages.md                    # NEW — step_media + media_picker + media_thumbnail widgets; BLoC event surface (R-40); per-Q-resolution enforcement
│   ├── watermark-pipeline.md                    # NEW — FR-014 7-step pipeline contract: format detect (Q4), header dimension cap (Q6 / R-24), decode, EXIF strip, downscale, composite, JPEG re-encode, upload; R-23 watermark params; R-25 isolate worker model
│   └── video-file-validator.md                  # NEW — FR-017 validator API + golden inputs/outputs (mp4 vs mov/mkv; under-cap vs over-cap byte counts)
├── checklists/
│   └── requirements.md                  # From /speckit-specify + /speckit-clarify (all 8 Qs resolved; checklist fully green)
├── spec.md                              # From /speckit-specify + /speckit-clarify (Q1=A min 1 image, Q2=D no external_link, Q3=A edit-in-place, Q4=A format normalization, Q5=A version-aware permissions, Q6=B 8000px cap, Q7=B 60s timeout, Q8=A public bucket + RLS)
├── tasks.md                             # Created by /speckit-tasks (NOT by /speckit-plan)
├── DEFERRED.md                          # Created during /speckit-implement; reviewed at squash-merge per project_deferred_work.md
└── HANDOFF.md                           # Created at /speckit-implement close-out (or omit if no follow-up scope)
```

### Source Code (repository root)

```text
supabase/
├── config.toml                                                            # (existing) NO CHANGE.
├── seed.sql                                                               # (existing) NO CHANGE — Phase 11 seeds zero rows.
├── migrations/
│   ├── (existing Phase 1/4/5/6/7/8/9/10 migrations)                       # NO CHANGE.
│   ├── 20260522120001_create_listing_media.sql                            # NEW — CREATE TABLE public.listing_media + CHECK constraints + partial unique index + set_updated_at + listing_media_cap_trigger + log_audit trigger group + inline-bundled RLS policies. (FR-001..FR-006, SC-007.)
│   ├── 20260522120002_create_listing_media_storage_buckets.sql            # NEW — INSERT INTO storage.buckets for listing-images + listing-videos with public: true + file_size_limit + allowed_mime_types. Idempotent via ON CONFLICT. (FR-008, SC-029.)
│   ├── 20260522120003_create_listing_media_storage_policies.sql           # NEW — 12 policies on storage.objects (6 per bucket × 2 buckets) per R-27, with path-shape WITH CHECK enforcement. (FR-007, SC-008, SC-009, SC-025.)
│   └── 20260522120004_amend_submit_listing_rpc_for_media_minimum.sql      # NEW — CREATE OR REPLACE public.submit_listing(...) with the Phase 10 body + the Q1=A media-minimum check folded into v_missing per R-31. Phase 10 migration 20260519120007 remains unedited per R-35. (FR-022, SC-017.)
├── policies/                                                              # (existing dir)
│   ├── (existing Phase 4..10 policy files)                                # NO CHANGE.
│   ├── listing_media_policies.sql                                         # NEW — mirror of migration 1's inline policies.
│   └── listing_media_storage_policies.sql                                 # NEW — mirror of migration 3's inline policies.
├── functions/                                                             # (existing dir)
│   └── (existing Phase 5/7 functions)                                     # NO CHANGE — Phase 11 introduces no Edge Functions per R-36.
└── docs/                                                                  # (existing dir)
    ├── (existing Phase 4..10 doc files)                                   # NO CHANGE except audit_logs.md + listings.md (cross-reference notes).
    ├── audit_logs.md                                                      # UPDATE — enumerate the 3 new action keys: listing_media.created/.updated/.deleted.
    ├── listings.md                                                        # UPDATE — note that submit_listing now performs the Q1=A media-minimum check (cross-reference Phase 11 FR-022); underlying table unchanged.
    └── listing_media.md                                                   # NEW — describes the new table, RLS posture, cap trigger, audit-trigger emission, 2-step storage-cleanup ordering (R-28 / R-38), Q1..Q8 surface alignment.

lib/
├── main.dart                                                              # (existing) NO CHANGE.
├── app.dart                                                               # NO CHANGE — Phase 11 registers no new go_router routes; the MediaPicker mounts inside Phase 10's /publisher/listings/<id>/edit route.
├── core/                                                                  # (existing)
│   ├── di/
│   │   ├── injection.dart                                                 # NO CHANGE.
│   │   └── injection.config.dart                                          # AUTO-REGEN — codegen adds entries for the new datasource + 6 new use cases.
│   ├── routing/
│   │   └── auth_redirect.dart                                             # NO CHANGE — Phase 10's publisher-status guard already covers /publisher/listings/<id>/edit; the MediaPicker is a step inside that route.
│   ├── security/
│   │   └── permission_checker.dart                                        # NO CHANGE — userIsApprovedPublisher helper consumed unchanged per R-19.
│   └── validators/
│       └── video_file_validator.dart                                      # NEW — MP4 mime + ≤30 MB byte count per FR-017.
├── shared/                                                                # (existing — Phase 9)
│   └── (no changes — MoneyFormatter, Money value object unchanged)
├── features/
│   ├── admin/                                                             # (existing) NO CHANGE — Phase 12 owns the admin listing-review surface.
│   ├── auth/                                                              # NO CHANGE.
│   ├── currencies/                                                        # NO CHANGE.
│   ├── home/                                                              # NO CHANGE.
│   ├── locations/                                                         # NO CHANGE.
│   ├── onboarding/                                                        # NO CHANGE.
│   ├── profile/                                                           # NO CHANGE.
│   ├── publisher_dashboard/                                               # (existing — Phase 10) NO CHANGE.
│   ├── super_admin/                                                       # NO CHANGE.
│   └── listing_form/                                                      # (existing — Phase 10) — EXTENDED in Phase 11.
│       ├── data/
│       │   ├── datasources/
│       │   │   ├── supabase_listings_datasource.dart                      # (existing — Phase 10) NO CHANGE.
│       │   │   └── supabase_listing_media_datasource.dart                 # NEW — Phase 11's only Supabase-touching datasource: storage.from(bucket).upload/remove/getPublicUrl + listing_media CRUD. (FR-012.)
│       │   ├── dtos/
│       │   │   ├── (existing Phase 10 DTOs)                               # NO CHANGE.
│       │   │   └── listing_media_dto.dart                                 # NEW — column-shape DTO matching public.listing_media.
│       │   └── repositories/
│       │       └── listings_repository_impl.dart                          # EXTEND — gains 6 method impls for the new use cases. Phase 10 file edited in place.
│       ├── domain/
│       │   ├── entities/
│       │   │   ├── (existing Phase 10 entities)                           # NO CHANGE.
│       │   │   └── listing_media.dart                                     # NEW — entity with two-value enum (image | video; external_link omitted from Dart side per Q2=D).
│       │   ├── repositories/
│       │   │   └── listings_repository.dart                               # EXTEND — gains 6 abstract methods. Phase 10 file edited in place.
│       │   └── usecases/
│       │       ├── (existing Phase 10 use cases)                          # NO CHANGE.
│       │       ├── upload_image.dart                                      # NEW — runs the FR-014 pipeline + atomic-upload-then-insert per FR-015.
│       │       ├── upload_video.dart                                      # NEW — runs the FR-017 validator + atomic-upload-then-insert.
│       │       ├── reorder_media.dart                                     # NEW — single transactional UPDATE re-sequencing `ordering`.
│       │       ├── set_main_image.dart                                    # NEW — UPDATE is_main=true on target + false on previous main; partial unique index serializes server-side.
│       │       ├── delete_media.dart                                      # NEW — storage remove → row DELETE per R-38 ordering.
│       │       └── load_media_for_listing.dart                            # NEW — SELECT * FROM public.listing_media WHERE listing_id = $1 ORDER BY ordering ASC.
│       └── presentation/
│           ├── bloc/
│           │   └── listing_form_bloc.dart                                 # EXTEND per R-40 — gains 5 new events (MediaPicked, VideoPicked, MediaReordered, MediaSetMain, MediaDeleted); state object gains `List<ListingMedia> media` field. Phase 10 file edited in place.
│           ├── pages/
│           │   └── listing_form_page.dart                                 # (existing — Phase 10) NO CHANGE — step container unchanged; step 6 swaps its content via the Phase 10 step-router which routes to step_media.dart now.
│           ├── util/
│           │   ├── watermark_pipeline.dart                                # NEW — FR-014 7-step pipeline runner (header check, decode, EXIF strip, downscale, composite, re-encode). Pure Dart; runs on the R-25 isolate.
│           │   ├── image_isolate_worker.dart                              # NEW — R-25 shared sequential isolate worker entry point.
│           │   └── image_header_reader.dart                               # NEW — R-24 header-only dimension reader covering JPEG/PNG/HEIC/WebP.
│           └── widgets/
│               ├── (existing Phase 10 widgets)                            # NO CHANGE except step_media_placeholder.dart is DELETED.
│               ├── step_media_placeholder.dart                            # DELETE — replaced by step_media.dart.
│               ├── step_media.dart                                        # NEW — step-6 container; mounts MediaPicker + the upload affordance row (Add images + Add video CTAs) per FR-010.
│               ├── media_picker.dart                                      # NEW — reusable picker grid widget; reads `media` slice from ListingFormBloc.
│               └── media_thumbnail.dart                                   # NEW — per-thumbnail card: main badge, ordering badge, action sheet, error/progress states; long-press action sheet hides set-main for video rows per FR-013.
└── l10n/                                                                  # (existing)
    ├── app_ar.arb                                                         # UPDATE — add ~20 new ARB keys per FR-019 (picker CTAs, action labels, cap-exceeded messages, format/size/decode errors, Q1=A images_below_minimum, Q5=A gallery permission denied + Open settings, Q6=B image too large, Q7=B timeout, watermark asset missing).
    └── app_en.arb                                                         # UPDATE — add the same ~20 keys in English. Both files updated in the same commit per Phase 3 localization gate.

android/
└── app/
    └── src/
        └── main/
            └── AndroidManifest.xml                                        # UPDATE per Q5=A + FR-023 + R-32: 3 new <uses-permission> declarations (READ_EXTERNAL_STORAGE with maxSdkVersion=32, READ_MEDIA_IMAGES, READ_MEDIA_VIDEO).

assets/
└── images/
    └── watermark/
        └── logo_watermark.png                                             # NEW — bundled watermark asset (~512×128 PNG with alpha) per R-23 + R-33.

docs/
└── design/
    └── assets/
        └── watermark/
            └── logo_watermark.svg                                         # NEW — source SVG for re-export at higher DPI.

pubspec.yaml                                                               # UPDATE — adds 3 new packages (image_picker, image, flutter_image_compress) per R-22; declares assets/images/watermark/ in flutter.assets if not already covered by an existing globpattern.
pubspec.lock                                                               # REGENERATE via flutter pub get; ~12 new transitive entries per R-37.
```

**Structure Decision**: The feature follows the project's established Mobile + Backend pattern. Backend artifacts (4 migrations + 2 policy files + 1 new + 2 updated doc files) live under `supabase/`. Flutter artifacts extend Phase 10's existing `lib/features/listing_form/` rather than introducing a new feature folder — the MediaPicker is a step inside the existing seven-step form, not a standalone surface. The single new validator lives at `lib/core/validators/video_file_validator.dart` per R-18. The watermark asset bundling lives at `assets/images/watermark/`. The AndroidManifest update per Q5=A is the first Phase 11 platform-side change beyond Dart code. The three new pubspec packages are the first Phase 10 R-03 deviation. The `submit_listing` amendment (migration 4) is the first cross-spec backend amendment in the project — Phase 11 amends a Phase 10 artifact without editing Phase 10's migration file, preserving the source-control immutability invariant from R-35.

## Complexity Tracking

> **No constitutional violations. This section is intentionally empty.**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| (none) | — | — |
