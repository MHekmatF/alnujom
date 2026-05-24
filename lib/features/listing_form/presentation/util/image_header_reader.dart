import 'dart:typed_data';

/// Phase 11 R-24 — Header-only image dimension reader.
///
/// Reads ONLY the file header (first ~64 to ~512 bytes) to extract pixel
/// dimensions WITHOUT performing a full pixel decode. Used by the Q6=B
/// pre-decode cap check (rejects sources wider or taller than 8000 px before
/// any memory-intensive decode operation).
///
/// Constitution IX: pure Dart — no package:supabase_flutter import.
/// Isolate-safe: no Flutter binding dependencies.

/// Stores extracted pixel dimensions from an image header.
class ImageDimensions {
  final int width;
  final int height;

  const ImageDimensions(this.width, this.height);

  @override
  String toString() => 'ImageDimensions(${width}x$height)';
}

/// Q4=A accepted source formats (per spec).
enum ImageFormat {
  jpeg,
  png,
  heic,
  webp,

  /// Format outside the Q4=A accept set — rejected by the pipeline.
  unsupported,
}

/// Detects the image format from magic bytes.
///
/// Reads at most the first 12 bytes. Returns [ImageFormat.unsupported] if the
/// byte sequence does not match any accepted Q4=A format or if [bytes] is too
/// short.
///
/// Per data-model.md § 8.8 and contracts/watermark-pipeline.md § R-24.
ImageFormat detectFormat(Uint8List bytes) {
  if (bytes.length < 12) return ImageFormat.unsupported;

  // JPEG: starts with FF D8 FF
  if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
    return ImageFormat.jpeg;
  }

  // PNG: starts with 89 50 4E 47 (0x89PNG)
  if (bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return ImageFormat.png;
  }

  // HEIC/HEIF: ftyp box at bytes 4-7, followed by a known brand at bytes 8-11.
  // The box size (bytes 0-3) can vary; we check the ftyp signature at offset 4.
  if (bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (['heic', 'heif', 'mif1', 'heix', 'msf1'].contains(brand)) {
      return ImageFormat.heic;
    }
  }

  // WebP: RIFF....WEBP (bytes 0-3 = RIFF, bytes 8-11 = WEBP)
  if (bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return ImageFormat.webp;
  }

  return ImageFormat.unsupported;
}

/// Reads pixel dimensions from the image header WITHOUT decoding pixels.
///
/// Returns [ImageDimensions] if dimensions were successfully extracted from
/// the header, or `null` if the header is corrupt / unreadable.
///
/// Supported formats and their header strategies:
/// - JPEG: walks SOF0 (Start of Frame baseline, marker 0xFFC0) markers.
/// - PNG: reads the IHDR chunk always at byte offset 16.
/// - HEIC: scans the container for the `ispe` (image spatial extent) box.
/// - WebP: reads the VP8X chunk dimensions at a fixed offset.
///
/// Per data-model.md § 8.8 and contracts/watermark-pipeline.md § R-24.
Future<ImageDimensions?> readImageDimensions(
  Uint8List bytes,
  ImageFormat format,
) async {
  try {
    switch (format) {
      case ImageFormat.jpeg:
        return _readJpegDimensions(bytes);
      case ImageFormat.png:
        return _readPngDimensions(bytes);
      case ImageFormat.heic:
        return _readHeicDimensions(bytes);
      case ImageFormat.webp:
        return _readWebpDimensions(bytes);
      case ImageFormat.unsupported:
        return null;
    }
  } catch (_) {
    // Any parse error → treat as corrupt header → return null
    return null;
  }
}

// ---------------------------------------------------------------------------
// JPEG — walk SOF0/SOF2 markers to extract width and height
// ---------------------------------------------------------------------------

