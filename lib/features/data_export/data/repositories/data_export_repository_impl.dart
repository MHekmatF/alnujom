// Plan A38 — DataExportRepositoryImpl.
//
// Imports supabase_flutter only for FunctionException (typed status mapping),
// per Constitution IX.

import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/data_export_file.dart';
import '../../domain/repositories/data_export_repository.dart';
import '../datasources/supabase_data_export_datasource.dart';

@LazySingleton(as: DataExportRepository)
class DataExportRepositoryImpl implements DataExportRepository {
  const DataExportRepositoryImpl(this._datasource, this._logger);

  static const _tag = 'DataExportRepositoryImpl';

  final SupabaseDataExportDatasource _datasource;
  final AppLogger _logger;

  @override
  Future<Result<DataExportFile>> exportMyData() async {
    try {
      final bytes = await _datasource.download();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      return Success(
        DataExportFile(bytes: bytes, fileName: 'alnujom-data-$stamp.json'),
      );
    } on FunctionException catch (e, st) {
      if (e.status == 401 || e.status == 403) {
        return const FailureResult(PermissionDeniedFailure());
      }
      _logger.warning(
        'export_my_data answered ${e.status}',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      return FailureResult(
        NetworkFailure(
          'export_my_data answered ${e.status}',
          cause: e,
          stackTrace: st,
        ),
      );
    } on SocketException catch (e, st) {
      return FailureResult(NetworkFailure(e.message, cause: e, stackTrace: st));
    } on TimeoutException catch (e, st) {
      return FailureResult(
        NetworkFailure(
          e.message ?? 'Request timed out',
          cause: e,
          stackTrace: st,
        ),
      );
    } on Object catch (e, st) {
      _logger.warning(
        'exportMyData failed',
        error: e,
        stackTrace: st,
        tag: _tag,
      );
      return FailureResult(
        UnknownFailure('exportMyData failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
