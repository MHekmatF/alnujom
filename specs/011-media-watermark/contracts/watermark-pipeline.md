# Contract: FR-014 watermark + downscale + upload pipeline

**Source FRs**: FR-014, FR-015, FR-016 | **Q-resolutions**: Q4=A, Q6=B, Q7=B | **Research**: R-23, R-24, R-25, R-33, R-39 | **Source-of-truth**: [data-model.md §8.7](../data-model.md#87-watermark-pipeline--libfeatureslisting_formpresentationutilwatermark_pipelinedart)

## Pipeline steps (FR-014)

| Step | Operation | Failure mode |
|---|---|---|
| (a) | Format-detect from MIME + magic bytes; accept set = {JPEG, PNG, HEIC, HEIF, WebP} per Q4 | Reject with `media.error.formatNotSupported` |
| (a-pre) | Header-only dimension read per R-24; reject if `width > 8000` OR `height > 8000` per Q6 | Reject with `media.error.imageTooLarge` |
| (b) | Decode source to raw RGBA pixels (HEIC via `flutter_image_compress` per R-22) | OOM → catch in BLoC; surface Retry per spec edge case |
| (c) | Apply EXIF orientation + strip EXIF block | Privacy invariant: no GPS / camera-make / camera-model survives |
| (d) | Downscale so long edge ≤ 1920 px; skip if already ≤ 1920 | — |
| (e) | Composite AlNujom logo per R-23 params | If watermark asset missing → fail closed with `media.error.watermarkAssetMissing` |
| (f) | Re-encode as JPEG quality 85 | — |
| (g) | Upload to `listing-images` bucket at `<listing_id>/<ordering>_<rand>.jpg` | Retry 2× exponential backoff (1s, 4s); on 3rd fail → Retry button |

## R-23 watermark parameters (locked at plan-time)

| Param | Value |
|---|---|
| Position | Bottom-end corner (RTL-aware: bottom-right in LTR, bottom-left in RTL) |
| Opacity | 0.15 (15%) |
| Size | 18% of image long-edge dimension |
| Padding (from outside edge + bottom) | 24 px constant |
| Aspect-ratio cap | `min(18% of long edge, 50% of short edge)` for panorama / extreme aspect ratios |

## R-24 header-reader contract

`Future<ImageDimensions?> readImageDimensions(Uint8List bytes, ImageFormat format)`:
- JPEG: walks SOF0 marker (start-of-frame baseline).
- PNG: reads IHDR chunk (always at byte offset 16).
- HEIC/HEIF: parses `ispe` (image spatial extent) box via `flutter_image_compress` metadata API.
- WebP: reads VP8X chunk dimensions.
- Returns `null` on corrupt header → caller surfaces format-not-supported.

Reads only the first ~64 bytes (or ~256 for HEIC) — constant cost regardless of source file size.

## R-25 isolate model

- Single sequential isolate worker spawned at `MediaPicker.initState()` (or first `MediaPicked` event handle).
- Pulls jobs from `StreamQueue<_ImageProcessingJob>` written by the BLoC.
- Sequential execution (one job at a time) bounds peak RAM at ~100 MB (one decoded image + watermark buffer + JPEG re-encode buffer).
- Worker terminates on picker dispose / route exit.

## R-39 timeout enforcement (Q7=B)

The BLoC's `MediaPicked` handler wraps each file's `Future`:
```dart
Future.value(_processImage(file)).timeout(
  const Duration(seconds: 60),
  onTimeout: () { /* cancel isolate job, remove partial bucket object, surface media.error.timeout */ },
);
```

The 60s budget covers: header read + decode + EXIF strip + downscale + composite + JPEG re-encode + upload + retries (1s + 4s backoff).

## FR-015 atomic-from-publisher-perspective

Pipeline is atomic from the publisher's view:
1. Pipeline succeeds → bucket object exists + `listing_media` row INSERTed.
2. Pipeline fails at any step before the INSERT → no bucket object, no row.
3. INSERT fails (e.g., cap trigger fires due to concurrent upload from another device) → datasource issues `storage.remove()` on the just-uploaded object before surfacing the error.

There is never a `listing_media` row pointing to a missing bucket object (the FR-005 audit row would lie). There may, in pathological cases (process kill mid-upload), be a bucket object without a row — those orphans are forward-stated to Phase 23 reconciliation per R-28.

## FR-016 watermarked flag

After successful pipeline, the datasource INSERTs with `watermarked: true`. This is the bit Q1=A FR-022 checks. Failed-watermark uploads never happen — the pipeline fails closed on missing asset (R-33).

## Verification

| SC | Test |
|---|---|
| SC-002 | Download 5 bucket objects; `exiftool` shows long edge ≤ 1920 |
| SC-003 | Visual inspection of 5 bucket objects for watermark visibility at bottom-end corner |
| SC-011 | Frame-time overlay during 8-image batch on Infinix Note 8 — confirm ≥ 30 fps |
| SC-024 | Download 5 bucket objects; `exiftool` reports 0 GPS / camera-make / camera-model fields |
| SC-027 | Pick 9000×9000 test image; picker rejects pre-decode |
| SC-028 | Throttle network to 50 kbps; pick 5 MB JPEG; timeout-error after ~60s |
