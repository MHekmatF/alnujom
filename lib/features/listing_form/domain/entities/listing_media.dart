import 'package:equatable/equatable.dart';

/// Phase 11 — Listing media entity.
///
/// Two kinds are surfaced through the Phase 11 entity layer per Q2=D:
/// `image` and `video`. The schema enum also retains `'external_link'`
/// for future-spec forward-compat, but no Phase 11 UI path inserts such
/// rows; the DTO maps unknown enum values defensively to [ListingMediaKind.image]
/// so the picker can render a broken-image placeholder if an admin direct-SQL
/// inserts an external_link row.
enum ListingMediaKind {
  image,
  video;

  String toDbValue() {
    switch (this) {
      case ListingMediaKind.image:
        return 'image';
      case ListingMediaKind.video:
        return 'video';
    }
  }

  /// Defensive parser — admin direct SQL can insert `'external_link'` rows;
  /// the entity surface maps them to [image] so the picker renders a
  /// broken-image placeholder rather than crashing.
  static ListingMediaKind fromDbValue(String value) {
    switch (value) {
      case 'image':
        return ListingMediaKind.image;
      case 'video':
        return ListingMediaKind.video;
      default:
        // 'external_link' or any unknown — defensive default per data-model § 8.2
        return ListingMediaKind.image;
    }
  }
}

/// The raw DB `kind` string written for a 360°/virtual-tour panorama row.
///
/// `listing_media.kind` is free text at the DB layer. A panorama is an
/// equirectangular image (so [ListingMediaKind.fromDbValue] maps it to
/// [ListingMediaKind.image] — it renders normally in the gallery), but the
/// original token is preserved in [ListingMedia.rawKind] so the listing-details
/// gallery can offer a 360° viewer affordance and the media picker can toggle it.
const String kListingMediaKindPanorama = 'panorama';

class ListingMedia extends Equatable {
  const ListingMedia({
    required this.id,
    required this.listingId,
    required this.kind,
    this.rawKind,
    this.storagePath,
    this.externalUrl,
    required this.ordering,
    required this.isMain,
    required this.watermarked,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String listingId;
  final ListingMediaKind kind;

  /// The original free-text `kind` string from the DB row, preserved verbatim.
  ///
  /// Defaults to null when constructed outside the DTO mapping. Used to detect
  /// kinds the closed [ListingMediaKind] enum cannot represent (notably
  /// [kListingMediaKindPanorama]); [kind] still collapses such rows to
  /// [ListingMediaKind.image] for backward-compatible rendering.
  final String? rawKind;
  final String? storagePath;
  final String? externalUrl;
  final int ordering;
  final bool isMain;
  final bool watermarked;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True when this row is a 360°/virtual-tour panorama (an equirectangular
  /// image) — detected from the preserved free-text [rawKind], not the enum.
  bool get isPanorama =>
      rawKind == kListingMediaKindPanorama && storagePath != null;

  ListingMedia copyWith({
    String? id,
    String? listingId,
    ListingMediaKind? kind,
    String? rawKind,
    String? storagePath,
    String? externalUrl,
    int? ordering,
    bool? isMain,
    bool? watermarked,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ListingMedia(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      kind: kind ?? this.kind,
      rawKind: rawKind ?? this.rawKind,
      storagePath: storagePath ?? this.storagePath,
      externalUrl: externalUrl ?? this.externalUrl,
      ordering: ordering ?? this.ordering,
      isMain: isMain ?? this.isMain,
      watermarked: watermarked ?? this.watermarked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    listingId,
    kind,
    rawKind,
    storagePath,
    externalUrl,
    ordering,
    isMain,
    watermarked,
    createdAt,
    updatedAt,
  ];
}
