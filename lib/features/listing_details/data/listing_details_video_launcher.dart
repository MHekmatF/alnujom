import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:url_launcher/url_launcher.dart';

import '../../../features/listing_form/domain/entities/listing_media.dart';

/// Phase 13 (spec/013-home-and-details) — video-tap launcher helper.
///
/// Resolves the public storage URL for a video [ListingMedia] item and
/// launches it via [url_launcher] in the OS external player per FR-027.
///
/// This helper lives in the data layer so that the presentation layer
/// ([ListingDetailsPage]) can delegate Supabase URL resolution here,
/// keeping `package:supabase_flutter` out of the presentation layer per
/// FR-030.
///
/// The [ListingGallery] Phase 12 Q8=A widget itself already uses
/// `Supabase.instance.client` in the shared presentation layer (its own
/// documented Constitution IX exception per phase12-shared-display-widgets.md).
/// This helper avoids adding a second violation to the listing_details
/// presentation layer.
abstract final class ListingDetailsVideoLauncher {
  /// Resolves the public storage URL for [media] and launches it in the OS
  /// external player via [launchUrl] with [LaunchMode.externalApplication]
  /// per FR-027.
  ///
  /// No-op if [media.storagePath] is null or the URL cannot be launched.
  static Future<void> launch(ListingMedia media) async {
    if (media.storagePath == null) return;
    final url = Supabase.instance.client.storage
        .from('listing-images')
        .getPublicUrl(media.storagePath!);
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
