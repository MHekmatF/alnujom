import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../domain/entities/account_approval_request.dart';

/// Wraps Supabase queries against `account_approval_requests` and the approve/reject RPCs.
///
/// Two-query approach: pending requests + profile snippets joined in Dart,
/// because account_approval_requests.user_id FKs to auth.users(id) rather than
/// profiles.user_id, so PostgREST cannot infer the join path directly.
@LazySingleton()
class SupabaseAccountApprovalsDatasource {
  SupabaseAccountApprovalsDatasource();

  supabase.SupabaseClient get _client => supabase.Supabase.instance.client;

  Future<List<AccountApprovalRequest>> loadPendingQueue() async {
    final requests = await _client
        .from('account_approval_requests')
        .select()
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    if (requests.isEmpty) return [];

    final userIds = requests.map((r) => r['user_id'] as String).toList();
    final profiles = await _client
        .from('profiles')
        .select('user_id, phone, email, full_name')
        .inFilter('user_id', userIds);

    final profileMap = <String, Map<String, dynamic>>{
      for (final p in profiles) p['user_id'] as String: p,
    };

    return requests.map((r) {
      final uid = r['user_id'] as String;
      final profile = profileMap[uid];
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
