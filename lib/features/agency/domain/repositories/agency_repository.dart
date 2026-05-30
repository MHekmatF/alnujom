// Phase 19 (spec/019-agencies) — AgencyRepository interface.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.
// The concrete implementation lives in data/repositories/.

import '../../../../core/errors/result.dart';
import '../entities/agency.dart';
import '../entities/agency_member.dart';

/// Analytics counters for an agency's self-service dashboard.
class AgencyAnalytics {
  const AgencyAnalytics({
    required this.memberCount,
    required this.listingsByStatus,
  });

  /// Total active member count for the agency.
  final int memberCount;

  /// Map of listing status wire value → count (e.g. {'approved': 5, 'pending_review': 2}).
  final Map<String, int> listingsByStatus;
}

abstract interface class AgencyRepository {
  /// Calls the `create_agency(name, description?, phone?, whatsapp?, address?)`
  /// SECURITY DEFINER RPC. Authenticated + approved publisher only; one agency
  /// per owner.
  ///
  /// Returns [Success] with the new agency UUID on success.
  /// Returns [FailureResult] on:
  ///   - auth_required (28000)
  ///   - not_a_publisher (42501)
  ///   - already_owns_agency (23505)
  ///   - invalid_name (22023)
  Future<Result<String>> createAgency({
    required String name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
  });

  /// Reads the current user's own agency via `public.v_agencies`.
  /// Returns [Success] with the [Agency] if found, `null` if the user has no
  /// agency yet.
  Future<Result<Agency?>> loadMyAgency();

  /// Updates the agency profile fields via the `update_agency_profile` RPC.
  /// Agency-admin only.
  Future<Result<void>> updateProfile({
    required String agencyId,
    String? name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
    String? logoPath,
    String? coverPath,
  });

  /// Uploads document bytes to the `agency-documents` bucket then calls
  /// `submit_agency_verification(agency_id, id_document_number,
  /// registration_number, evidence_urls?)`. Agency-admin only; one open
  /// request per agency.
  ///
  /// Returns [Success] with the new verification request UUID.
  /// Returns [FailureResult] on:
  ///   - permission_denied (42501)
  ///   - 23505 (open request already exists)
  Future<Result<String>> submitVerification({
    required String agencyId,
    required String idDocumentNumber,
    required String registrationNumber,
    List<String>? evidenceUrls,
  });

  /// Loads the active roster for [agencyId] via `public.agency_members`.
  /// Accessible to the caller when they are themselves an active member or
  /// hold `agencies.view`.
  Future<Result<List<AgencyMember>>> loadMembers(String agencyId);

  /// Calls `invite_agency_member(agency_id, phone, role)`. Agency-admin only;
  /// resolves the phone to an existing account.
  ///
  /// Returns [Success] with the invited user's UUID.
  /// Returns [FailureResult] on:
  ///   - permission_denied (42501)
  ///   - invalid_role (22023)
  ///   - user_not_found (23503)
  Future<Result<String>> inviteMember({
    required String agencyId,
    required String phone,
    String role = 'agent',
  });

  /// Calls `respond_agency_invitation(agency_id, accept)`. Invitee only
  /// (bound to `auth.uid()`).
  ///
  /// Returns [FailureResult] on:
  ///   - no_pending_invitation (P0002)
  Future<Result<void>> respondInvitation({
    required String agencyId,
    required bool accept,
  });

  /// Calls `set_agency_member_role(agency_id, user_id, role)`.
  /// Agency-admin only; owner is protected.
  ///
  /// Returns [FailureResult] on:
  ///   - permission_denied (42501)
  ///   - invalid_role (22023)
  ///   - cannot_modify_owner (42501)
  Future<Result<void>> setMemberRole({
    required String agencyId,
    required String userId,
    required String role,
  });

  /// Calls `remove_agency_member(agency_id, user_id)`.
  /// Agency-admin only; owner is protected.
  ///
  /// Returns [FailureResult] on:
  ///   - permission_denied (42501)
  ///   - cannot_remove_owner (42501)
  Future<Result<void>> removeMember({
    required String agencyId,
    required String userId,
  });

  /// Loads pending invitations for the current user across all agencies via
  /// `public.agency_members` (status = 'pending').
  Future<Result<List<AgencyMember>>> loadMyInvitations();

  /// Pages through the listings for [agencyId] via `public.v_listings_public`,
  /// ordered by `published_at DESC`. [cursor] is an ISO-8601 timestamp for
  /// keyset pagination; pass `null` for the first page.
  Future<Result<List<Map<String, dynamic>>>> loadAgencyListings({
    required String agencyId,
    String? cursor,
    int limit = 30,
  });

  /// Returns bounded analytics counters for [agencyId]: active member count +
  /// listing-by-status counts.
  Future<Result<AgencyAnalytics>> loadAnalytics(String agencyId);
}
