import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import 'image_header_reader.dart';

/// Phase 11 FR-014 — Client-side watermark + downscale pipeline.
///
/// Top-level pure function callable from the R-25 background isolate worker.
/// Implements all 7 FR-014 steps: format-detect → Q6 header dimension cap →
/// decode → EXIF-strip + bake-orientation → downscale to 1920 →
/// watermark composite (R-23 params) → JPEG quality-85 re-encode.
///
/// Constitution IX: pure Dart — no package:supabase_flutter, no Flutter widgets.
/// Isolate-safe: only dart:typed_data + image package + flutter_image_compress.

// ---------------------------------------------------------------------------
// Custom exceptions (surface structured errors to the BLoC / picker UI)
// ---------------------------------------------------------------------------

/// Thrown when the source image format is not in the Q4=A accept set
/// (JPEG / PNG / HEIC / WebP) or the header is too corrupt to identify.
class UnsupportedFormatException implements Exception {
  const UnsupportedFormatException();

  @override
  String toString() => 'UnsupportedFormatException: format not in Q4=A accept set';
}

/// Thrown when the source image header indicates dimensions exceeding the
/// Q6=B hard cap of 8000 × 8000 pixels (checked before full decode).
class ImageTooLargeException implements Exception {
  final int width;
  final int height;

  const ImageTooLargeException(this.width, this.height);

  @override
  String toString() =>
      'ImageTooLargeException: ${width}x$height exceeds 8000x8000 cap';
}

/// Thrown when the watermark PNG asset bytes cannot be decoded (asset missing
/// or corrupt). Pipeline fails closed per FR-014 edge case + Constitution III.
class WatermarkAssetMissingException implements Exception {
  const WatermarkAssetMissingException();

  @override
  String toString() => 'WatermarkAssetMissingException: watermark asset missing or corrupt';
}

// ---------------------------------------------------------------------------
// Main pipeline function
// ---------------------------------------------------------------------------

