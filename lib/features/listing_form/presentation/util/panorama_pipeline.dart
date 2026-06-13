import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import 'image_header_reader.dart';
import 'watermark_pipeline.dart'
    show
        ImageTooLargeException,
        UnsupportedFormatException;

/// Phase 029 (F5) — Client-side 360°/equirectangular panorama pipeline.
///
/// Sibling of [processImageForUpload] (watermark_pipeline.dart). Top-level pure
/// function callable from the shared background isolate worker. A panorama is an
/// equirectangular photo whose width:height ratio is ~2:1; treating it like a
/// normal listing image would be wrong on two counts:
///   1. The watermark composite would land inside the 360° sphere and break the
///      left/right wrap seam — so this pipeline applies NO watermark.
///   2. The 1920px long-edge cap of the image pipeline would crush the
///      horizontal resolution the viewer needs — so this caps the longest edge
///      at 4096px instead.
///
/// Steps:
///   (a) format-detect (Q4=A accept set) + reject unsupported
///   (a-pre) read header dims; ASPECT GATE width/height in [1.9, 2.1] else throw
///           [NotEquirectangularException]; also the 8000x8000 pre-decode cap
///   (b) decode (image package; flutter_image_compress for HEIC)
///   (c) bake EXIF orientation + STRIP exif (privacy — no GPS/camera metadata)
///   (d) downscale longest edge to <= 4096 (equirect needs width)
///   (e) NO watermark (would break the wrap seam)
///   (f) JPEG re-encode quality 85
///
/// Constitution IX: pure Dart — no package:supabase_flutter, no Flutter widgets.
/// Isolate-safe: only dart:typed_data + image + flutter_image_compress.

// ---------------------------------------------------------------------------
// Custom exception
// ---------------------------------------------------------------------------

/// Thrown when the source image is not a 2:1 equirectangular panorama (its
/// width/height ratio falls outside the [1.9, 2.1] acceptance window). Surfaces
/// to the picker UI as a localized hint guiding the publisher to capture a real
/// 360° photo with a panorama-capable app.
class NotEquirectangularException implements Exception {
  const NotEquirectangularException(this.width, this.height);

  final int width;
  final int height;

  /// The measured width/height ratio (e.g. 2.0 for a perfect equirectangular).
  double get ratio => height == 0 ? 0 : width / height;

  @override
  String toString() =>
      'NotEquirectangularException: ${width}x$height (ratio '
      '${ratio.toStringAsFixed(3)}) is not 2:1 equirectangular';
}

// ---------------------------------------------------------------------------
// Acceptance window + downscale target
// ---------------------------------------------------------------------------

/// Minimum accepted width/height ratio for an equirectangular panorama.
const double kPanoramaMinAspect = 1.9;

/// Maximum accepted width/height ratio for an equirectangular panorama.
const double kPanoramaMaxAspect = 2.1;

/// Longest-edge cap for a panorama (must preserve enough horizontal resolution
/// for the 360° sphere — bigger than the 1920px regular-image cap).
const int kPanoramaLongEdgeCap = 4096;

// ---------------------------------------------------------------------------
// Main pipeline function
// ---------------------------------------------------------------------------

/// Processes a source equirectangular image through the F5 pipeline and returns
/// the resulting (un-watermarked, exif-stripped, JPEG-q85) panorama bytes.
///
/// Parameters:
/// - [sourceBytes]: Raw bytes of the picked image file (JPEG/PNG/HEIC/WebP).
///
/// Throws:
/// - [UnsupportedFormatException] — format outside the accept set / corrupt header.
/// - [NotEquirectangularException] — width/height ratio outside [1.9, 2.1].
/// - [ImageTooLargeException] — source exceeds the 8000x8000 pre-decode cap.
Future<Uint8List> processPanoramaForUpload({
  required Uint8List sourceBytes,
}) async {
  // -------------------------------------------------------------------------
  // (a) FORMAT DETECT — Q4=A accept set: JPEG, PNG, HEIC, WebP
  // -------------------------------------------------------------------------
  final format = detectFormat(sourceBytes);
  if (format == ImageFormat.unsupported) {
    throw const UnsupportedFormatException();
  }

  // -------------------------------------------------------------------------
  // (a-pre) HEADER DIMENSION READ + ASPECT GATE + 8000x8000 pre-decode cap
  // -------------------------------------------------------------------------
  final dims = await readImageDimensions(sourceBytes, format);
  if (dims == null) throw const UnsupportedFormatException(); // corrupt header
  if (dims.width > 8000 || dims.height > 8000) {
    throw ImageTooLargeException(dims.width, dims.height);
  }
  // Aspect gate — reject anything that is not ~2:1 equirectangular BEFORE the
  // memory-intensive decode. height==0 is guarded by the header reader (it only
  // returns positive dims), but guard defensively anyway.
  final ratio = dims.height == 0 ? 0.0 : dims.width / dims.height;
  if (ratio < kPanoramaMinAspect || ratio > kPanoramaMaxAspect) {
    throw NotEquirectangularException(dims.width, dims.height);
  }

  // -------------------------------------------------------------------------
  // (b) DECODE — image package for JPEG/PNG/WebP; flutter_image_compress (HEIC)
  // -------------------------------------------------------------------------
  img.Image? decoded;

  if (format == ImageFormat.heic) {
    final jpegBytes = await FlutterImageCompress.compressWithList(
      sourceBytes,
      format: CompressFormat.jpeg,
      quality: 100,
    );
    decoded = img.decodeJpg(jpegBytes);
  } else {
    decoded = img.decodeImage(sourceBytes);
  }

  if (decoded == null) throw const UnsupportedFormatException();

  // PNG transparency → composite against white before re-encode (matches the
  // watermark pipeline; an equirectangular panorama rarely carries alpha).
  if (format == ImageFormat.png && decoded.hasAlpha) {
    final flat = img.Image(width: decoded.width, height: decoded.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, decoded);
    decoded = flat;
  }

  // -------------------------------------------------------------------------
  // (c) EXIF ROTATION BAKE + STRIP — apply orientation to pixels, drop EXIF so
  //     no GPS / camera metadata survives (privacy invariant).
  // -------------------------------------------------------------------------
  decoded = img.bakeOrientation(decoded);
  decoded.exif = img.ExifData();

  // -------------------------------------------------------------------------
  // (d) DOWNSCALE — longest edge <= 4096 px (skip if already within bounds).
  //     Equirectangular width is the dominant dimension; 4096 preserves enough
  //     horizontal resolution for the viewer.
  // -------------------------------------------------------------------------
  final longEdge = decoded.width > decoded.height
      ? decoded.width
      : decoded.height;
  if (longEdge > kPanoramaLongEdgeCap) {
    final scale = kPanoramaLongEdgeCap / longEdge;
    decoded = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  // -------------------------------------------------------------------------
  // (e) NO WATERMARK — a composite would break the 360° left/right wrap seam.
  // -------------------------------------------------------------------------

  // -------------------------------------------------------------------------
  // (f) RE-ENCODE as JPEG quality 85
  // -------------------------------------------------------------------------
  final jpegOut = img.encodeJpg(decoded, quality: 85);
  return Uint8List.fromList(jpegOut);
}
