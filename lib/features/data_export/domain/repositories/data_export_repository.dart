// Plan A38 — DataExportRepository interface.
//
// Per Constitution IX: ZERO supabase_flutter imports in domain/.

import '../../../../core/errors/result.dart';
import '../entities/data_export_file.dart';

abstract interface class DataExportRepository {
  /// Asks the `export_my_data` server function, with the caller's own token,
  /// for a copy of everything the app holds about them.
  ///
  /// Fails with PermissionDeniedFailure when signed out, NetworkFailure when
  /// the server cannot be reached or answers with an error, UnknownFailure
  /// otherwise.
  Future<Result<DataExportFile>> exportMyData();
}