/// Reads JPEG dimensions by walking segment markers until a SOF marker is found.
///
/// SOF markers that carry width/height in their payload:
/// SOF0 (0xFFC0), SOF1 (0xFFC1), SOF2 (0xFFC2), SOF9 (0xFFC9).
ImageDimensions? _readJpegDimensions(Uint8List bytes) {
  if (bytes.length < 4) return null;

  int offset = 2; // skip the initial FF D8 SOI marker
  while (offset + 4 < bytes.length) {
    if (bytes[offset] != 0xFF) return null; // lost sync

    final marker = bytes[offset + 1];
    final segmentLength =
        (bytes[offset + 2] << 8) | bytes[offset + 3]; // big-endian

    // SOF markers that encode image dimensions (height at +5..+6, width at +7..+8)
    // SOF0=0xC0, SOF1=0xC1, SOF2=0xC2, SOF9=0xC9 (progressive DCT)
    if (marker == 0xC0 || marker == 0xC1 || marker == 0xC2 || marker == 0xC9) {
      if (offset + 9 >= bytes.length) return null;
      // payload starts at offset+4; [0]=precision, [1..2]=height, [3..4]=width
      final h = (bytes[offset + 5] << 8) | bytes[offset + 6];
      final w = (bytes[offset + 7] << 8) | bytes[offset + 8];
      if (w == 0 || h == 0) return null;
      return ImageDimensions(w, h);
    }

    // Skip to the next segment: current marker (2) + length field (2) + payload
    offset += 2 + segmentLength;
  }
  return null;
}

// ---------------------------------------------------------------------------
// PNG — IHDR chunk is always at bytes 8-33 (after the 8-byte PNG signature)
// ---------------------------------------------------------------------------

