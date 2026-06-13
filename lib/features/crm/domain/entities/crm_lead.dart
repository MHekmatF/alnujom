// lib/features/crm/domain/entities/crm_lead.dart
//
// Phase 029 — CRM domain entity: one lead in the publisher's pipeline.

import 'crm_stage.dart';

class CrmLead {
  const CrmLead({
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
  final CrmStage stage;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The signed-in contact this lead represents (chat/viewing/inquirer), or
  /// the publisher themselves for a manual lead.
  final String? contactUserId;

  /// The inquiry this lead originated from (when sourced from the inbox).
  final String? sourceInquiryId;

  /// The listing this lead is associated with (heading hint), when known.
  final String? listingId;

  /// True when this lead exposes a chat contact (drives the in-app Chat action).
  bool get hasContact => contactUserId != null;

  CrmLead copyWith({CrmStage? stage, String? displayName}) => CrmLead(
    id: id,
    displayName: displayName ?? this.displayName,
    stage: stage ?? this.stage,
    createdAt: createdAt,
    updatedAt: updatedAt,
    contactUserId: contactUserId,
    sourceInquiryId: sourceInquiryId,
    listingId: listingId,
  );
}
