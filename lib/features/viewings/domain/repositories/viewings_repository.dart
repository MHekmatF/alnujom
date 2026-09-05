// lib/features/viewings/domain/repositories/viewings_repository.dart
//
// Viewing scheduler — abstract contract for viewing access.
// Implemented by ViewingsRepositoryImpl (data layer).

import '../../../../core/errors/result.dart';
import '../entities/viewing.dart';

/// Repository for the `viewings` table + its two RPCs.
///
/// All reads/writes are RLS-scoped to the viewing's members (requester +
/// publisher). The current user id (used to compute `amIPublisher`) is sourced
/// from the authenticated Supabase session inside the data layer.
abstract interface class ViewingsRepository {
  /// Loads the caller's viewings, newest-scheduled-first.
  /// One page (plan A36): rows scheduled before [before], newest first.
  Future<Result<List<Viewing>>> listMyViewings({
    DateTime? before,
    int limit = kViewingsPageSize,
  });

  /// Requests a viewing on [listingId] at [scheduledAtUtc] (UTC) with an
  /// optional [note]; returns the new viewing's id.
  Future<Result<String>> requestViewing({
    required String listingId,
    required DateTime scheduledAtUtc,
    String? note,
  });

  /// Transitions [viewingId] to [status] (confirmed/declined/cancelled).
  Future<Result<void>> updateStatus({
    required String viewingId,
    required String status,
  });
}
