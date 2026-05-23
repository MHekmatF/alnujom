# Contract: MediaPicker — step_media + media_picker + media_thumbnail

**Source FRs**: FR-010, FR-011, FR-012, FR-013, FR-020 | **Q-resolutions**: Q2=D, Q3=A, Q4=A, Q5=A | **Source-of-truth**: [data-model.md §8](../data-model.md#8-flutter-entity--dto--use-case--bloc-event-shapes)

## Widget tree

```
step_media.dart (StatelessWidget — replaces Phase 10 step_media_placeholder.dart)
└── BlocBuilder<ListingFormBloc, ListingFormState>
    ├── upload-affordance row
    │   ├── ElevatedButton "Add images" (FR-010; disabled at 10-image cap from FR-005)
    │   └── ElevatedButton "Add video"  (FR-010; disabled at 2-video cap from FR-005)
    └── MediaPicker (StatefulWidget — drag-reorder state owner)
        └── ReorderableGridView.builder (3-column on portrait; FR-013)
            └── MediaThumbnail (per row in `state.media`, sorted by ordering)
                ├── Image preview (per kind):
                │   ├── image → Image.memory(localBytes) OR Image.network(publicUrl) per R-29
                │   └── video → Container with play-icon overlay (no video-frame thumbnail in Phase 11)
                ├── Main badge (top-end corner; only for is_main=true image rows)
                ├── Ordering badge (top-start corner; index 1..N)
                ├── Progress overlay (CircularProgressIndicator when uploadInFlight[id] is processing)
                ├── Error overlay (icon + localized message + Retry button when uploadInFlight[id] is error)
                └── GestureDetector onLongPress → BottomSheet action sheet:
                    ├── "Set as main" (hidden when kind=video per FR-013 / FR-002 CHECK)
                    ├── "Delete" (with localized confirmation dialog)
                    └── (Reorder hint — drag is the primary affordance)
```

## BLoC event surface (R-40 — `ListingFormBloc` extension)

| Event | Payload | Handler |
|---|---|---|
| `MediaPicked` | `List<XFile>` (from `image_picker.pickMultiImage(...)`) | For each file: validate via Q4 accept set + Q6 8000×8000 cap, then enqueue on R-25 isolate worker for the FR-014 pipeline. Update `state.uploadInFlight` per file. |
| `VideoPicked` | `XFile` (from `image_picker.pickVideo(...)`) | Validate via `video_file_validator` (MP4 mime + ≤ 30 MB). Directly upload (no watermark). |
| `MediaReordered` | `List<String>` (new id sequence) | Issue transactional UPDATE re-sequencing `ordering`. |
| `MediaSetMain` | `String mediaId` | Issue transactional UPDATE flipping `is_main=true` on target + `is_main=false` on prior main. |
| `MediaDeleted` | `String mediaId` | Per R-38: storage.from(bucket).remove([path]) → from('listing_media').delete().eq('id', id). |

## State extension (R-40)

`ListingFormState` gains:
- `final List<ListingMedia> media` — current media set, ordered by `ordering` ASC.
- `final Map<String, _MediaUploadProgress> uploadInFlight` — per-file pipeline state (idle / processing / uploading / error / completed) keyed by a local UUID stable across re-renders.

## Q-resolution enforcement

| Q | How enforced in this widget set |
|---|---|
| Q1=A | The Submit button on step 7 (Review — Phase 10) is disabled when `state.media.where((m) => m.kind == ListingMediaKind.image && m.watermarked).isEmpty`. Server-side check duplicates per FR-022. |
| Q2=D | No "Add external link" CTA; no URL text field; no host-badge rendering. |
| Q3=A | On entering step 6 with an existing draft/rejected listing, `LoadMediaForListing` runs; existing rows render with stable UUIDs preserved. |
| Q4=A | `image_picker.pickMultiImage()` allows the broad source set; the FR-014 pipeline normalizes to JPEG. |
| Q5=A | `image_picker` plugin internally handles version-aware runtime permission requests on Android. On denial, the picker surfaces `media.error.galleryPermissionDenied` + `media.action.openSettings` per FR-019. |
| Q6=B | The FR-014 pipeline's step (a-pre) reads source header dimensions; rejects > 8000×8000 with `media.error.imageTooLarge`. |
| Q7=B | The BLoC `MediaPicked` handler wraps each file's pipeline `Future` in `.timeout(Duration(seconds: 60))` per R-39. |
| Q8=A | Picker thumbnails use `getPublicUrl()` for re-mounted sessions per R-29. |

## Read-only mode

When the parent listing's `status NOT IN ('draft', 'rejected')` (i.e., `pending_review`, `approved`, `paused`, `sold`, `rented`, `expired`, `deleted`), the picker hides the upload affordances AND hides the per-thumbnail long-press action sheet. The existing thumbnails render as a non-interactive carousel. The localized banner `media.readOnly.pendingOrApproved` displays at the top of step 6.

## Constitution IX-clean (FR-012)

`lib/features/listing_form/presentation/widgets/step_media.dart`, `media_picker.dart`, `media_thumbnail.dart` — none import `package:supabase_flutter`. SC-014 verifies via grep.

## Design tokens (FR-020 / Constitution VI)

- Thumbnail size: `MediaQuery.of(context).size.width / 3 - AppSpacing.md * 2` (computed; no inline pixel literal).
- Main badge color: `Theme.of(context).colorScheme.primary`.
- Error overlay color: `Theme.of(context).colorScheme.errorContainer`.
- Progress spinner color: `Theme.of(context).colorScheme.primaryFixed` (Phase 2 token).
- Action sheet styling: Phase 2 `BottomSheet` primitive.
- No inline hex; no inline EdgeInsets.only; no raw pixel SizedBox. SC-016 verifies.
