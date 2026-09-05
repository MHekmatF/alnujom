// Phase 18 (spec/018-reports-moderation) — T037
// ReportQueueItemDto: maps a public.v_reports row (admin projection) onto
// the domain ReportQueueItem entity. Only the datasource layer imports this
// file (Constitution IX).
import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';
import '../../domain/entities/report_queue_item.dart';

class ReportQueueItemDto {
  const ReportQueueItemDto({
    required this.id,
    this.listingId,
    required this.reporterUserId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.note,
    this.resolution,
    this.resolvedAt,
    this.reviewingBy,
    this.resolvedBy,
    this.targetUserId,
    this.targetUserName,
    required this.listingTitle,
    required this.listingStatus,
    this.mainImagePath,
    this.governorateNameAr,
    this.governorateNameEn,
    this.cityNameAr,
    this.cityNameEn,
  });

  final String id;
  final String? listingId;
  final String? targetUserId;
  final String? targetUserName;
  final String reporterUserId;
  final String reason;
  final String status;
  final String createdAt;
  final String? note;
  final String? resolution;
  final String? resolvedAt;
  final String? reviewingBy;
  final String? resolvedBy;
  final String listingTitle;
  final String listingStatus;
  final String? mainImagePath;
  final String? governorateNameAr;
  final String? governorateNameEn;
  final String? cityNameAr;
  final String? cityNameEn;

  factory ReportQueueItemDto.fromJson(Map<String, dynamic> json) {
    return ReportQueueItemDto(
      id: json['id'] as String,
      listingId: json['listing_id'] as String?,
      targetUserId: json['target_user_id'] as String?,
      targetUserName: json['target_user_name'] as String?,
      reporterUserId: json['reporter_user_id'] as String,
      reason: json['reason'] as String,
      status: json['status'] as String,
      createdAt: json['created_at'] as String,
      note: json['note'] as String?,
      resolution: json['resolution'] as String?,
      resolvedAt: json['resolved_at'] as String?,
      reviewingBy: json['reviewing_by'] as String?,
      resolvedBy: json['resolved_by'] as String?,
      listingTitle: json['listing_title'] as String? ?? '',
      listingStatus: json['listing_status'] as String? ?? '',
      mainImagePath: json['main_image_path'] as String?,
      governorateNameAr: json['governorate_name_ar'] as String?,
      governorateNameEn: json['governorate_name_en'] as String?,
      cityNameAr: json['city_name_ar'] as String?,
      cityNameEn: json['city_name_en'] as String?,
    );
  }

  ReportQueueItem toEntity() {
    return ReportQueueItem(
      id: id,
      listingId: listingId,
      reporterUserId: reporterUserId,
      reason: ReportReason.fromWire(reason),
      status: ReportStatus.fromWire(status),
      createdAt: DateTime.parse(createdAt),
      note: note,
      resolution: resolution,
      resolvedAt: resolvedAt != null ? DateTime.parse(resolvedAt!) : null,
      reviewingBy: reviewingBy,
      resolvedBy: resolvedBy,
      targetUserId: targetUserId,
      targetUserName: targetUserName,
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
