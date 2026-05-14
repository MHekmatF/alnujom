import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../entities/account_approval_request.dart';

/// Admin approval-queue repository contract.
///
/// Constitution IX: no Supabase types.
abstract class AccountApprovalsRepository {
  Future<Result<List<AccountApprovalRequest>>> loadPendingQueue();
  Future<Result<void>> approve({required String userId});
  Future<Result<void>> reject({required String userId, required String reason});
}

// ───────────────────────────────────────────────────────────────────────────
// Failure hierarchy
// ───────────────────────────────────────────────────────────────────────────

sealed class AccountApprovalsFailure extends Failure {
  const AccountApprovalsFailure(super.message, {super.cause, super.stackTrace});
}

final class AdminForbidden extends AccountApprovalsFailure {
  const AdminForbidden({super.cause, super.stackTrace})
    : super('admin_forbidden');
}

final class RequestAlreadyResolved extends AccountApprovalsFailure {
  const RequestAlreadyResolved({super.cause, super.stackTrace})
    : super('admin_request_already_resolved');
}

final class NetworkErrorAdmin extends AccountApprovalsFailure {
  const NetworkErrorAdmin(super.message, {super.cause, super.stackTrace});
}

final class UnknownAdminError extends AccountApprovalsFailure {
  const UnknownAdminError(super.message, {super.cause, super.stackTrace});
}
