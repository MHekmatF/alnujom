import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:video_compress/video_compress.dart';

/// Phase 030 (W1) — best-effort 720p video transcode + poster-thumbnail helper
/// wrapping the `video_compress` plugin (a process-wide singleton: only ONE
/// compression can run at a time — guarded by [_busy] here and by the plugin's
/// own `isCompressing` flag).
///
/// Design contract (never block publishing):
///  - [compress] returns the COMPRESSED [File] only when it is strictly smaller
///    than the original; on a null result, any exception, or a no-gain result
///    (compressed size >= original size) it falls back to the ORIGINAL file.
///  - [thumbnail] returns a JPEG poster [File] grabbed from the first frame, or
///    null on any failure (the caller treats a missing poster as non-fatal).
///
/// Progress: [compress] accepts an [onProgress] callback (0..100) wired to the
/// plugin's `compressProgress$` stream; the subscription is always cancelled in
/// a `finally` block so a later compression starts from a clean stream.
@injectable
class VideoProcessor {
  VideoProcessor();

  /// Re-entrancy guard. `video_compress` is a singleton with a single native
  /// pipeline; a second concurrent call would throw `StateError`. When already
  /// busy, [compress] skips transcoding and returns the original file.
  bool _busy = false;

  bool get isBusy => _busy;

  /// Transcodes [originalPath] to 720p (H.264) best-effort.
  ///
  /// Returns the compressed file when it is smaller than the original; otherwise
  /// returns the original file unchanged. Never throws — every failure path
  /// resolves to the original file so publishing is never blocked.
  ///
  /// [onProgress] receives the 0..100 percentage emitted by the plugin.
  Future<File> compress(
    String originalPath, {
    void Function(double percent)? onProgress,
  }) async {
    final originalFile = File(originalPath);

    // Guard: a compression is already running (singleton native pipeline) — do
    // not block publishing, just upload the original.
    if (_busy || VideoCompress.isCompressing) {
      return originalFile;
    }

    _busy = true;
    Subscription? sub;
    if (onProgress != null) {
      sub = VideoCompress.compressProgress$.subscribe(onProgress);
    }
    try {
      final info = await VideoCompress.compressVideo(
        originalPath,
        quality: VideoQuality.Res1280x720Quality,
        deleteOrigin: false,
        includeAudio: true,
      );

      final compressedPath = info?.path;
      if (info == null || compressedPath == null) {
        // Plugin returned nothing (unsupported codec, cancelled, etc.).
        return originalFile;
      }
      final compressedFile = File(compressedPath);

      // Only keep the transcode if it is an actual win; some short / already-
      // efficient clips come back LARGER than the source.
      final int originalSize = await _safeLength(originalFile);
      final int compressedSize = info.filesize ?? await _safeLength(compressedFile);
      if (originalSize > 0 && compressedSize >= originalSize) {
        return originalFile;
      }
      return compressedFile;
    } catch (_) {
      // Any failure (PlatformException, StateError, etc.) — fall back to the
      // original so the publisher can still upload.
      return originalFile;
    } finally {
      sub?.unsubscribe();
      _busy = false;
    }
  }

  /// Grabs a JPEG poster frame from the first frame of [videoPath]
  /// (`position: -1` lets the plugin pick a representative frame). Returns null
  /// on any failure — a missing poster is non-fatal for the caller.
  Future<File?> thumbnail(String videoPath) async {
    try {
      return await VideoCompress.getFileThumbnail(
        videoPath,
        quality: 75,
        position: -1,
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> _safeLength(File file) async {
    try {
      return await file.length();
    } catch (_) {
      return 0;
    }
  }
}
