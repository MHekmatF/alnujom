# Contract: `video_file_validator.dart`

**Source FRs**: FR-017 | **Path**: `lib/core/validators/video_file_validator.dart` | **Pattern**: matches Phase 10 R-18 validators-in-core invariant

## API

```dart
class VideoFileValidator {
  /// Returns null on success; localized error key on failure.
  /// Caller resolves the key via AppLocalizations at render time.
  static String? validate(XFile file, {required int sizeBytes});
}
```

Caller pattern:
```dart
final errorKey = VideoFileValidator.validate(pickedFile, sizeBytes: bytesRead);
if (errorKey != null) {
  showSnackBar(AppLocalizations.of(context)!.lookupByKey(errorKey));
  return;
}
```

## Validation rules

| Rule | Check | Error key on failure |
|---|---|---|
| MIME type | `file.mimeType == 'video/mp4'` OR (`mimeType` is null AND `file.name.toLowerCase().endsWith('.mp4')`) | `media.error.videoFormatMustBeMp4` |
| Size cap | `sizeBytes <= 31457280` (30 MB) | `media.error.videoSizeExceeded` |

If both rules pass, returns `null`.

## Golden inputs (manual verification per quickstart.md)

| File | mimeType | bytes | Expected return |
|---|---|---|---|
| `test.mp4` | `'video/mp4'` | 10000000 (10 MB) | `null` (accept) |
| `test.mp4` | `'video/mp4'` | 31457280 (30 MB exactly) | `null` (accept — boundary inclusive) |
| `test.mp4` | `'video/mp4'` | 31457281 (30 MB + 1 byte) | `'media.error.videoSizeExceeded'` |
| `test.mov` | `'video/quicktime'` | 5000000 (5 MB) | `'media.error.videoFormatMustBeMp4'` |
| `test.mkv` | `'video/x-matroska'` | 5000000 | `'media.error.videoFormatMustBeMp4'` |
| `test.mp4` | `null` (some pickers don't supply MIME) | 5000000 | `null` (accept — name-fallback) |
| `test.jpg` | `'image/jpeg'` | 5000000 | `'media.error.videoFormatMustBeMp4'` |

## Server-side defense-in-depth

The `listing-videos` bucket's `allowed_mime_types: ['video/mp4']` AND `file_size_limit: 31457280` (FR-008) enforce the same rules at upload time. A malicious client bypassing this validator hits the bucket-level rejection.

## Constitution IX

Pure Dart; no `package:supabase_flutter` import. SC-014 indirectly covers via the `lib/core/validators/` directory grep.

## Localization

The two error keys ship in both `lib/l10n/app_ar.arb` and `lib/l10n/app_en.arb` per FR-019. See [data-model.md §9](../data-model.md#9-arb-key-inventory-fr-019) for the full ARB inventory.

## Constitution X (manual verification only)

No automated tests per `feedback_no_new_tests.md`. The golden table above is exercised manually during the quickstart.md device walk on the Infinix Note 8 — pick three video files (one valid MP4, one .mov, one >30 MB MP4) and confirm the validator's output matches the table.
