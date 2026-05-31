// Phase 19 (spec/019-agencies) — SupabaseAgencyDatasource.
//
// SOLE importer of supabase_flutter under lib/features/agency/ per
// Constitution IX. All Supabase I/O for the self-service agency feature:
//   - create_agency RPC (FR-001)
//   - v_agencies SELECT (FR-003 / FR-029)
//   - agency_members SELECT (FR-030)
//   - invite/respond/set_role/remove member RPCs (FR-013..FR-017)
//   - submit_agency_verification RPC + agency-documents bucket upload (FR-004/FR-006)
//   - v_listings_public SELECT cursor-paginated (FR-034 / SC-015)
//   - bounded analytics count queries (FR-034 / SC-015)

import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/agency_dto.dart';
import '../dtos/agency_member_dto.dart';

@injectable
class SupabaseAgencyDatasource {
  SupabaseAgencyDatasource(this._client);

  final supabase.SupabaseClient _client;

  // ---------------------------------------------------------------------------
  // Agency profile — write path
  // ---------------------------------------------------------------------------

  /// Calls `create_agency(p_name, p_description?, p_phone?, p_whatsapp?,
  /// p_address?)` SECURITY DEFINER RPC. Returns the new agency UUID.
  ///
  /// Throws [supabase.PostgrestException] on:
  ///   - auth_required (28000)
  ///   - not_a_publisher (42501)
  ///   - already_owns_agency (23505)
  ///   - invalid_name (22023)
  Future<String> createAgency({
    required String name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
  }) async {
    final result = await _client.rpc(
      'create_agency',
      params: {
        'p_name': name,
        if (description != null) 'p_description': description,
        if (phone != null) 'p_phone': phone,
        if (whatsapp != null) 'p_whatsapp': whatsapp,
        if (address != null) 'p_address': address,
      },
    );
    return result as String;
  }