/// Reads PNG dimensions from the IHDR chunk at fixed offset 16.
///
/// PNG file layout: 8-byte signature + IHDR chunk (4-byte length at 8,
/// 4-byte type "IHDR" at 12, width at 16..19, height at 20..23).
ImageDimensions? _readPngDimensions(Uint8List bytes) {
  if (bytes.length < 24) return null;

  // Verify PNG signature
  if (bytes[0] != 0x89 ||
      bytes[1] != 0x50 ||
      bytes[2] != 0x4E ||
      bytes[3] != 0x47) {
    return null;
  }

  // IHDR chunk type at bytes 12-15 should be "IHDR" = 0x49484452
  if (bytes[12] != 0x49 ||
      bytes[13] != 0x48 ||
      bytes[14] != 0x44 ||
      bytes[15] != 0x52) {
    return null;
  }

  final w =
      (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
  final h =
      (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
  if (w == 0 || h == 0) return null;
  return ImageDimensions(w, h);
}

// ---------------------------------------------------------------------------
// HEIC — scan for 'ispe' (image spatial extent) box in the container
// ---------------------------------------------------------------------------

/// Reads HEIC/HEIF dimensions by scanning for the `ispe` (image spatial
/// extent) ISOBMFF box in the byte stream.
///
/// The `ispe` box contains width (4 bytes) and height (4 bytes) immediately
/// after its box header (size:4 + type:4 = 8 bytes) and the FullBox fields
/// (version:1 + flags:3 = 4 bytes).
///
/// We scan up to 32 KB into the file — the `ispe` box is typically in the
/// `iprp`→`ipco` box hierarchy near the beginning.
ImageDimensions? _readHeicDimensions(Uint8List bytes) {
  // 'ispe' in ASCII = 0x69 0x73 0x70 0x65
  final limit = bytes.length < 32768 ? bytes.length : 32768;

  for (int i = 4; i + 16 < limit; i++) {
    // Search for the 'ispe' box type tag
    if (bytes[i] == 0x69 &&
        bytes[i + 1] == 0x73 &&
        bytes[i + 2] == 0x70 &&
        bytes[i + 3] == 0x65) {
      // The box layout: [size:4][type:4][version:1][flags:3][width:4][height:4]
      // 'ispe' tag is at i; full box payload starts at i+4 (version+flags),
      // then width at i+8, height at i+12.
      if (i + 16 > bytes.length) return null;
      final w =
          (bytes[i + 8] << 24) |
          (bytes[i + 9] << 16) |
          (bytes[i + 10] << 8) |
          bytes[i + 11];
      final h =
          (bytes[i + 12] << 24) |
          (bytes[i + 13] << 16) |
          (bytes[i + 14] << 8) |
          bytes[i + 15];
      if (w > 0 && h > 0) return ImageDimensions(w, h);
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// WebP — read VP8X chunk dimensions
// ---------------------------------------------------------------------------

/// Reads WebP dimensions.
///
/// WebP layout: RIFF (4) + file size (4) + WEBP (4) = 12 bytes header.
/// Then the first chunk follows at offset 12.
///
/// For VP8X (Extended WebP): type 'VP8X' at 12, chunk data size at 16,
/// chunk data at 20. Canvas width (minus 1) is 3 bytes little-endian at
/// offset 24; canvas height (minus 1) is 3 bytes little-endian at offset 27.
///
/// For plain VP8 (lossy): type 'VP8 ' at 12. Width and height are encoded
/// in the bitstream at fixed offsets 26..29.
///
/// For VP8L (lossless): type 'VP8L' at 12. The signature is 0x2F at offset
/// 20; width-1 is 14 bits and height-1 is 14 bits packed at offset 21.
ImageDimensions? _readWebpDimensions(Uint8List bytes) {
  if (bytes.length < 30) return null;

  // Verify RIFF....WEBP header
  if (bytes[0] != 0x52 ||
      bytes[1] != 0x49 ||
      bytes[2] != 0x46 ||
      bytes[3] != 0x46) {
    return null;
  }
  if (bytes[8] != 0x57 ||
      bytes[9] != 0x45 ||
      bytes[10] != 0x42 ||
      bytes[11] != 0x50) {
    return null;
  }

  // Read chunk type at offset 12
  final chunkType = String.fromCharCodes(bytes.sublist(12, 16));

  if (chunkType == 'VP8X') {
    // VP8X Extended format — canvas width at 24 (3 bytes LE, value+1) and height at 27
    if (bytes.length < 30) return null;
    final w = 1 + (bytes[24] | (bytes[25] << 8) | (bytes[26] << 16));
    final h = 1 + (bytes[27] | (bytes[28] << 8) | (bytes[29] << 16));
    return ImageDimensions(w, h);
  } else if (chunkType == 'VP8 ') {
    // Lossy VP8 — width and height in the bitstream header
    // Bitstream starts at offset 20. Check for the VP8 frame tag at 20..22.
    if (bytes.length < 30) return null;
    // VP8 bitstream frame starts with a 3-byte frame tag; check keyframe bit (bit 0 = 0)
    if ((bytes[20] & 0x01) != 0) return null; // not a keyframe
    // Width at bytes 26..27 (16-bit LE), height at bytes 28..29 (16-bit LE)
    // Lower 14 bits = dimension; upper 2 bits = scale
    final w = (bytes[26] | (bytes[27] << 8)) & 0x3FFF;
    final h = (bytes[28] | (bytes[29] << 8)) & 0x3FFF;
    if (w == 0 || h == 0) return null;
    return ImageDimensions(w, h);
  } else if (chunkType == 'VP8L') {
    // Lossless VP8L — signature 0x2F at offset 20; width/height packed after
    if (bytes.length < 25) return null;
    if (bytes[20] != 0x2F) return null; // VP8L signature byte
    // Bits 0..13 = width - 1; bits 14..27 = height - 1 (packed across bytes 21..24)
    final bits =
        bytes[21] | (bytes[22] << 8) | (bytes[23] << 16) | (bytes[24] << 24);
    final w = (bits & 0x3FFF) + 1;
    final h = ((bits >> 14) & 0x3FFF) + 1;
    return ImageDimensions(w, h);
  }

  return null;
}
