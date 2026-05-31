// Phase 19 (spec/019-agencies) — T042
// SupabaseAgenciesAdminDatasource: sole importer of package:supabase_flutter
// in lib/features/admin/agencies/ (Constitution IX).
//
// Three families of methods:
//   - loadQueue  — agency_verification_requests joined with v_agencies,
//                  filtered to pending, cursor-paginated (FR-007 / SC-015).
//   - loadDetail — single agency row + verification request + Vault-decrypted
//                  PII via app_vault_secret_for_agency (SC-010).
//   - moderate   — functions.invoke('moderate_agency', body:{...}), mirroring
//                  the Phase 18 resolve_report / Phase 12 approve_listing pattern.
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../dtos/agency_verification_item_dto.dart';

/// Lightweight wrapper around Supabase FunctionResponse so the repository
/// can branch on `status` without importing supabase_flutter itself.
class AgencyAdminEdgeFunctionResponse {
  AgencyAdminEdgeFunctionResponse({required this.status, required this.data});

  final int status;
  final dynamic data;
}

@injectable
class SupabaseAgenciesAdminDatasource {
  SupabaseAgenciesAdminDatasource(this._client);

  final supabase.SupabaseClient _client;

  // ─── loadQueue ────────────────────────────────────────────────────────────

  /// Returns one page of the verification queue ordered newest-first.
  ///
  /// Joins agency_verification_requests (decision='pending') with v_agencies
  /// and optionally with profiles for owner display names.
  ///
  /// [statusWire] — filter on agency status (e.g. 'pending'); null = all.
  /// [cursor]     — ISO-8601 `submitted_at` of the last item on the previous
  ///               page; null for the first page.
  Future<List<AgencyVerificationItemDto>> loadQueue({
    String? statusWire,
    String? cursor,
    int limit = 30,
  }) async {
    // Query agency_verification_requests (pending only) joined with agencies.
    // We select a flattened shape that the DTO's fromJson can parse.
    var query = _client
        .from('agency_verification_requests')
        .select(
          'avr_id:id, decision, submitted_at, decision_reason, evidence_urls, reviewed_at, '
          'agencies!inner(id, owner_user_id, name, status, created_at, description, phone, whatsapp, address, logo_path, cover_path)',
        );

    // Default (no filter) = the open verification queue (pending requests).
    // A status filter instead targets the AGENCY's status: an approved /
    // suspended / rejected agency no longer has a 'pending' request, so gating
    // on decision='pending' hid every non-pending agency — which made the
    // Approved/Rejected/Suspended filter chips return nothing and left
    // suspend/reinstate unreachable from the admin UI.
    if (statusWire == null) {
      query = query.eq('decision', 'pending');
    } else {
      query = query.eq('agencies.status', statusWire);
    }
    if (cursor != null) {
      query = query.lt('submitted_at', cursor);
    }

    final rows = await query
        .order('submitted_at', ascending: false)
        .limit(limit);

    return (rows as List<dynamic>).map((r) {
      final row = Map<String, dynamic>.from(r as Map);
      // Flatten the nested agencies join into the top-level map.
      final agencyMap = Map<String, dynamic>.from(row['agencies'] as Map);
      return AgencyVerificationItemDto.fromJson({
        ...agencyMap,
        'avr_id': row['avr_id'],
        'decision': row['decision'],
        'submitted_at': row['submitted_at'],
        'decision_reason': row['decision_reason'],
        'evidence_urls': row['evidence_urls'],
        'reviewed_at': row['reviewed_at'],
      });
    }).toList();
  }

  // ─── loadDetail ───────────────────────────────────────────────────────────

  /// Loads the full detail for a single agency including the admin-only
  /// Vault-decrypted PII fields (idDocumentNumber + commercialRegistrationNumber).
  Future<AgencyVerificationItemDto> loadDetail(String agencyId) async {
    // Load the agency from v_agencies (admin sees any status).
    final agencyRow = await _client
        .from('v_agencies')
        .select()
        .eq('id', agencyId)
        .single();

    // Load the most recent verification request for this agency.
    final requestRow = await _client
        .from('agency_verification_requests')
        .select()
        .eq('agency_id', agencyId)
        .order('created_at', ascending: false)
        .limit(1)
        .single();

    // Decrypt both Vault-stored PII fields (returns null for non-admin callers).
    final idNumber = await _decryptVaultField(agencyId, 'id_document_number');
    final regNumber = await _decryptVaultField(
      agencyId,
      'commercial_registration_number',
    );

    final dto = AgencyVerificationItemDto.fromJson({
      ...Map<String, dynamic>.from(agencyRow),
      'avr_id': requestRow['id'],
      'decision': requestRow['decision'],
      'submitted_at': requestRow['submitted_at'],
      'decision_reason': requestRow['decision_reason'],
      'evidence_urls': requestRow['evidence_urls'],
      'reviewed_at': requestRow['reviewed_at'],
    });

    return dto.withVaultFields(
      idDocumentNumber: idNumber,
      commercialRegistrationNumber: regNumber,
    );
  }

  /// Calls `public.app_vault_secret_for_agency(p_agency_id, field_name)`.
  /// Returns null when the caller lacks `agencies.view` or when the secret
  /// does not exist.
  Future<String?> _decryptVaultField(
    String agencyId,
    String fieldName,
  ) async {
    final result = await _client.rpc(
      'app_vault_secret_for_agency',
      params: <String, dynamic>{
        'p_agency_id': agencyId,
        'field_name': fieldName,
      },
    );
    return result as String?;
  }

  // ─── moderate ─────────────────────────────────────────────────────────────

  /// Invokes the `moderate_agency` Edge Function.
  ///
  /// [agencyId]  — UUID of the target agency.
  /// [action]    — 'approve' | 'reject' | 'suspend' | 'reinstate'.
  /// [preset]    — required for `reject`; the reason preset key.
  /// [detail]    — optional extra detail for `reject` (≤500 chars).
  ///
  /// Returns the raw HTTP status + response data; the repository maps errors
  /// to typed Failures (mirrors Phase 12 / Phase 18 Edge Function pattern).
  Future<AgencyAdminEdgeFunctionResponse> moderate(
    String agencyId,
    String action, {
    String? preset,
    String? detail,
  }) async {
    final body = <String, dynamic>{
      'agency_id': agencyId,
      'action': action,
    };

    if (preset != null && preset.isNotEmpty) {
      body['reason'] = <String, dynamic>{
        'preset': preset,
        if (detail != null && detail.isNotEmpty) 'detail': detail,
      };
    }

    final response = await _client.functions.invoke(
      'moderate_agency',
      body: body,
    );
    return AgencyAdminEdgeFunctionResponse(
      status: response.status,
      data: response.data,
    );
  }
}
