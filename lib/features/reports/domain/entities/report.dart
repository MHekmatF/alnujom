// Phase 18 (spec/018-reports-moderation) — Report domain entity.
// Projection from v_reports (data-model §2.3). Zero Supabase imports.
import 'package:equatable/equatable.dart';

import 'report_reason.dart';
import 'report_status.dart';

class Report extends Equatable {
  const Report({
    required this.id,
    required this.listingId,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.note,
    this.resolution,
    this.resolvedAt,
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
