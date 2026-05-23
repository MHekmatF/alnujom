import 'package:image_picker/image_picker.dart';

/// Phase 11 FR-017 — Validates an MP4 video file before upload.
///
/// Returns null on success; returns the ARB error key string on failure.
/// Caller resolves the key via AppLocalizations at render time.
///
/// Constitution IX: pure Dart — no package:supabase_flutter import.
class VideoFileValidator {
  /// Validates [file] for MIME type and byte size.
  ///
  /// Rules (per contracts/video-file-validator.md):
  /// 1. MIME must be `'video/mp4'` OR (MIME is null AND filename ends `.mp4`).
  /// 2. [sizeBytes] must be <= 31457280 (30 MB).
  ///
  /// Returns null when both rules pass, otherwise returns the ARB error key.
  static String? validate(XFile file, {required int sizeBytes}) {
    // Rule 1: MIME type check
    final mime = file.mimeType;
    final nameIsmp4 = file.name.toLowerCase().endsWith('.mp4');
    final mimeOk = (mime == 'video/mp4') || (mime == null && nameIsmp4);
    if (!mimeOk) {
      return 'media.error.videoFormatMustBeMp4';
    }

    // Rule 2: Size cap — 30 MB (30 * 1024 * 1024 = 31457280 bytes), boundary inclusive
    if (sizeBytes > 31457280) {
      return 'media.error.videoSizeExceeded';
    }

    return null;
  }
}
