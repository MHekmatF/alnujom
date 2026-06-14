import 'package:equatable/equatable.dart';

import 'revision_manifest_item.dart';

/// Phase 031 (WS-B) — the publisher/admin-facing view of one `listing_revisions`
/// row: the staged `proposed` scalar/detail/price snapshot (kept as a raw map
/// keyed by the RPC's exact JSON keys) plus the parsed media manifest.
///
/// The form maps [proposed] onto the in-memory draft entities; the manifest is
/// rendered in the picker and edited in place. Status mirrors the DB CHECK
/// (`draft|pending_review|approved|rejected`).
class ListingRevision extends Equatable {
  const ListingRevision({
    required this.id,
    required this.status,
    required this.proposed,
    required this.manifest,
  });

  final String id;
  final String status;

  /// Raw `proposed` JSON object (exact RPC keys, e.g. `title`, `governorate_id`,
  /// `price_amount`, `amenities`…). The form reads/writes via these keys.
  final Map<String, dynamic> proposed;
  final List<RevisionManifestItem> manifest;

  bool get isPending => status == 'pending_review';
  bool get isDraft => status == 'draft';

  @override
  List<Object?> get props => [id, status, proposed, manifest];
}
