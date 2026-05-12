import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/account_approval_request.dart';

/// Wraps Supabase queries against `account_approval_requests` and the approve/reject RPCs.
///
/// Single-query approach: uses PostgREST embedded select (profiles FK added in Phase 5)
/// to fetch queue items + profile snippets in one HTTPS request, avoiding HiOS throttling
/// that occurs when two consecutive requests are made in quick succession.
@LazySingleton()
class SupabaseAccountApprovalsDatasource {
  SupabaseAccountApprovalsDatasource();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  Future<List<AccountApprovalRequest>> loadPendingQueue() async {
    // Single request: embedded select joins profiles via the FK added in Phase 5.
    // Timeout guards against HiOS throttling; TimeoutException propagates to repository.
    final Future<List<dynamic>> queueFuture = _client
        .from('account_approval_requests')
        .select('*, profiles(phone, email, full_name)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final requests = await queueFuture.timeout(const Duration(seconds: 15));

    if (requests.isEmpty) return [];

    return requests.map((r) {
      final uid = r['user_id'] as String;
      final profile = r['profiles'] as Map<String, dynamic>?;
      return AccountApprovalRequest(
        id: r['id'] as String,
        userId: uid,
        status: _parseStatus(r['status'] as String),
        rejectionReason: r['rejection_reason'] as String?,
        reviewedBy: r['reviewed_by'] as String?,
        reviewedAt: r['reviewed_at'] != null
            ? DateTime.parse(r['reviewed_at'] as String)
            : null,
        createdAt: DateTime.parse(r['created_at'] as String),
        updatedAt: DateTime.parse(r['updated_at'] as String),
        registrantPhone: profile?['phone'] as String?,
        registrantEmail: profile?['email'] as String?,
        registrantFullName: profile?['full_name'] as String?,
      );
    }).toList();
  }

  Future<void> approve({required String userId}) async {
    await _client.rpc(
      'approve_account_approval_request',
      params: {'p_user_id': userId},
    );
  }

  Future<void> reject({
    required String userId,
    required String reason,
  }) async {
    await _client.rpc(
      'reject_account_approval_request',
      params: {'p_user_id': userId, 'p_reason': reason},
    );
  }

  AccountApprovalStatus _parseStatus(String raw) {
    return switch (raw) {
      'approved' => AccountApprovalStatus.approved,
      'rejected' => AccountApprovalStatus.rejected,
      _ => AccountApprovalStatus.pending,
    };
  }
}
