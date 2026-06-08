import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

import '../../../features/listing_form/domain/entities/listing_media.dart';

/// Spec 026 (growth-features) — 360°/virtual-tour storage-URL resolver.
///
/// Resolves the public storage URL for a panorama [ListingMedia] row (an
/// equirectangular image stored in the `listing-images` bucket with
/// `kind='panorama'`). Mirrors [ListingDetailsVideoLauncher]: it lives in the
/// data layer so the presentation layer ([ListingDetailsPage] /
/// [PanoramaTourPage]) can resolve a Supabase URL without importing
/// `package:supabase_flutter` (FR-030 / Constitution IX boundary).
abstract final class PanoramaTourUrlResolver {
  static const String _bucket = 'listing-images';

  /// Returns the stable public URL for [media]'s [ListingMedia.storagePath],
  /// or null when the row has no storage path.
  static String? resolve(ListingMedia media) {
    final path = media.storagePath;
    if (path == null || path.isEmpty) return null;
    return Supabase.instance.client.storage.from(_bucket).getPublicUrl(path);
  }
}
