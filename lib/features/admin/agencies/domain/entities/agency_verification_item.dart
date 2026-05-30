// Phase 19 (spec/019-agencies) — T038
// AgencyVerificationItem: admin-only composite entity (data-model §2.6).
// Composes Agency + AgencyVerificationRequest with the admin-only decrypted
// PII fields (populated by app_vault_secret_for_agency) + ownerDisplayName.
// Constitution IX: zero Supabase imports.
import 'package:equatable/equatable.dart';

import '../../../../../features/agency/domain/entities/agency.dart';
import '../../../../../features/agency/domain/entities/agency_verification_request.dart';

class AgencyVerificationItem extends Equatable {
  const AgencyVerificationItem({
    required this.agency,
    required this.request,
    this.ownerDisplayName,
    this.idDocumentNumber,
    this.commercialRegistrationNumber,
  });

  /// The agency profile (any status — admin sees pending/rejected as well).
  final Agency agency;

  /// The associated verification request (decision + evidence).
  final AgencyVerificationRequest request;

  /// Display name of the agency owner (joined from profiles.full_name).
  final String? ownerDisplayName;

  /// Admin-only — decrypted via `app_vault_secret_for_agency(id,'id_document_number')`.
  /// Visible only to `agencies.view` holders on the detail screen.
  final String? idDocumentNumber;

  /// Admin-only — decrypted via `app_vault_secret_for_agency(id,'commercial_registration_number')`.
  /// Visible only to `agencies.view` holders on the detail screen.
  final String? commercialRegistrationNumber;

  @override
  List<Object?> get props => [agency, request];
}
