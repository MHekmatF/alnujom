// Phase 19 (spec/019-agencies) — AgencyMemberDto.
//
// DTO mirroring a row from public.agency_members (data-model §1.2).
//
// agency_members columns:
//   agency_id, user_id, member_role, status, invited_by, joined_at,
//   created_at, updated_at
//
// Optional joined display fields (full_name, phone) when the query JOINs profiles.
// member_role / status are mapped through AgencyMemberRole.fromWire / AgencyMemberStatus.fromWire.
// No supabase_flutter import — Supabase coupling is at the datasource boundary.

import '../../domain/entities/agency_member.dart';
import '../../domain/entities/agency_member_role.dart';
import '../../domain/entities/agency_member_status.dart';

class AgencyMemberDto {
  const AgencyMemberDto({
    required this.agencyId,
    required this.userId,
    required this.role,
    required this.status,
    this.invitedBy,
    this.joinedAt,
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

  factory AgencyMemberDto.fromJson(Map<String, dynamic> json) {
    return AgencyMemberDto(
      agencyId: json['agency_id'] as String,
      userId: json['user_id'] as String,
      role: AgencyMemberRole.fromWire(json['member_role'] as String),
      status: AgencyMemberStatus.fromWire(json['status'] as String),
      invitedBy: json['invited_by'] as String?,
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : null,
      // Optional display fields joined from profiles (may be absent).
      displayName: json['display_name'] as String?,
      phone: json['phone'] as String?,
    );
  }

  AgencyMember toEntity() {
    return AgencyMember(
      agencyId: agencyId,
      userId: userId,
      role: role,
      status: status,
      invitedBy: invitedBy,
      joinedAt: joinedAt,
      displayName: displayName,
      phone: phone,
    );
  }
}
