import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'panorama_pipeline.dart';
import 'watermark_pipeline.dart';

/// Phase 11 R-25 — Shared sequential background isolate worker.
///
/// Spawns ONE isolate at picker mount and processes image jobs sequentially
/// (one at a time) to bound peak RAM at ~100 MB per R-25.
/// The isolate is reused across all images picked in the same session.
///
/// Usage pattern:
/// ```dart
/// final worker = ImageIsolateWorker();
/// await worker.start();
/// try {
///   final result = await worker.processImage(
///     sourceBytes: bytes,
///     watermarkAssetBytes: assetBytes,
///     isRtl: true,
///   );
/// } finally {
///   worker.stop();
/// }
/// ```
///
/// Constitution IX: pure Dart — no package:supabase_flutter, no Flutter widgets.
/// Isolate-safe: only dart:isolate + dart:async + watermark_pipeline.dart.

// ---------------------------------------------------------------------------
// Internal message types passed via SendPort
// ---------------------------------------------------------------------------

/// Job sent from main isolate to the worker isolate.
class _ImageJob {
  final SendPort replyTo;
  final Uint8List sourceBytes;
  final Uint8List watermarkAssetBytes;
  final bool isRtl;

  const _ImageJob({
    required this.replyTo,
    required this.sourceBytes,
    required this.watermarkAssetBytes,
    required this.isRtl,
  });
}

/// Phase 029 (F5) — Panorama job sent from main isolate to the worker isolate.
/// Mirrors [_ImageJob] but runs the equirectangular pipeline (no watermark, no
/// watermark asset bytes needed, 4096px cap, 2:1 aspect gate).
class _PanoramaJob {
  final SendPort replyTo;
  final Uint8List sourceBytes;

  const _PanoramaJob({required this.replyTo, required this.sourceBytes});
}

/// Result returned from the worker isolate to the main isolate.
class _ImageResult {
  /// Non-null on success.
  final Uint8List? bytes;

  /// The card thumbnail, non-null only for the watermark pipeline. The panorama
  /// pipeline leaves it null: a panorama is never a card image (the card
  /// LATERALs all filter `kind = 'image'`), so making one would be wasted work.
  final Uint8List? thumbnailBytes;

  /// Non-null on failure.
  final Object? error;

  const _ImageResult.success(Uint8List this.bytes, {this.thumbnailBytes})
    : error = null;
  const _ImageResult.failure(Object this.error)
    : bytes = null,
      thumbnailBytes = null;
}

// ---------------------------------------------------------------------------
// Worker isolate entry point (runs on the background isolate)
// ---------------------------------------------------------------------------

/// Entry point for the background isolate.
///
/// Receives the main isolate's [SendPort], then listens for [_ImageJob]
/// messages and processes them sequentially by calling [processImageForUpload].
void _workerEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();

  // Send our ReceivePort's SendPort back to the main isolate so it can talk to us
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) async {
    if (message is _ImageJob) {
      try {
        final processed = await processImageForUpload(
          sourceBytes: message.sourceBytes,
          watermarkAssetBytes: message.watermarkAssetBytes,
          isRtl: message.isRtl,
        );
        message.replyTo.send(
          _ImageResult.success(
            processed.full,
            thumbnailBytes: processed.thumbnail,
          ),
        );
      } catch (e) {
        message.replyTo.send(_ImageResult.failure(e));
      }
    } else if (message is _PanoramaJob) {
      // Phase 029 (F5) — equirectangular panorama path (no watermark).
      try {
        final resultBytes = await processPanoramaForUpload(
          sourceBytes: message.sourceBytes,
        );
        message.replyTo.send(_ImageResult.success(resultBytes));
      } catch (e) {
        message.replyTo.send(_ImageResult.failure(e));
      }
    }
  });
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Manages the lifecycle of a single background isolate for image processing.
///
/// Jobs are processed sequentially — the caller should await each
/// [processImage] call before dispatching the next one (or the BLoC queues
/// them via a StreamQueue / sequential Future chain per R-25).
class ImageIsolateWorker {
  Isolate? _isolate;
  SendPort? _workerSendPort;
  ReceivePort? _mainReceivePort;
  bool _started = false;

