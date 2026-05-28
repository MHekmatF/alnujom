import '../../domain/entities/lead_event.dart';
import '../../domain/entities/lead_event_type.dart';

/// DTO mirroring a row from either `public.v_lead_events_publisher`
/// (5 columns, no metadata) or `public.v_lead_events_admin` (6 columns,
/// with metadata). The [metadata] field is null-safe to handle both tiers.
///
/// Publisher tier columns: id, listing_id, user_id, event_type, created_at.
/// Admin tier adds:        metadata (JSONB, null-safe).
class LeadEventDto {
  const LeadEventDto({
    required this.id,
    required this.listingId,
    required this.userId,
    required this.eventType,
    required this.createdAt,
    this.metadata,
  });

  final String id;
  final String listingId;
  final String? userId;
  final String eventType;
  final DateTime createdAt;

  /// Present only in the admin-tier view (v_lead_events_admin).
  /// Publisher-tier rows omit this column entirely → null here.
  final Map<String, dynamic>? metadata;

  factory LeadEventDto.fromJson(Map<String, dynamic> json) {
    return LeadEventDto(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      userId: json['user_id'] as String?,
      eventType: json['event_type'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  LeadEvent toEntity() {
    return LeadEvent(
      id: id,
      listingId: listingId,
      userId: userId,
      eventType: LeadEventType.fromWire(eventType),
      metadata: metadata,
      createdAt: createdAt,
    );
  }
}
