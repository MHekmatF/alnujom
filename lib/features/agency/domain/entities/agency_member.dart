import 'package:equatable/equatable.dart';

import 'agency_member_role.dart';
import 'agency_member_status.dart';

class AgencyMember extends Equatable {
  const AgencyMember({
    required this.agencyId,
    required this.userId,
    required this.role,
    required this.status,
    this.invitedBy,
    this.joinedAt,
    // Optional joined display fields (full_name / phone) when the roster view provides them:
    this.displayName,
    this.phone,
  });

  final String agencyId;
  final String userId;
  final AgencyMemberRole role;
  final AgencyMemberStatus status;
  final String? invitedBy;
  final DateTime? joinedAt;
  final String? displayName;
  final String? phone;

  @override
  List<Object?> get props => [agencyId, userId, role, status];
}
