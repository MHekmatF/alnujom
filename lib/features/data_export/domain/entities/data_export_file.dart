import 'dart:typed_data';

/// Plan A38 — the file "Download my data" hands to the share sheet.
class DataExportFile {
  const DataExportFile({required this.bytes, required this.fileName});

  /// Pretty-printed UTF-8 JSON, exactly as the server composed it.
  final Uint8List bytes;

  /// `alnujom-data-YYYY-MM-DD.json`.
  final String fileName;
}
