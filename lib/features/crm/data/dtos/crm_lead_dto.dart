// lib/features/crm/data/dtos/crm_lead_dto.dart
//
// Phase 029 — DTO mirroring a public.crm_leads row.

import '../../domain/entities/crm_lead.dart';
import '../../domain/entities/crm_stage.dart';

class CrmLeadDto {
  const CrmLeadDto({
    required this.id,
    required this.displayName,
    required this.stage,
    required this.createdAt,
    required this.updatedAt,
    this.contactUserId,
    this.sourceInquiryId,
    this.listingId,
  });

  final String id;
  final String displayName;
  final String stage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? contactUserId;
  final String? sourceInquiryId;
  final String? listingId;

  factory CrmLeadDto.fromJson(Map<String, dynamic> json) => CrmLeadDto(
    id: json['id'] as String,
    displayName: json['display_name'] as String? ?? '',
    stage: json['stage'] as String? ?? 'new',
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(
      (json['updated_at'] ?? json['created_at']) as String,
    ),
    contactUserId: json['contact_user_id'] as String?,
    sourceInquiryId: json['source_inquiry_id'] as String?,
    listingId: json['listing_id'] as String?,
  );

  /// Maps to the domain entity. [currentUserId] lets us treat a self-anchored
  /// manual lead as having no real chat contact.
  CrmLead toEntity(String currentUserId) {
    final isSelfAnchored =
        contactUserId != null && contactUserId == currentUserId;
    return CrmLead(
      id: id,
      displayName: displayName,
      stage: CrmStage.fromWire(stage),
      createdAt: createdAt,
      updatedAt: updatedAt,
      contactUserId: isSelfAnchored ? null : contactUserId,
      sourceInquiryId: sourceInquiryId,
      listingId: listingId,
    );
  }
}
