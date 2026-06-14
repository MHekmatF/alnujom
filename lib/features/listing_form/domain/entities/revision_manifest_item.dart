import 'package:equatable/equatable.dart';

import 'listing_media.dart';

/// Phase 031 (WS-B) — one entry in a listing revision's staged media manifest.
///
/// Mirrors EXACTLY the JSON object the `begin/save/apply_listing_revision`
/// RPCs read/write in `listing_revisions.media_manifest` (a JSON array of):
///   `{storage_path, kind, is_main, ordering, thumbnail_path}`.
///
/// During a stay-live revision the publisher's media edits are staged into a
/// list of these items (NOT live `listing_media` rows). New uploads land in the
/// same `{listingId}/` bucket path but only append a manifest entry; removals
/// drop an entry; reorders/set-main rewrite `ordering`/`is_main`. The admin's
/// `apply_listing_revision` later reconciles `listing_media` to the manifest.
class RevisionManifestItem extends Equatable {
  const RevisionManifestItem({
    required this.storagePath,
    required this.kind,
    required this.isMain,
    required this.ordering,
    this.thumbnailPath,
  });

  /// Bucket object path (`{listingId}/{suffix}.jpg|.mp4`). The reconcile key.
  final String storagePath;

  /// Free-text DB `kind` token verbatim: `image` | `video` | `panorama`.
  final String kind;
  final bool isMain;
  final int ordering;
  final String? thumbnailPath;

  /// Maps to the exact JSON shape the RPCs expect.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'storage_path': storagePath,
    'kind': kind,
    'is_main': isMain,
    'ordering': ordering,
    'thumbnail_path': thumbnailPath,
  };

  /// Parses one manifest object as returned by `begin_listing_revision`.
  factory RevisionManifestItem.fromJson(Map<String, dynamic> json) {
    return RevisionManifestItem(
      storagePath: json['storage_path'] as String,
      kind: (json['kind'] as String?) ?? 'image',
      isMain: (json['is_main'] as bool?) ?? false,
      ordering: (json['ordering'] as num?)?.toInt() ?? 0,
      thumbnailPath: json['thumbnail_path'] as String?,
    );
  }

  RevisionManifestItem copyWith({
    String? storagePath,
    String? kind,
    bool? isMain,
    int? ordering,
    Object? thumbnailPath = _sentinel,
  }) {
    return RevisionManifestItem(
      storagePath: storagePath ?? this.storagePath,
      kind: kind ?? this.kind,
      isMain: isMain ?? this.isMain,
      ordering: ordering ?? this.ordering,
      thumbnailPath: identical(thumbnailPath, _sentinel)
          ? this.thumbnailPath
          : thumbnailPath as String?,
    );
  }

  /// Renders this staged item as a [ListingMedia] for the picker grid. The
  /// `id` is synthesized from [storagePath] (stable across rebuilds and unique
  /// within a revision) since no live row exists yet. The enum [kind] collapses
  /// `panorama` → image while [ListingMedia.rawKind] preserves the token so the
  /// 360° badge/affordance still works.
  ListingMedia toMedia(String listingId) {
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    return ListingMedia(
      id: storagePath,
      listingId: listingId,
      kind: ListingMediaKind.fromDbValue(kind),
      rawKind: kind,
      storagePath: storagePath,
      thumbnailPath: thumbnailPath,
      ordering: ordering,
      isMain: isMain,
      // Revision images are always watermarked at upload time (parity with the
      // live image upload path); the flag is unused by the picker.
      watermarked: kind == 'image',
      createdAt: epoch,
      updatedAt: epoch,
    );
  }

  @override
  List<Object?> get props => [
    storagePath,
    kind,
    isMain,
    ordering,
    thumbnailPath,
  ];
}

const Object _sentinel = Object();
