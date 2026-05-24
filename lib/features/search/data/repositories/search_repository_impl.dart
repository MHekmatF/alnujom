// lib/features/search/data/repositories/search_repository_impl.dart
//
// Phase 14 — concrete [SearchRepository] delegating to the
// [SupabaseSearchDatasource]. Wraps any transport / RPC exception in a
// [NetworkFailure] (SocketException / TimeoutException) or [UnknownFailure]
// (everything else, including PostgrestException) per the Phase 13
// `HomeFeedRepositoryImpl` pattern.
//
// Per Constitution IX + FR-030 this file MUST NOT import the
// supabase_flutter package — the datasource is the sole importer.
import 'dart:async';
import 'dart:io' show SocketException;

import 'package:injectable/injectable.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/errors/result.dart';
import '../../domain/entities/filter_state.dart';
import '../../domain/entities/search_cursor.dart';
import '../../domain/entities/search_result_item.dart';
import '../../domain/entities/sort_order.dart';
import '../../domain/repositories/search_repository.dart';
import '../datasources/supabase_search_datasource.dart';

@Injectable(as: SearchRepository)
class SearchRepositoryImpl implements SearchRepository {
  SearchRepositoryImpl(this._datasource);

  final SupabaseSearchDatasource _datasource;

  @override
  Future<Result<List<SearchResultItem>>> search({
    required FilterState filters,
    required SortOrder sort,
    SearchCursor? cursor,
    int limit = 20,
  }) async {
    try {
      final items = await _datasource.fetchPage(
        filters: filters,
        sort: sort,
        cursor: cursor,
        limit: limit,
      );
      return Success(items);
    } on SocketException catch (e, st) {
      return FailureResult(
        NetworkFailure(e.message, cause: e, stackTrace: st),
      );
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
        UnknownFailure('Search failed: $e', cause: e, stackTrace: st),
      );
    }
  }
}
