// Phase 20 (spec/020-admin-dashboard) — T013
// DashboardRepositoryImpl: concrete implementation, mirrors reports/ wiring.
// Constitution IX: only imports the datasource; Supabase is confined there.
import 'package:injectable/injectable.dart';

import '../../../../../core/errors/failure.dart';
import '../../../../../core/errors/result.dart';
import '../../../../../core/logging/app_logger.dart';
import '../../domain/entities/dashboard_counts.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_counts_datasource.dart';

@LazySingleton(as: DashboardRepository)
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'DashboardRepositoryImpl';

  final DashboardCountsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<DashboardCounts>> fetchCounts() async {
    try {
      final dto = await _datasource.fetchCounts();
      return Success(dto.toEntity());
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'fetchCounts failed.',
        error: error,
        stackTrace: stackTrace,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
      );
    }
  }
}
