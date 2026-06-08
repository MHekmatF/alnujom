// lib/features/search/data/repositories/saved_searches_repository_impl.dart
//
// Phase 25 premium uplift — concrete [SavedSearchesRepository] delegating to
// [SupabaseSavedSearchesDatasource]. Wraps transport/RPC exceptions in typed
// [Failure]s (Phase 14 SearchRepositoryImpl pattern). Per Constitution IX this
// file MUST NOT import supabase_flutter — the datasource is the sole importer.
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/entities/saved_search.dart';
import '../../domain/repositories/saved_searches_repository.dart';
import '../datasources/supabase_saved_searches_datasource.dart';

@Injectable(as: SavedSearchesRepository)
class SavedSearchesRepositoryImpl implements SavedSearchesRepository {
  SavedSearchesRepositoryImpl(this._datasource);

  final SupabaseSavedSearchesDatasource _datasource;

  @override
  Future<Result<SavedSearch>> save({
    required String label,
    required FilterState filters,
  }) async {
    try {
      final dto = await _datasource.create(
        label: label,
        filters: filters.toJson(),
      );
      return Success(dto.toEntity());
    } on SavedSearchAuthRequired {
      return const FailureResult(PermissionDeniedFailure());
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
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('Save search failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<List<SavedSearch>>> list() async {
    try {
      final dtos = await _datasource.list();
      return Success(dtos.map((d) => d.toEntity()).toList());
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
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('Load saved searches failed: $e', cause: e, stackTrace: st),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      await _datasource.delete(id);
      return const Success(null);
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
    } catch (e, st) {
      return FailureResult(
        UnknownFailure('Delete saved search failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
