import '../../../listing_form/domain/entities/listing.dart';
import '../../../listing_form/domain/entities/listing_status_history_entry.dart';

/// Flat DTO for `public.listing_status_history`. The view exposes these via
/// `latest_history_*` columns; this DTO is also reused for direct table reads
/// in Phase 12 (admin reject path).
class ListingStatusHistoryEntryDto {
  ListingStatusHistoryEntryDto({
    required this.id,
    required this.listingId,
    required this.previousStatus,
    required this.newStatus,
    required this.changedBy,
    required this.changedAt,
    required this.reason,
  });

  final String id;
  final String listingId;
  final String? previousStatus;
  final String newStatus;
  final String? changedBy;
  final DateTime changedAt;
  final String? reason;

  static ListingStatusHistoryEntryDto fromMap(Map<String, dynamic> row) {
    return ListingStatusHistoryEntryDto(
      id: row['id'] as String,
      listingId: row['listing_id'] as String,
      previousStatus: row['previous_status'] as String?,
      newStatus: row['new_status'] as String,
      changedBy: row['changed_by'] as String?,
      changedAt: DateTime.parse(row['changed_at'] as String),
      reason: row['reason'] as String?,
    );
  }

  ListingStatusHistoryEntry toEntity() {
    return ListingStatusHistoryEntry(
      id: id,
      listingId: listingId,
      previousStatus: previousStatus == null
          ? null
          : ListingStatusDb.fromDbValue(previousStatus!),
      newStatus: ListingStatusDb.fromDbValue(newStatus),
      changedBy: changedBy,
      changedAt: changedAt,
      reason: reason,
    );
  }
}
