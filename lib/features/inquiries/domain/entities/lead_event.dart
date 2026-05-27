import 'package:equatable/equatable.dart';

import 'lead_event_type.dart';

class LeadEvent extends Equatable {
  const LeadEvent({
    required this.id,
    required this.listingId,
    required this.userId,
    required this.eventType,
    required this.metadata,
    required this.createdAt,
  });

  final String id;
  final String listingId;
  final String? userId;
  final LeadEventType eventType;

  /// Null for the publisher tier per FR-014b. Populated for admin tier.
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, listingId, userId, eventType, metadata, createdAt];
}
