// Phase 19 (spec/019-agencies) — T041
// AgencyVerificationItemDto: maps the joined v_agencies + agency_verification_requests
// row onto the admin AgencyVerificationItem entity. The decrypted PII fields
// (idDocumentNumber / commercialRegistrationNumber) come from a separate
// app_vault_secret_for_agency RPC call and are injected before toEntity().
// Constitution IX: no Supabase imports.
import '../../../../agency/domain/entities/agency.dart';
import '../../../../agency/domain/entities/agency_status.dart';
import '../../../../agency/domain/entities/agency_verification_request.dart';
import '../../domain/entities/agency_verification_item.dart';

class AgencyVerificationItemDto {
  const AgencyVerificationItemDto({
    // Agency fields (from v_agencies)
    required this.agencyId,
    required this.ownerUserId,
    required this.agencyName,
    required this.agencyStatus,
    required this.agencyCreatedAt,
    this.agencyDescription,
    this.agencyPhone,
    this.agencyWhatsapp,
    this.agencyAddress,
    this.agencyLogoPath,
    this.agencyCoverPath,
    // Verification request fields (from agency_verification_requests)
    required this.requestId,
    required this.decision,
    required this.submittedAt,
    this.decisionReason,
    this.evidenceUrls,
    this.reviewedAt,
    // Owner profile (joined)
    this.ownerDisplayName,
    // Admin-only Vault-decrypted fields (populated by separate RPC calls)
    this.idDocumentNumber,
    this.commercialRegistrationNumber,
  });

  // Agency
  final String agencyId;
  final String ownerUserId;
  final String agencyName;
  final String agencyStatus;
  final String agencyCreatedAt;
  final String? agencyDescription;
  final String? agencyPhone;
  final String? agencyWhatsapp;
  final String? agencyAddress;
  final String? agencyLogoPath;
  final String? agencyCoverPath;

  // Verification request
  final String requestId;
  final String decision;
  final String submittedAt;
  final String? decisionReason;
  final List<String>? evidenceUrls;
  final String? reviewedAt;

  // Joined
  final String? ownerDisplayName;

  // Injected after Vault RPC calls
  final String? idDocumentNumber;
  final String? commercialRegistrationNumber;

  /// Constructs a DTO from the joined query row.
  ///
  /// The query is expected to join v_agencies with agency_verification_requests
  /// on agency_id, optionally joining profiles for ownerDisplayName.
  factory AgencyVerificationItemDto.fromJson(Map<String, dynamic> json) {
    // Parse evidence_urls from JSONB array
    List<String>? evidenceUrls;
    final rawUrls = json['evidence_urls'];
    if (rawUrls != null) {
      evidenceUrls = (rawUrls as List<dynamic>)
          .map((e) => e as String)
          .toList(growable: false);
    }

    return AgencyVerificationItemDto(
      agencyId: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      agencyName: json['name'] as String,
      agencyStatus: json['status'] as String,
      agencyCreatedAt: json['created_at'] as String,
      agencyDescription: json['description'] as String?,
      agencyPhone: json['phone'] as String?,
      agencyWhatsapp: json['whatsapp'] as String?,
      agencyAddress: json['address'] as String?,
      agencyLogoPath: json['logo_path'] as String?,
      agencyCoverPath: json['cover_path'] as String?,
      // Verification request (nested or flattened — support both shapes)
      requestId: (json['request_id'] ?? json['avr_id']) as String,
      decision: json['decision'] as String,
      submittedAt: json['submitted_at'] as String,
      decisionReason: json['decision_reason'] as String?,
      evidenceUrls: evidenceUrls,
      reviewedAt: json['reviewed_at'] as String?,
      // Owner profile (optional join)
      ownerDisplayName: json['owner_display_name'] as String?,
    );
  }

  /// Returns a copy with admin-only Vault fields populated.
  AgencyVerificationItemDto withVaultFields({
    String? idDocumentNumber,
    String? commercialRegistrationNumber,
  }) {
    return AgencyVerificationItemDto(
      agencyId: agencyId,
      ownerUserId: ownerUserId,
      agencyName: agencyName,
      agencyStatus: agencyStatus,
      agencyCreatedAt: agencyCreatedAt,
      agencyDescription: agencyDescription,
      agencyPhone: agencyPhone,
      agencyWhatsapp: agencyWhatsapp,
      agencyAddress: agencyAddress,
      agencyLogoPath: agencyLogoPath,
      agencyCoverPath: agencyCoverPath,
      requestId: requestId,
      decision: decision,
      submittedAt: submittedAt,
      decisionReason: decisionReason,
      evidenceUrls: evidenceUrls,
      reviewedAt: reviewedAt,
      ownerDisplayName: ownerDisplayName,
      idDocumentNumber: idDocumentNumber,
      commercialRegistrationNumber: commercialRegistrationNumber,
    );
  }

  AgencyVerificationItem toEntity() {
    final agency = Agency(
      id: agencyId,
      ownerUserId: ownerUserId,
      name: agencyName,
      status: AgencyStatus.fromWire(agencyStatus),
      createdAt: DateTime.parse(agencyCreatedAt),
      description: agencyDescription,
      phone: agencyPhone,
      whatsapp: agencyWhatsapp,
      address: agencyAddress,
      logoPath: agencyLogoPath,
      coverPath: agencyCoverPath,
    );

    final request = AgencyVerificationRequest(
      id: requestId,
      agencyId: agencyId,
      decision: VerificationDecision.fromWire(decision),
      submittedAt: DateTime.parse(submittedAt),
      decisionReason: decisionReason,
      evidenceUrls: evidenceUrls,
      reviewedAt: reviewedAt != null ? DateTime.parse(reviewedAt!) : null,
    );

    return AgencyVerificationItem(
      agency: agency,
      request: request,
      ownerDisplayName: ownerDisplayName,
      idDocumentNumber: idDocumentNumber,
      commercialRegistrationNumber: commercialRegistrationNumber,
    );
  }
}
