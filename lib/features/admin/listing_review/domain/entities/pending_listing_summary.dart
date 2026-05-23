import 'package:equatable/equatable.dart';

import '../../../../../shared/domain/value_objects/money.dart';
import '../../../../listing_form/domain/entities/listing.dart';

/// Phase 12 (spec/012-listing-approval) — domain aggregate carrying the data
/// needed to render one queue card on `PendingQueuePage`.
///
/// `submittedAt` is sourced from `listings.created_at` per analysis finding C8
/// (decision locked in `contracts/phase12-admin-queue-page.md` — the listings
/// table's created_at column is indexed and avoids the
/// `MIN(changed_at) WHERE new_status='pending_review'` aggregate that
/// `listing_status_history` would require).
class PendingListingSummary extends Equatable {
  const PendingListingSummary({
    required this.id,
    required this.title,
    this.mainImageStoragePath,
    this.mainImageUrl,
    required this.purpose,
    required this.propertyType,
    required this.governorateName,
    required this.cityName,
    required this.areaName,
    this.primaryPrice,
    required this.publisherDisplayName,
    required this.submittedAt,
  });

  final String id;
  final String title;
  final String? mainImageStoragePath;

  /// Resolved public URL for [mainImageStoragePath] (computed in the
  /// datasource so the presentation layer remains Constitution IX-clean).
  final String? mainImageUrl;
  final ListingPurpose purpose;
  final PropertyType propertyType;
  final String governorateName;
  final String cityName;
  final String areaName;

  /// Null when the publisher has not yet saved the prices step (Phase 10
  /// allows submit with no prices; the queue card just hides the price line).
  final Money? primaryPrice;
  final String publisherDisplayName;
  final DateTime submittedAt;

  @override
  List<Object?> get props => [
    id,
    title,
    mainImageStoragePath,
    mainImageUrl,
    purpose,
    propertyType,
    governorateName,
    cityName,
    areaName,
    primaryPrice,
    publisherDisplayName,
    submittedAt,
  ];
}