  /// Spawns the background isolate. Must be called before [processImage].
  Future<void> start() async {
    if (_started) return;

    final initPort = ReceivePort();
    _isolate = await Isolate.spawn(
      _workerEntry,
      initPort.sendPort,
      debugName: 'image_isolate_worker',
    );

    // Wait for the worker to send back its SendPort
    final completer = Completer<SendPort>();
    initPort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
        initPort.close();
      }
    });

    _workerSendPort = await completer.future;
    _started = true;
  }

  /// Sends [sourceBytes] to the background isolate for watermark processing.
  ///
  /// Returns the full-resolution JPEG **and** its card thumbnail
  /// ([ProcessedImage]); both are made from the same decoded pixels in one pass,
  /// so the thumbnail costs no second decode.
  /// Throws the original exception (wrapped) on failure.
  ///
  /// Jobs are processed sequentially on the isolate side. Callers MUST
  /// await this call before issuing the next job to maintain the sequential
  /// R-25 invariant (bounding peak RAM at ~100 MB).
  Future<ProcessedImage> processImage({
    required Uint8List sourceBytes,
    required Uint8List watermarkAssetBytes,
    required bool isRtl,
  }) async {
    if (!_started || _workerSendPort == null) {
      throw StateError(
        'ImageIsolateWorker.start() must be called before processImage()',
      );
    }

    final replyPort = ReceivePort();
    final completer = Completer<ProcessedImage>();

    replyPort.listen((message) {
      replyPort.close();
      if (message is _ImageResult) {
        final full = message.bytes;
        final thumb = message.thumbnailBytes;
        if (full != null && thumb != null) {
          completer.complete(ProcessedImage(full: full, thumbnail: thumb));
        } else {
          completer.completeError(
            message.error ?? Exception('Unknown isolate error'),
          );
        }
      } else {
        completer.completeError(
          Exception('Unexpected isolate response: $message'),
        );
      }
    });

    _workerSendPort!.send(
      _ImageJob(
        replyTo: replyPort.sendPort,
        sourceBytes: sourceBytes,
        watermarkAssetBytes: watermarkAssetBytes,
        isRtl: isRtl,
      ),
    );

    return completer.future;
  }

  /// Phase 029 (F5) — sends [sourceBytes] to the background isolate for the
  /// equirectangular panorama pipeline (no watermark, 4096px cap, 2:1 aspect
  /// gate). Returns the processed JPEG bytes on success; throws the original
  /// pipeline exception (e.g. [NotEquirectangularException]) on failure.
  ///
  /// Like [processImage], jobs are processed sequentially on the isolate side;
  /// callers MUST await this call before issuing the next job.
  Future<Uint8List> processPanorama({required Uint8List sourceBytes}) async {
    if (!_started || _workerSendPort == null) {
      throw StateError(
        'ImageIsolateWorker.start() must be called before processPanorama()',
      );
    }

    final replyPort = ReceivePort();
    final completer = Completer<Uint8List>();

    replyPort.listen((message) {
      replyPort.close();
      if (message is _ImageResult) {
        if (message.bytes != null) {
          completer.complete(message.bytes);
        } else {
          completer.completeError(
            message.error ?? Exception('Unknown isolate error'),
          );
        }
      } else {
        completer.completeError(
          Exception('Unexpected isolate response: $message'),
        );
      }
    });

    _workerSendPort!.send(
      _PanoramaJob(replyTo: replyPort.sendPort, sourceBytes: sourceBytes),
    );

    return completer.future;
  }

  /// Terminates the background isolate. Should be called when the MediaPicker
  /// route disposes (e.g., in the BLoC's close() or widget's dispose()).
  void stop() {
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _workerSendPort = null;
    _mainReceivePort?.close();
    _mainReceivePort = null;
    _started = false;
  }
}
