import 'package:equatable/equatable.dart';

/// Phase 029 (Reels W4) — one video reel: an approved, in-window, published
/// listing that carries at least one video, projected by the
/// `list_video_reels` RPC.
///
/// Locale-resolved location names and the already-resolved public storage URLs
/// for the video + poster come from the data layer (`ReelDto.toEntity` +
/// `ReelsStorageUrlResolver`), so the presentation layer never touches
/// `package:supabase_flutter` (Constitution IX boundary).
class Reel extends Equatable {
  const Reel({
    required this.listingId,
    required this.title,
    required this.propertyType,
    required this.purpose,
    required this.locationLabel,
    required this.publishedAt,
    required this.videoUrl,
    this.posterImageUrl,
    this.priceAmount,
    this.priceCurrency,
  });

  final String listingId;
  final String title;

  /// Listings enum string (`apartment` / `villa` / ...). The presentation layer
  /// maps it to a localized label.
  final String propertyType;

  /// Listings enum string (`sale` / `rent` / ...).
  final String purpose;

  /// Locale-resolved "City، Governorate" style label (already joined for the
  /// active locale; em-dash when neither name is present).
  final String locationLabel;

  /// Keyset anchor — also the sort key paired with [listingId].
  final DateTime publishedAt;

  /// Resolved public URL for the listing's first video (`listing-videos`
  /// bucket). Always present (the RPC INNER-JOINs on a video row).
  final String videoUrl;

  /// Resolved public URL for the poster still (`listing-images` bucket); null
  /// when the listing has no image rows (the player falls back to a neutral
  /// surface until the controller initializes).
  final String? posterImageUrl;

  /// Primary price amount as a plain string (formatted in the UI with the
  /// active locale's numerals); null when no primary price row exists.
  final String? priceAmount;

  /// Primary price ISO currency code; null alongside [priceAmount].
  final String? priceCurrency;

  bool get hasPrice =>
      priceAmount != null &&
      priceAmount!.isNotEmpty &&
      priceCurrency != null &&
      priceCurrency!.isNotEmpty;

  @override
  List<Object?> get props => [
    listingId,
    title,
    propertyType,
    purpose,
    locationLabel,
    publishedAt,
    videoUrl,
    posterImageUrl,
    priceAmount,
    priceCurrency,
  ];
}
