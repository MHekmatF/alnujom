import 'package:equatable/equatable.dart';

import 'listing_revision.dart';

/// Phase 031 (WS-B) — one row in the admin pending-revisions queue: a revision
/// awaiting review plus the id of the live listing it edits and when it was
/// submitted. The proposed snapshot + manifest live on [revision].
class PendingRevision extends Equatable {
  const PendingRevision({
    required this.revision,
    required this.listingId,
    required this.submittedAt,
  });

  final ListingRevision revision;
  final String listingId;
  final DateTime submittedAt;

  /// Convenience: the proposed listing title (or empty).
  String get proposedTitle {
    final t = revision.proposed['title'];
    return t is String ? t : '';
  }

  @override
  List<Object?> get props => [revision, listingId, submittedAt];
}
