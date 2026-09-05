// Phase 18 (spec/018-reports-moderation) — T031
// ReportQueueItem: the admin-visible projection of a report row from
// public.v_reports. Extends the reporter-facing Report fields with
// reporter identity + reviewer info that are only visible to
// reports.manage holders (data-model §2.5). Zero Supabase imports
// (Constitution IX).
import 'package:equatable/equatable.dart';

import '../../../../reports/domain/entities/report_reason.dart';
import '../../../../reports/domain/entities/report_status.dart';

class ReportQueueItem extends Equatable {
  const ReportQueueItem({
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
    // Joined listing-card fields:
    required this.listingTitle,
    required this.listingStatus,
    this.mainImagePath,
    this.governorateNameAr,
    this.governorateNameEn,
    this.cityNameAr,
    this.cityNameEn,
  });

  final String id;

  /// Null when the report is about a person (plan A29).
  final String? listingId;

  /// Plan A29 — set, with [listingId] null, when the report is about a person.
  final String? targetUserId;
  final String? targetUserName;

  bool get isUserReport => targetUserId != null;

  /// The listing title, or the reported person's name.
  String get displayTitle =>
      listingTitle.isNotEmpty ? listingTitle : (targetUserName ?? '');

  /// Reporter's auth.users.id — visible only to reports.manage holders.
  final String reporterUserId;

  final ReportReason reason;
  final ReportStatus status;
  final DateTime createdAt;
  final String? note;
  final String? resolution;
  final DateTime? resolvedAt;

  /// The admin currently soft-claiming this report (Q4=B).
  final String? reviewingBy;

  /// The admin who resolved this report (if terminal).
  final String? resolvedBy;

  // Joined listing-card fields (from v_reports).
  final String listingTitle;

  /// Raw `listings.status` string (not filtered by the view).
  final String listingStatus;
  final String? mainImagePath;
  final String? governorateNameAr;
  final String? governorateNameEn;
  final String? cityNameAr;
  final String? cityNameEn;

  @override
  List<Object?> get props => [
        id,
        listingId,
        reporterUserId,
        reason,
        status,
        resolution,
        resolvedAt,
        reviewingBy,
      ];
}
