// Phase 18 (spec/018-reports-moderation) — ReportDto.
//
// DTO mirroring a row from public.v_reports (Migration 4/8).
//
// v_reports projected columns (17 columns):
//   id, listing_id, reporter_user_id,
//   reason, note, status, reviewing_by, resolved_by, resolution,
//   created_at, resolved_at,
//   listing_title, listing_status,
//   main_image_path,
//   governorate_name_ar, governorate_name_en,
//   city_name_ar, city_name_en
//
// reason / status are mapped through ReportReason.fromWire / ReportStatus.fromWire.
// No supabase_flutter import — this file belongs to data/models/ but references
// only domain types, keeping the Supabase coupling at the datasource boundary.

import '../../domain/entities/report.dart';
import '../../domain/entities/report_reason.dart';
import '../../domain/entities/report_status.dart';

class ReportDto {
  const ReportDto({
    required this.id,
    required this.listingId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.note,
    this.resolution,
    this.resolvedAt,
    required this.listingTitle,
    required this.listingStatus,
    this.mainImagePath,
    this.governorateNameAr,
    this.governorateNameEn,
    this.cityNameAr,
    this.cityNameEn,
  });

  final String id;
  final String listingId;
  final ReportReason reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? note;
  final String? resolution;
  final DateTime? resolvedAt;
  final String listingTitle;
  final String listingStatus;
  final String? mainImagePath;
  final String? governorateNameAr;
  final String? governorateNameEn;
  final String? cityNameAr;
  final String? cityNameEn;

  factory ReportDto.fromJson(Map<String, dynamic> json) {
    return ReportDto(
      id: json['id'] as String,
      listingId: json['listing_id'] as String,
      reason: ReportReason.fromWire(json['reason'] as String),
      status: ReportStatus.fromWire(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      note: json['note'] as String?,
      resolution: json['resolution'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      listingTitle: json['listing_title'] as String? ?? '',
      listingStatus: json['listing_status'] as String? ?? '',
      mainImagePath: json['main_image_path'] as String?,
      governorateNameAr: json['governorate_name_ar'] as String?,
      governorateNameEn: json['governorate_name_en'] as String?,
      cityNameAr: json['city_name_ar'] as String?,
      cityNameEn: json['city_name_en'] as String?,
    );
  }

  Report toEntity() {
    return Report(
      id: id,
      listingId: listingId,
      reason: reason,
      status: status,
      createdAt: createdAt,
      note: note,
      resolution: resolution,
      resolvedAt: resolvedAt,
      listingTitle: listingTitle,
      listingStatus: listingStatus,
      mainImagePath: mainImagePath,
      governorateNameAr: governorateNameAr,
      governorateNameEn: governorateNameEn,
      cityNameAr: cityNameAr,
      cityNameEn: cityNameEn,
    );
  }
}
