// Phase 18 (spec/018-reports-moderation) — Report domain entity.
// Projection from v_reports (data-model §2.3). Zero Supabase imports.
import 'package:equatable/equatable.dart';

import 'report_reason.dart';
import 'report_status.dart';

class Report extends Equatable {
  const Report({
    required this.id,
    this.listingId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.note,
    this.resolution,
    this.resolvedAt,
    this.targetUserId,
    this.targetUserName,
    // Joined v_reports listing-card fields (for My-Reports rendering):
    required this.listingTitle,
    required this.listingStatus,        // raw listings.status string
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

  @override
  List<Object?> get props => [
        id,
        listingId,
        reason,
        status,
        resolution,
        resolvedAt,
      ];
}
