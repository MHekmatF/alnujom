// Phase 25 premium uplift v2 — publisher summary dashboard.
// PublisherDashboardCountsRepositoryImpl: concrete impl, mirrors the admin
// DashboardRepositoryImpl wiring. Constitution IX: only imports the datasource.
import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/publisher_dashboard_counts.dart';
import '../../domain/repositories/publisher_dashboard_counts_repository.dart';
import '../datasources/publisher_dashboard_counts_datasource.dart';

@LazySingleton(as: PublisherDashboardCountsRepository)
class PublisherDashboardCountsRepositoryImpl
    implements PublisherDashboardCountsRepository {
  PublisherDashboardCountsRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'PublisherDashboardCountsRepositoryImpl';

  final PublisherDashboardCountsDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<PublisherDashboardCounts>> fetchCounts() async {
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
