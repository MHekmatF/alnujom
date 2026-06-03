// lib/features/reports/presentation/cubit/listing_report_status_cubit.dart
//
// Phase 18 (spec/018-reports-moderation) Sub-Phase H (T047).
// Cubit that loads the current user's report (if any) for a given listing.
// Drives the ReporterStatusBanner on the listing-details page (FR-023).
// Zero Supabase imports (Constitution IX).
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/errors/result.dart';
import '../../domain/entities/report.dart';
import '../../domain/usecases/load_my_report_for_listing.dart';

/// State for [ListingReportStatusCubit].
sealed class ListingReportStatusState {
  const ListingReportStatusState();
}

/// Initial / loading.
final class ListingReportStatusLoading extends ListingReportStatusState {
  const ListingReportStatusLoading();
}

/// Report loaded (may be null when the user has not reported this listing).
final class ListingReportStatusLoaded extends ListingReportStatusState {
  const ListingReportStatusLoaded(this.report);

  /// Null when the current user has no report for this listing.
  final Report? report;
}

/// Error loading the report status (e.g. network failure).
final class ListingReportStatusError extends ListingReportStatusState {
  const ListingReportStatusError();
}

/// Page-scoped cubit: loads the reporter's own most-recent report for a
/// listing.  Non-authenticated users always land in [ListingReportStatusLoaded]
/// with `report == null` so the banner renders nothing (FR-023).
///
/// Registered as @injectable (one per listing-details page instance).
@injectable
class ListingReportStatusCubit
    extends Cubit<ListingReportStatusState> {
  ListingReportStatusCubit(this._loadMyReportForListing)
      : super(const ListingReportStatusLoading());

  final LoadMyReportForListing _loadMyReportForListing;

  /// Loads the report status for [listingId].
  Future<void> load(String listingId) async {
    emit(const ListingReportStatusLoading());
    final result = await _loadMyReportForListing(listingId);
    if (isClosed) return;
    switch (result) {
      case Success<Report?>(:final value):
        emit(ListingReportStatusLoaded(value));
      case FailureResult<Report?>():
        // Fail silently — banner renders nothing on error (not the listing's
        // primary content).
        emit(const ListingReportStatusError());
    }
  }
}
