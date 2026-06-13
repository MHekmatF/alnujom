import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;

/// Phase 029 (Reels W4) — storage-URL resolver for reel media.
///
/// Mirrors [PanoramaTourUrlResolver] / [ListingDetailsVideoLauncher]: it lives
/// in the data layer so the reels presentation layer (the player + rail) can
/// render public Supabase URLs without importing `package:supabase_flutter`
/// (Constitution IX boundary).
///
/// Videos live in the `listing-videos` bucket and poster stills in
/// `listing-images` (per 20260522120002_create_listing_media_storage_buckets).
abstract final class ReelsStorageUrlResolver {
  static const String _videoBucket = 'listing-videos';
  static const String _imageBucket = 'listing-images';

  /// Public URL for a video [storagePath] (listing-videos bucket); null/empty
  /// in → null out.
  static String? video(String? storagePath) =>
      _resolve(_videoBucket, storagePath);

  /// Public URL for a poster image [storagePath] (listing-images bucket).
  static String? poster(String? storagePath) =>
      _resolve(_imageBucket, storagePath);

  static String? _resolve(String bucket, String? path) {
    if (path == null || path.isEmpty) return null;
    // Guard against an already-resolved full URL (defensive — current writers
    // store bare paths, but mirror the home datasource's http-prefix guard).
    if (path.startsWith('http')) return path;
    return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
  }
}