  /// Calls `update_agency_profile(p_agency_id, ...)` SECURITY DEFINER RPC.
  /// Agency-admin only.
  ///
  /// Throws [supabase.PostgrestException] on permission_denied (42501).
  Future<void> updateProfile({
    required String agencyId,
    String? name,
    String? description,
    String? phone,
    String? whatsapp,
    String? address,
    String? logoPath,
    String? coverPath,
  }) async {
    await _client.rpc(
      'update_agency_profile',
      params: {
        'p_agency_id': agencyId,
        if (name != null) 'p_name': name,
        if (description != null) 'p_description': description,
        if (phone != null) 'p_phone': phone,
        if (whatsapp != null) 'p_whatsapp': whatsapp,
        if (address != null) 'p_address': address,
        if (logoPath != null) 'p_logo_path': logoPath,
        if (coverPath != null) 'p_cover_path': coverPath,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Agency profile — read path
  // ---------------------------------------------------------------------------

  /// Reads the current user's own agency row from `public.v_agencies`.
  /// The SECURITY DEFINER view ensures a member's own pending agency is
  /// visible. Returns `null` if the user has no agency.
  Future<AgencyDto?> loadMyAgency() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;

    final rows = await _client
        .from('v_agencies')
        .select()
        .eq('owner_user_id', uid)
        .limit(1);

    final list = rows as List<dynamic>;
    if (list.isEmpty) return null;
    return AgencyDto.fromJson(Map<String, dynamic>.from(list.first as Map));
  }

  /// Reads a single agency row by [agencyId] from `public.v_agencies`.
  /// The SECURITY DEFINER view returns approved agencies to anyone plus the
  /// caller's own agency at any status. Returns `null` when not visible.
  Future<AgencyDto?> loadAgencyById(String agencyId) async {
    final row = await _client
        .from('v_agencies')
        .select()
        .eq('id', agencyId)
        .maybeSingle();

    if (row == null) return null;
    return AgencyDto.fromJson(Map<String, dynamic>.from(row));
  }

  /// Loads the agencies the current user is an `active` member of.
  ///
  /// Two-step: read `agency_members` (user_id = current uid, status='active')
  /// for the agency ids, then fetch the matching `v_agencies` rows (which the
  /// definer view scopes to approved-or-own). Returns an empty list when the
  /// user is anonymous or a member of nothing.
  Future<List<AgencyDto>> loadMyActiveAgencies() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const <AgencyDto>[];

    final memberRows = await _client
        .from('agency_members')
        .select('agency_id')
        .eq('user_id', uid)
        .eq('status', 'active');

    final agencyIds = (memberRows as List<dynamic>)
        .map((r) => (r as Map)['agency_id'] as String)
        .toList();
    if (agencyIds.isEmpty) return const <AgencyDto>[];

    final rows = await _client
        .from('v_agencies')
        .select()
        .inFilter('id', agencyIds);

    return (rows as List<dynamic>)
        .map((r) => AgencyDto.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Verification — write path
  // ---------------------------------------------------------------------------

  /// Uploads [documentBytes] to the `agency-documents` private bucket at
  /// `'<agencyId>/<filename>'`, then calls `submit_agency_verification(
  /// p_agency_id, p_id_document_number, p_registration_number,
  /// p_evidence_urls?)`. Returns the new verification request UUID.
  ///
  /// Throws [supabase.StorageException] on upload failure.
  /// Throws [supabase.PostgrestException] on:
  ///   - permission_denied (42501)
  ///   - 23505 (open request already exists)
  Future<String> submitVerification({
    required String agencyId,
    required String idDocumentNumber,
    required String registrationNumber,
    List<String>? evidenceUrls,
  }) async {
    final result = await _client.rpc(
      'submit_agency_verification',
      params: {
        'p_agency_id': agencyId,
        'p_id_document_number': idDocumentNumber,
        'p_registration_number': registrationNumber,
        if (evidenceUrls != null) 'p_evidence_urls': evidenceUrls,
      },
    );
    return result as String;
  }

  /// Uploads a verification document file to the `agency-documents` bucket.
  /// Path shape: `'<agencyId>/<filename>'` (matches the storage policy uuid
  /// prefix regex — the policy checks `is_agency_admin` on the prefix UUID).
  ///
  /// Returns the Storage object path on success.
  Future<String> uploadVerificationDocument({
    required String agencyId,
    required String filename,
    required Uint8List bytes,
    String contentType = 'application/pdf',
  }) async {
    final path = '$agencyId/$filename';
    await _client.storage.from('agency-documents').uploadBinary(
          path,
          bytes,
          fileOptions: supabase.FileOptions(contentType: contentType),
        );
    return path;
  }

  // ---------------------------------------------------------------------------
  // Member operations — write path
  // ---------------------------------------------------------------------------

  /// Calls `invite_agency_member(p_agency_id, p_phone, p_role)`.
  /// Returns the invited user's UUID.
  ///
  /// Throws [supabase.PostgrestException] on:
  ///   - permission_denied (42501)
  ///   - invalid_role (22023)
  ///   - user_not_found (23503)
  Future<String> inviteMember({
    required String agencyId,
    required String phone,
    String role = 'agent',
  }) async {
    final result = await _client.rpc(
      'invite_agency_member',
      params: {
        'p_agency_id': agencyId,
        'p_phone': phone,
        'p_role': role,
      },
    );
    return result as String;
  }

  /// Calls `respond_agency_invitation(p_agency_id, p_accept)`.
  ///
  /// Throws [supabase.PostgrestException] on no_pending_invitation (P0002).
  Future<void> respondInvitation({
    required String agencyId,
    required bool accept,
  }) async {
    await _client.rpc(
      'respond_agency_invitation',
      params: {
        'p_agency_id': agencyId,
        'p_accept': accept,
      },
    );
  }

  /// Calls `set_agency_member_role(p_agency_id, p_user_id, p_role)`.
  ///
  /// Throws [supabase.PostgrestException] on:
  ///   - permission_denied (42501) / cannot_modify_owner / invalid_role (22023)
  Future<void> setMemberRole({
    required String agencyId,
    required String userId,
    required String role,
  }) async {
    await _client.rpc(
      'set_agency_member_role',
      params: {
        'p_agency_id': agencyId,
        'p_user_id': userId,
        'p_role': role,
      },
    );
  }

  /// Calls `remove_agency_member(p_agency_id, p_user_id)`.
  ///
  /// Throws [supabase.PostgrestException] on:
  ///   - permission_denied (42501) / cannot_remove_owner
  Future<void> removeMember({
    required String agencyId,
    required String userId,
  }) async {
    await _client.rpc(
      'remove_agency_member',
      params: {
        'p_agency_id': agencyId,
        'p_user_id': userId,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Member operations — read path
  // ---------------------------------------------------------------------------

  /// Loads the roster for [agencyId] from `public.agency_members`.
  /// RLS allows active members and `agencies.view` holders.
  Future<List<AgencyMemberDto>> loadMembers(String agencyId) async {
    final rows = await _client
        .from('agency_members')
        .select()
        .eq('agency_id', agencyId)
        .neq('status', 'removed');

    return (rows as List<dynamic>)
        .map(
          (row) =>
              AgencyMemberDto.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  /// Loads pending invitations for the current user across all agencies via
  /// `public.agency_members` (status = 'pending', user_id = auth.uid()).
  Future<List<AgencyMemberDto>> loadMyInvitations() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const <AgencyMemberDto>[];

    final rows = await _client
        .from('agency_members')
        .select()
        .eq('user_id', uid)
        .eq('status', 'pending');

    return (rows as List<dynamic>)
        .map(
          (row) =>
              AgencyMemberDto.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Listings — read path
  // ---------------------------------------------------------------------------

  /// Pages through listings for [agencyId] via `public.v_listings_public`
  /// (badge-augmented with approved agencies). Ordered by `published_at DESC`.
  /// [cursor] is an ISO-8601 timestamp for keyset pagination (mirrors Phase 13
  /// home-feed + Phase 17 favorites + Phase 18 reports convention).
  Future<List<Map<String, dynamic>>> loadAgencyListings({
    required String agencyId,
    String? cursor,
    int limit = 30,
  }) async {
    var query = _client
        .from('v_listings_public')
        .select()
        .eq('agency_id', agencyId);

    if (cursor != null) {
      query = query.lt('published_at', cursor);
    }

    final rows = await query
        .order('published_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Analytics — read path
  // ---------------------------------------------------------------------------

  /// Returns bounded analytics counters for [agencyId]:
  ///   - active member count
  ///   - listing counts grouped by status (via bounded COUNT queries)
  ///
  /// Uses `count: CountOption.exact` for the member count and a status-keyed
  /// map built from sequential bounded queries (SC-015 — LIMIT/cursor bounded).
  Future<({int memberCount, Map<String, int> listingsByStatus})>
      loadAnalyticsRaw(String agencyId) async {
    // Active member count (bounded — agency rosters are small).
    final memberResponse = await _client
        .from('agency_members')
        .select()
        .eq('agency_id', agencyId)
        .eq('status', 'active')
        .count(supabase.CountOption.exact);
    final memberCount = memberResponse.count;

    // Listing counts per status via v_listings_public (approved only) and the
    // listings table (all statuses for the owner's own analytics view).
    // We issue a single query and group in Dart to avoid N+1 per status.
    // Listings are still bounded by agency_id — each agency's set is finite.
    final listingRows = await _client
        .from('listings')
        .select('status')
        .eq('agency_id', agencyId)
        .limit(1000); // SC-015 bounded

    final byStatus = <String, int>{};
    for (final row in listingRows as List<dynamic>) {
      final status = (row as Map)['status'] as String? ?? 'unknown';
      byStatus[status] = (byStatus[status] ?? 0) + 1;
    }

    return (memberCount: memberCount, listingsByStatus: byStatus);
  }
}
