import 'package:equatable/equatable.dart';

/// Plan A36 — rows per page of the approvals queue (keyset on `created_at`).
const int kApprovalsPageSize = 50;

/// Approval queue lifecycle values (matches `account_approval_status` SQL enum, minus suspended).
enum AccountApprovalStatus { pending, approved, rejected }

/// Pending approval request shown in the admin queue.
///
/// Carries denormalized snippet fields (phone, email, fullName) from the
/// registrant's profile row for display without a second query in the UI.
/// Constitution IX: no Supabase types.
class AccountApprovalRequest extends Equatable {
  const AccountApprovalRequest({
    required this.id,
    required this.userId,
    required this.status,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
    this.registrantPhone,
    this.registrantEmail,
    this.registrantFullName,
  });

  final String id;
  final String userId;
  final AccountApprovalStatus status;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Denormalized from profiles.phone — shown in the admin card.
  final String? registrantPhone;

  /// Denormalized from profiles.email — shown in the admin card.
  final String? registrantEmail;

  /// Denormalized from profiles.full_name — shown in the admin card.
  final String? registrantFullName;

  @override
  List<Object?> get props => [
    id,
    userId,
    status,
    rejectionReason,
    reviewedBy,
    reviewedAt,
    createdAt,
    updatedAt,
    registrantPhone,
    registrantEmail,
    registrantFullName,
  ];
}