/// Processes a source image through the FR-014 pipeline and returns the
/// resulting watermarked JPEG bytes.
///
/// Parameters:
/// - [sourceBytes]: Raw bytes of the picked image file (JPEG/PNG/HEIC/WebP).
/// - [watermarkAssetBytes]: Raw PNG bytes of the AlNujom watermark asset
///   (`assets/images/watermark/logo_watermark.png`). Must be provided by the
///   caller since isolates cannot access the Flutter asset bundle.
/// - [isRtl]: Whether the current locale is right-to-left. Determines the
///   watermark corner: bottom-right (LTR) or bottom-left (RTL) per R-23.
///
/// Throws:
/// - [UnsupportedFormatException] — format outside Q4=A accept set or corrupt header.
/// - [ImageTooLargeException] — source exceeds 8000×8000 pre-decode cap (Q6=B).
/// - [WatermarkAssetMissingException] — watermark PNG cannot be decoded.
///
/// Constitution IX: no package:supabase_flutter. Pure Dart — runs on isolate.
Future<Uint8List> processImageForUpload({
  required Uint8List sourceBytes,
  required Uint8List watermarkAssetBytes,
  required bool isRtl,
}) async {
  // -------------------------------------------------------------------------
  // (a) FORMAT DETECT — Q4=A accept set: JPEG, PNG, HEIC, WebP
  // -------------------------------------------------------------------------
  final format = detectFormat(sourceBytes);
  if (format == ImageFormat.unsupported) {
    throw const UnsupportedFormatException();
  }

  // -------------------------------------------------------------------------
  // (a-pre) Q6=B HEADER DIMENSION CAP — reject pre-decode if > 8000×8000
  // -------------------------------------------------------------------------
  final dims = await readImageDimensions(sourceBytes, format);
  if (dims == null) throw const UnsupportedFormatException(); // corrupt header
  if (dims.width > 8000 || dims.height > 8000) {
    throw ImageTooLargeException(dims.width, dims.height);
  }

  // -------------------------------------------------------------------------
  // (b) DECODE — pure-Dart `image` package for JPEG/PNG/WebP;
  //              flutter_image_compress for HEIC (native libheif on Android).
  // -------------------------------------------------------------------------
  img.Image? decoded;

  if (format == ImageFormat.heic) {
    // FlutterImageCompress decodes HEIC → JPEG bytes natively via libheif.
    // quality=100 preserves maximum fidelity at this stage; we re-encode at 85 later.
    final jpegBytes = await FlutterImageCompress.compressWithList(
      sourceBytes,
      format: CompressFormat.jpeg,
      quality: 100,
    );
    decoded = img.decodeJpg(jpegBytes);
  } else {
    // The `image` package handles JPEG, PNG, and WebP natively (pure Dart).
    decoded = img.decodeImage(sourceBytes);
  }

  if (decoded == null) throw const UnsupportedFormatException();

  // PNG transparency → composite against a white background before watermark.
  // Real-estate photos rarely carry meaningful transparency; white fill is safe.
  if (format == ImageFormat.png && decoded.hasAlpha) {
    final flat = img.Image(width: decoded.width, height: decoded.height);
    img.fill(flat, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flat, decoded);
    decoded = flat;
  }

  // -------------------------------------------------------------------------
  // (c) EXIF ROTATION + STRIP — bakeOrientation applies EXIF rotation to
  //     pixel data and strips the EXIF block (no GPS / camera metadata survives).
  // -------------------------------------------------------------------------
  decoded = img.bakeOrientation(decoded);
  // Clear EXIF to strip GPS, camera-make, camera-model (SC-024 / privacy invariant).
  decoded.exif = img.ExifData();

  // -------------------------------------------------------------------------
  // (d) DOWNSCALE — long edge ≤ 1920 px (skip if already within bounds)
  // -------------------------------------------------------------------------
  final longEdge =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  if (longEdge > 1920) {
    final scale = 1920.0 / longEdge;
    decoded = img.copyResize(
      decoded,
      width: (decoded.width * scale).round(),
      height: (decoded.height * scale).round(),
      interpolation: img.Interpolation.cubic,
    );
  }

  // -------------------------------------------------------------------------
  // (e) WATERMARK COMPOSITE — R-23 params:
  //     bottom-end corner, 15% opacity, 18% of long edge, 24 px padding.
  //     Aspect-ratio cap: min(18% of long edge, 50% of short edge).
  // -------------------------------------------------------------------------
  final watermark = img.decodePng(watermarkAssetBytes);
  if (watermark == null) throw const WatermarkAssetMissingException();

  final finalLong =
      decoded.width > decoded.height ? decoded.width : decoded.height;
  final finalShort =
      decoded.width > decoded.height ? decoded.height : decoded.width;

  // R-23 aspect-ratio cap: min(18% of long edge, 50% of short edge)
  final wmTargetWidth = (0.18 * finalLong)
      .round()
      .clamp(1, (0.50 * finalShort).round());
  final wmScale = wmTargetWidth / watermark.width;
  final scaledWatermark = img.copyResize(
    watermark,
    width: wmTargetWidth,
    height: (watermark.height * wmScale).round(),
    interpolation: img.Interpolation.cubic,
  );

  // Pre-multiply watermark alpha by 0.15 (15% opacity per R-23).
  // The `image` package v4.x exposes Pixel objects via iteration; .a is settable.
  for (final pixel in scaledWatermark) {
    pixel.a = (pixel.a * 0.15).round().clamp(0, 255);
  }

  // RTL-aware positioning: bottom-end = bottom-RIGHT in LTR, bottom-LEFT in RTL
  const padding = 24;
  final dstY = decoded.height - scaledWatermark.height - padding;
  final dstX = isRtl
      ? padding
      : decoded.width - scaledWatermark.width - padding;

  img.compositeImage(
    decoded,
    scaledWatermark,
    dstX: dstX,
    dstY: dstY,
    blend: img.BlendMode.alpha,
  );

  // -------------------------------------------------------------------------
  // (f) RE-ENCODE as JPEG quality 85
  // -------------------------------------------------------------------------
  final jpegOut = img.encodeJpg(decoded, quality: 85);

  // -------------------------------------------------------------------------
  // (g) Return bytes
  // -------------------------------------------------------------------------
  return Uint8List.fromList(jpegOut);
}
