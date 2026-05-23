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

class ListingMedia extends Equatable {
  const ListingMedia({
    required this.id,
    required this.listingId,
    required this.kind,
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
  final String? storagePath;
  final String? externalUrl;
  final int ordering;
  final bool isMain;
  final bool watermarked;
  final DateTime createdAt;
  final DateTime updatedAt;

  ListingMedia copyWith({
    String? id,
    String? listingId,
    ListingMediaKind? kind,
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
    storagePath,
    externalUrl,
    ordering,
    isMain,
    watermarked,
    createdAt,
    updatedAt,
  ];
}
