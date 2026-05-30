// Phase 19 (spec/019-agencies) — AgencyDto.
//
// DTO mirroring a row from public.v_agencies (data-model §1.6).
//
// v_agencies projected columns:
//   id, owner_user_id, name, description, phone, whatsapp, address,
//   logo_path, cover_path, status, created_at, updated_at
//
// status is mapped through AgencyStatus.fromWire.
// No supabase_flutter import — Supabase coupling is at the datasource boundary.

import '../../domain/entities/agency.dart';
import '../../domain/entities/agency_status.dart';

class AgencyDto {
  const AgencyDto({
    required this.id,
    required this.ownerUserId,
    required this.name,
    required this.status,
    required this.createdAt,
    this.description,
    this.phone,
    this.whatsapp,
    this.address,
    this.logoPath,
    this.coverPath,
  });

  final String id;
  final String ownerUserId;
  final String name;
  final AgencyStatus status;
  final DateTime createdAt;
  final String? description;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String? logoPath;
  final String? coverPath;

  factory AgencyDto.fromJson(Map<String, dynamic> json) {
    return AgencyDto(
      id: json['id'] as String,
      ownerUserId: json['owner_user_id'] as String,
      name: json['name'] as String,
      status: AgencyStatus.fromWire(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      description: json['description'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      address: json['address'] as String?,
      logoPath: json['logo_path'] as String?,
      coverPath: json['cover_path'] as String?,
    );
  }

  Agency toEntity() {
    return Agency(
      id: id,
      ownerUserId: ownerUserId,
      name: name,
      status: status,
      createdAt: createdAt,
      description: description,
      phone: phone,
      whatsapp: whatsapp,
      address: address,
      logoPath: logoPath,
      coverPath: coverPath,
    );
  }
}
